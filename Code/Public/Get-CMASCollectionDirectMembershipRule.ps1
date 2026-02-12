function Get-CMASCollectionDirectMembershipRule {
    <#
        .SYNOPSIS
            Retrieves direct membership rules from a Configuration Manager collection.

        .DESCRIPTION
            This function retrieves direct membership rules for Configuration Manager collections via the Admin Service API.
            You can filter by collection using CollectionName, CollectionId, or by providing a collection object.
            Additionally, you can filter the membership rules by ResourceName or ResourceId.

        .PARAMETER CollectionName
            The name of the collection to retrieve direct membership rules from.

        .PARAMETER CollectionId
            The ID of the collection to retrieve direct membership rules from.

        .PARAMETER InputObject
            A collection object (from Get-CMASCollection) to retrieve direct membership rules from.
            This parameter accepts pipeline input.

        .PARAMETER ResourceName
            Optional. Filter membership rules to only include rules for resources with this name.
            Supports wildcards.

        .PARAMETER ResourceId
            Optional. Filter membership rules to only include rules for the resource with this ID.

        .EXAMPLE
            Get-CMASCollectionDirectMembershipRule -CollectionName "All Systems"
            Retrieves all direct membership rules from the "All Systems" collection.

        .EXAMPLE
            Get-CMASCollectionDirectMembershipRule -CollectionId "SMS00001" -ResourceName "Server01"
            Retrieves direct membership rules from collection SMS00001 for resource named "Server01".

        .EXAMPLE
            Get-CMASCollectionDirectMembershipRule -CollectionName "My Collection" -ResourceId 16777220
            Retrieves the direct membership rule for resource ID 16777220 in "My Collection".

        .EXAMPLE
            Get-CMASCollection -Name "My Collection" | Get-CMASCollectionDirectMembershipRule
            Retrieves all direct membership rules from the piped collection object.

        .EXAMPLE
            Get-CMASCollection -Name "My Collection" | Get-CMASCollectionDirectMembershipRule -ResourceName "TEST-*"
            Retrieves direct membership rules for resources matching "TEST-*" wildcard pattern.

        .NOTES
            This function is part of the SCCM Admin Service module.
            Requires an active connection established via Connect-CMAS.

            IMPORTANT: The Admin Service does not expose SMS_CollectionRuleDirect as a separate WMI class.
            This function retrieves the full collection object and extracts direct membership rules from
            the CollectionRules property. This may be less efficient than the native ConfigurationManager
            cmdlet for collections with many rules.

            NOTE: This function returns DIRECT MEMBERSHIP RULES, not collection members.
            - Direct membership rules explicitly add specific devices/users to a collection
            - A collection with 1000 members might have 0 direct membership rules if it uses query-based rules
            - Collections can have query rules, include rules, exclude rules, or direct membership rules
            - This cmdlet only returns direct membership rules (where @odata.type = '#AdminService.SMS_CollectionRuleDirect')

        .LINK
            Connect-CMAS
            Get-CMASCollection
    #>
    [CmdletBinding(DefaultParameterSetName='ByName', SupportsShouldProcess=$false)]
    param(
        [Parameter(Mandatory=$true, ParameterSetName='ByName')]
        [Parameter(Mandatory=$true, ParameterSetName='ByNameAndResourceName')]
        [Parameter(Mandatory=$true, ParameterSetName='ByNameAndResourceId')]
        [Alias('Name')]
        [string]$CollectionName,

        [Parameter(Mandatory=$true, ParameterSetName='ById')]
        [Parameter(Mandatory=$true, ParameterSetName='ByIdAndResourceName')]
        [Parameter(Mandatory=$true, ParameterSetName='ByIdAndResourceId')]
        [Alias('Id')]
        [string]$CollectionId,

        [Parameter(Mandatory=$true, ParameterSetName='ByValue', ValueFromPipeline=$true)]
        [Parameter(Mandatory=$true, ParameterSetName='ByValueAndResourceName', ValueFromPipeline=$true)]
        [Parameter(Mandatory=$true, ParameterSetName='ByValueAndResourceId', ValueFromPipeline=$true)]
        [Alias('Collection')]
        [object]$InputObject,

        [Parameter(Mandatory=$true, ParameterSetName='ByNameAndResourceName')]
        [Parameter(Mandatory=$true, ParameterSetName='ByIdAndResourceName')]
        [Parameter(Mandatory=$true, ParameterSetName='ByValueAndResourceName')]
        [SupportsWildcards()]
        [string]$ResourceName,

        [Parameter(Mandatory=$true, ParameterSetName='ByNameAndResourceId')]
        [Parameter(Mandatory=$true, ParameterSetName='ByIdAndResourceId')]
        [Parameter(Mandatory=$true, ParameterSetName='ByValueAndResourceId')]
        [long]$ResourceId
    )

    begin {
        # Validate connection
        if (-not $script:CMASConnection.SiteServer) {
            throw "No active connection to SCCM Admin Service. Run Connect-CMAS first."
        }
    }

    process {
        try {
            # Determine the CollectionID to use
            $targetCollectionId = $null

            if ($PSCmdlet.ParameterSetName -like 'ByValue*') {
                # Extract CollectionID from InputObject
                if ($InputObject.CollectionID) {
                    $targetCollectionId = $InputObject.CollectionID
                } else {
                    Write-Error "InputObject does not contain a valid CollectionID property."
                    return
                }
            } elseif ($CollectionId) {
                $targetCollectionId = $CollectionId
            } elseif ($CollectionName) {
                # Need to resolve CollectionName to CollectionID
                Write-Verbose "Resolving CollectionName '$CollectionName' to CollectionID..."
                $collection = Get-CMASCollection -Name $CollectionName
                if (-not $collection) {
                    Write-Error "Collection with name '$CollectionName' not found."
                    return
                }
                $targetCollectionId = $collection.CollectionID
            }

            # Get the full collection object which contains CollectionRules property
            # Note: SMS_CollectionRuleDirect is not exposed as a separate class in Admin Service
            # Collection rules are embedded in the SMS_Collection object
            # IMPORTANT: CollectionRules is a LAZY PROPERTY - must access by key, not by filter
            $path = "wmi/SMS_Collection('$targetCollectionId')"

            Write-Verbose "Fetching collection from Admin Service with path: $path"
            $res = Invoke-CMASApi -Path $path

            if (-not $res.value -or $res.value.Count -eq 0) {
                Write-Verbose "Collection '$targetCollectionId' not found or has no data"
                return $null
            }

            $collection = $res.value[0]

            # Extract CollectionRules and filter for direct membership rules only
            # Direct membership rules have __CLASS = 'SMS_CollectionRuleDirect' OR
            # @odata.type = '#AdminService.SMS_CollectionRuleDirect' (in Admin Service API)
            if (-not $collection.CollectionRules -or $collection.CollectionRules.Count -eq 0) {
                Write-Verbose "Collection '$targetCollectionId' has no collection rules defined"
                return $null
            }

            $directRules = $collection.CollectionRules | Where-Object {
                $_.__CLASS -eq 'SMS_CollectionRuleDirect' -or
                $_.'@odata.type' -eq '#AdminService.SMS_CollectionRuleDirect'
            }

            if (-not $directRules -or @($directRules).Count -eq 0) {
                Write-Verbose "Collection '$targetCollectionId' has no direct membership rules"
                return $null
            }

            # Apply resource name filter if specified
            if ($ResourceName) {
                if ($ResourceName -match '\*') {
                    # Handle wildcards
                    $pattern = $ResourceName -replace '\*', '.*'
                    $pattern = "^$pattern$"
                    $directRules = $directRules | Where-Object { $_.RuleName -match $pattern }
                } else {
                    # Exact match
                    $directRules = $directRules | Where-Object { $_.RuleName -eq $ResourceName }
                }
            }

            # Apply resource ID filter if specified
            if ($ResourceId) {
                $directRules = $directRules | Where-Object { $_.ResourceID -eq $ResourceId }
            }

            # Format results - exclude WMI metadata and OData metadata, add CollectionID
            if ($directRules) {
                $rules = $directRules | Select-Object -Property * -ExcludeProperty @odata* |
                    ForEach-Object {
                        $_ | Add-Member -NotePropertyName 'CollectionID' -NotePropertyValue $targetCollectionId -Force -PassThru
                    } |
                    Select-Object -Property * -ExcludeProperty __*
                return $rules
            } else {
                # No rules found after filtering
                return $null
            }
        }
        catch {
            Write-Error "Failed to retrieve collection direct membership rules: $_"
            throw $_
        }
    }

    end {
    }
}

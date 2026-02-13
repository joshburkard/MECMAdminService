function Get-CMASCollectionIncludeMembershipRule {
    <#
        .SYNOPSIS
            Retrieves include membership rules from a Configuration Manager collection.

        .DESCRIPTION
            This function retrieves include membership rules for Configuration Manager collections via the Admin Service API.
            You can filter by collection using CollectionName, CollectionId, or by providing a collection object.
            Additionally, you can filter the include rules by IncludeCollectionName or IncludeCollectionId.

        .PARAMETER CollectionName
            The name of the collection to retrieve include membership rules from.

        .PARAMETER CollectionId
            The ID of the collection to retrieve include membership rules from.

        .PARAMETER InputObject
            A collection object (from Get-CMASCollection) to retrieve include membership rules from.
            This parameter accepts pipeline input.

        .PARAMETER IncludeCollectionName
            Optional. Filter include rules to only include rules for the included collection with this name.
            Supports wildcards.

        .PARAMETER IncludeCollectionId
            Optional. Filter include rules to only include rules for the included collection with this ID.

        .EXAMPLE
            Get-CMASCollectionIncludeMembershipRule -CollectionName "All Systems"
            Retrieves all include membership rules from the "All Systems" collection.

        .EXAMPLE
            Get-CMASCollectionIncludeMembershipRule -CollectionId "SMS00001" -IncludeCollectionName "Included Collection"
            Retrieves include membership rules from collection SMS00001 for included collection named "Included Collection".

        .EXAMPLE
            Get-CMASCollectionIncludeMembershipRule -CollectionName "My Collection" -IncludeCollectionId "SMS00002"
            Retrieves the include membership rule for included collection ID SMS00002 in "My Collection".

        .EXAMPLE
            Get-CMASCollection -Name "My Collection" | Get-CMASCollectionIncludeMembershipRule
            Retrieves all include membership rules from the piped collection object.

        .EXAMPLE
            Get-CMASCollection -Name "My Collection" | Get-CMASCollectionIncludeMembershipRule -IncludeCollectionName "TEST-*"
            Retrieves include membership rules for included collections matching "TEST-*" wildcard pattern.

        .NOTES
            This function is part of the SCCM Admin Service module.
            Requires an active connection established via Connect-CMAS.

            IMPORTANT: The Admin Service does not expose SMS_CollectionRuleInclude as a separate WMI class.
            This function retrieves the full collection object and extracts include membership rules from
            the CollectionRules property. This may be less efficient than the native ConfigurationManager
            cmdlet for collections with many rules.

            NOTE: This function returns INCLUDE MEMBERSHIP RULES, not included collection members.
            - Include membership rules specify which collections should have their members included
            - Collections can have query rules, include rules, exclude rules, or direct membership rules
            - This cmdlet only returns include membership rules (where @odata.type = '#AdminService.SMS_CollectionRuleIncludeCollection')

        .LINK
            Connect-CMAS
            Get-CMASCollection
    #>
    [CmdletBinding(DefaultParameterSetName='ByName', SupportsShouldProcess=$false)]
    param(
        [Parameter(Mandatory=$true, ParameterSetName='ByName')]
        [Parameter(Mandatory=$true, ParameterSetName='ByNameAndIncludeName')]
        [Parameter(Mandatory=$true, ParameterSetName='ByNameAndIncludeId')]
        [Alias('Name')]
        [string]$CollectionName,

        [Parameter(Mandatory=$true, ParameterSetName='ById')]
        [Parameter(Mandatory=$true, ParameterSetName='ByIdAndIncludeName')]
        [Parameter(Mandatory=$true, ParameterSetName='ByIdAndIncludeId')]
        [Alias('Id')]
        [string]$CollectionId,

        [Parameter(Mandatory=$true, ParameterSetName='ByValue', ValueFromPipeline=$true)]
        [Parameter(Mandatory=$true, ParameterSetName='ByValueAndIncludeName', ValueFromPipeline=$true)]
        [Parameter(Mandatory=$true, ParameterSetName='ByValueAndIncludeId', ValueFromPipeline=$true)]
        [Alias('Collection')]
        [object]$InputObject,

        [Parameter(Mandatory=$true, ParameterSetName='ByNameAndIncludeName')]
        [Parameter(Mandatory=$true, ParameterSetName='ByIdAndIncludeName')]
        [Parameter(Mandatory=$true, ParameterSetName='ByValueAndIncludeName')]
        [SupportsWildcards()]
        [string]$IncludeCollectionName,

        [Parameter(Mandatory=$true, ParameterSetName='ByNameAndIncludeId')]
        [Parameter(Mandatory=$true, ParameterSetName='ByIdAndIncludeId')]
        [Parameter(Mandatory=$true, ParameterSetName='ByValueAndIncludeId')]
        [string]$IncludeCollectionId
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
            # Note: SMS_CollectionRuleInclude is not exposed as a separate class in Admin Service
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

            # Extract CollectionRules and filter for include membership rules only
            # Include membership rules have __CLASS = 'SMS_CollectionRuleInclude' OR
            # @odata.type = '#AdminService.SMS_CollectionRuleIncludeCollection' (in Admin Service API)
            if (-not $collection.CollectionRules -or $collection.CollectionRules.Count -eq 0) {
                Write-Verbose "Collection '$targetCollectionId' has no collection rules defined"
                return $null
            }

            $includeRules = $collection.CollectionRules | Where-Object {
                $_.__CLASS -eq 'SMS_CollectionRuleInclude' -or
                $_.'@odata.type' -eq '#AdminService.SMS_CollectionRuleIncludeCollection'
            }

            if (-not $includeRules -or @($includeRules).Count -eq 0) {
                Write-Verbose "Collection '$targetCollectionId' has no include membership rules"
                return $null
            }

            # Apply include collection name filter if specified
            if ($IncludeCollectionName) {
                if ($IncludeCollectionName -match '\*') {
                    # Handle wildcards
                    $pattern = $IncludeCollectionName -replace '\*', '.*'
                    $pattern = "^$pattern$"
                    $includeRules = $includeRules | Where-Object { $_.RuleName -match $pattern }
                } else {
                    # Exact match
                    $includeRules = $includeRules | Where-Object { $_.RuleName -eq $IncludeCollectionName }
                }
            }

            # Apply include collection ID filter if specified
            if ($IncludeCollectionId) {
                $includeRules = $includeRules | Where-Object { $_.IncludeCollectionID -eq $IncludeCollectionId }
            }

            # Format results - exclude WMI metadata and OData metadata, add CollectionID
            if ($includeRules) {
                $rules = $includeRules | Select-Object -Property * -ExcludeProperty @odata* |
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
            Write-Error "Failed to retrieve collection include membership rules: $_"
            throw $_
        }
    }

    end {
    }
}

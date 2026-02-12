function Get-CMASCollectionExcludeMembershipRule {
    <#
        .SYNOPSIS
            Retrieves exclude membership rules from a Configuration Manager collection.

        .DESCRIPTION
            This function retrieves exclude membership rules for Configuration Manager collections via the Admin Service API.
            You can filter by collection using CollectionName, CollectionId, or by providing a collection object.
            Additionally, you can filter the exclude rules by ExcludeCollectionName or ExcludeCollectionId.

        .PARAMETER CollectionName
            The name of the collection to retrieve exclude membership rules from.

        .PARAMETER CollectionId
            The ID of the collection to retrieve exclude membership rules from.

        .PARAMETER InputObject
            A collection object (from Get-CMASCollection) to retrieve exclude membership rules from.
            This parameter accepts pipeline input.

        .PARAMETER ExcludeCollectionName
            Optional. Filter exclude rules to only include rules for the excluded collection with this name.
            Supports wildcards.

        .PARAMETER ExcludeCollectionId
            Optional. Filter exclude rules to only include rules for the excluded collection with this ID.

        .EXAMPLE
            Get-CMASCollectionExcludeMembershipRule -CollectionName "All Systems"
            Retrieves all exclude membership rules from the "All Systems" collection.

        .EXAMPLE
            Get-CMASCollectionExcludeMembershipRule -CollectionId "SMS00001" -ExcludeCollectionName "Excluded Collection"
            Retrieves exclude membership rules from collection SMS00001 for excluded collection named "Excluded Collection".

        .EXAMPLE
            Get-CMASCollectionExcludeMembershipRule -CollectionName "My Collection" -ExcludeCollectionId "SMS00002"
            Retrieves the exclude membership rule for excluded collection ID SMS00002 in "My Collection".

        .EXAMPLE
            Get-CMASCollection -Name "My Collection" | Get-CMASCollectionExcludeMembershipRule
            Retrieves all exclude membership rules from the piped collection object.

        .EXAMPLE
            Get-CMASCollection -Name "My Collection" | Get-CMASCollectionExcludeMembershipRule -ExcludeCollectionName "TEST-*"
            Retrieves exclude membership rules for excluded collections matching "TEST-*" wildcard pattern.

        .NOTES
            This function is part of the SCCM Admin Service module.
            Requires an active connection established via Connect-CMAS.

            IMPORTANT: The Admin Service does not expose SMS_CollectionRuleExclude as a separate WMI class.
            This function retrieves the full collection object and extracts exclude membership rules from
            the CollectionRules property. This may be less efficient than the native ConfigurationManager
            cmdlet for collections with many rules.

            NOTE: This function returns EXCLUDE MEMBERSHIP RULES, not excluded collection members.
            - Exclude membership rules specify which collections should have their members excluded
            - Collections can have query rules, include rules, exclude rules, or direct membership rules
            - This cmdlet only returns exclude membership rules (where @odata.type = '#AdminService.SMS_CollectionRuleExclude')

        .LINK
            Connect-CMAS
            Get-CMASCollection
    #>
    [CmdletBinding(DefaultParameterSetName='ByName', SupportsShouldProcess=$false)]
    param(
        [Parameter(Mandatory=$true, ParameterSetName='ByName')]
        [Parameter(Mandatory=$true, ParameterSetName='ByNameAndExcludeName')]
        [Parameter(Mandatory=$true, ParameterSetName='ByNameAndExcludeId')]
        [Alias('Name')]
        [string]$CollectionName,

        [Parameter(Mandatory=$true, ParameterSetName='ById')]
        [Parameter(Mandatory=$true, ParameterSetName='ByIdAndExcludeName')]
        [Parameter(Mandatory=$true, ParameterSetName='ByIdAndExcludeId')]
        [Alias('Id')]
        [string]$CollectionId,

        [Parameter(Mandatory=$true, ParameterSetName='ByValue', ValueFromPipeline=$true)]
        [Parameter(Mandatory=$true, ParameterSetName='ByValueAndExcludeName', ValueFromPipeline=$true)]
        [Parameter(Mandatory=$true, ParameterSetName='ByValueAndExcludeId', ValueFromPipeline=$true)]
        [Alias('Collection')]
        [object]$InputObject,

        [Parameter(Mandatory=$true, ParameterSetName='ByNameAndExcludeName')]
        [Parameter(Mandatory=$true, ParameterSetName='ByIdAndExcludeName')]
        [Parameter(Mandatory=$true, ParameterSetName='ByValueAndExcludeName')]
        [SupportsWildcards()]
        [string]$ExcludeCollectionName,

        [Parameter(Mandatory=$true, ParameterSetName='ByNameAndExcludeId')]
        [Parameter(Mandatory=$true, ParameterSetName='ByIdAndExcludeId')]
        [Parameter(Mandatory=$true, ParameterSetName='ByValueAndExcludeId')]
        [string]$ExcludeCollectionId
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
            # Note: SMS_CollectionRuleExclude is not exposed as a separate class in Admin Service
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

            # Extract CollectionRules and filter for exclude membership rules only
            # Exclude membership rules have __CLASS = 'SMS_CollectionRuleExclude' OR
            # @odata.type = '#AdminService.SMS_CollectionRuleExclude' (in Admin Service API)
            if (-not $collection.CollectionRules -or $collection.CollectionRules.Count -eq 0) {
                Write-Verbose "Collection '$targetCollectionId' has no collection rules defined"
                return $null
            }

            $excludeRules = $collection.CollectionRules | Where-Object {
                $_.__CLASS -eq 'SMS_CollectionRuleExclude' -or
                $_.'@odata.type' -eq '#AdminService.SMS_CollectionRuleExcludeCollection'
            }

            if (-not $excludeRules -or @($excludeRules).Count -eq 0) {
                Write-Verbose "Collection '$targetCollectionId' has no exclude membership rules"
                return $null
            }

            # Apply exclude collection name filter if specified
            if ($ExcludeCollectionName) {
                if ($ExcludeCollectionName -match '\*') {
                    # Handle wildcards
                    $pattern = $ExcludeCollectionName -replace '\*', '.*'
                    $pattern = "^$pattern$"
                    $excludeRules = $excludeRules | Where-Object { $_.RuleName -match $pattern }
                } else {
                    # Exact match
                    $excludeRules = $excludeRules | Where-Object { $_.RuleName -eq $ExcludeCollectionName }
                }
            }

            # Apply exclude collection ID filter if specified
            if ($ExcludeCollectionId) {
                $excludeRules = $excludeRules | Where-Object { $_.ExcludeCollectionID -eq $ExcludeCollectionId }
            }

            # Format results - exclude WMI metadata and OData metadata, add CollectionID
            if ($excludeRules) {
                $rules = $excludeRules | Select-Object -Property * -ExcludeProperty @odata* |
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
            Write-Error "Failed to retrieve collection exclude membership rules: $_"
            throw $_
        }
    }

    end {
    }
}

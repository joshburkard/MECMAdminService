function Get-CMASCollectionQueryMembershipRule {
    <#
        .SYNOPSIS
            Retrieves query membership rules from a Configuration Manager collection.

        .DESCRIPTION
            This function retrieves query membership rules for Configuration Manager collections via the Admin Service API.
            You can filter by collection using CollectionName, CollectionId, or by providing a collection object.
            Additionally, you can filter the query rules by RuleName.

        .PARAMETER CollectionName
            The name of the collection to retrieve query membership rules from.

        .PARAMETER CollectionId
            The ID of the collection to retrieve query membership rules from.

        .PARAMETER InputObject
            A collection object (from Get-CMASCollection) to retrieve query membership rules from.
            This parameter accepts pipeline input.

        .PARAMETER RuleName
            Optional. Filter query rules to only include rules with this name.
            Supports wildcards.

        .EXAMPLE
            Get-CMASCollectionQueryMembershipRule -CollectionName "All Systems"
            Retrieves all query membership rules from the "All Systems" collection.

        .EXAMPLE
            Get-CMASCollectionQueryMembershipRule -CollectionId "SMS00001" -RuleName "All Systems"
            Retrieves query membership rules from collection SMS00001 for query rule named "All Systems".

        .EXAMPLE
            Get-CMASCollectionQueryMembershipRule -CollectionName "My Collection" -RuleName "*Desktop*"
            Retrieves query membership rules matching "*Desktop*" wildcard pattern in "My Collection".

        .EXAMPLE
            Get-CMASCollection -Name "My Collection" | Get-CMASCollectionQueryMembershipRule
            Retrieves all query membership rules from the piped collection object.

        .EXAMPLE
            Get-CMASCollection -Name "My Collection" | Get-CMASCollectionQueryMembershipRule -RuleName "Custom*"
            Retrieves query membership rules matching "Custom*" wildcard pattern.

        .NOTES
            This function is part of the SCCM Admin Service module.
            Requires an active connection established via Connect-CMAS.

            IMPORTANT: The Admin Service does not expose SMS_CollectionRuleQuery as a separate WMI class.
            This function retrieves the full collection object and extracts query membership rules from
            the CollectionRules property. This may be less efficient than the native ConfigurationManager
            cmdlet for collections with many rules.

            NOTE: This function returns QUERY MEMBERSHIP RULES, not query results or collection members.
            - Query membership rules define WQL queries that dynamically populate collections
            - Collections can have query rules, include rules, exclude rules, or direct membership rules
            - This cmdlet only returns query membership rules (where @odata.type = '#AdminService.SMS_CollectionRuleQuery')

        .LINK
            Connect-CMAS
            Get-CMASCollection
    #>
    [CmdletBinding(DefaultParameterSetName='ByName', SupportsShouldProcess=$false)]
    param(
        [Parameter(Mandatory=$true, ParameterSetName='ByName')]
        [Alias('Name')]
        [string]$CollectionName,

        [Parameter(Mandatory=$true, ParameterSetName='ById')]
        [Alias('Id')]
        [string]$CollectionId,

        [Parameter(Mandatory=$true, ParameterSetName='ByValue', ValueFromPipeline=$true)]
        [Alias('Collection')]
        [object]$InputObject,

        [Parameter(Mandatory=$false)]
        [SupportsWildcards()]
        [string]$RuleName
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
            # Note: SMS_CollectionRuleQuery is not exposed as a separate class in Admin Service
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

            # Extract CollectionRules and filter for query membership rules only
            # Query membership rules have __CLASS = 'SMS_CollectionRuleQuery' OR
            # @odata.type = '#AdminService.SMS_CollectionRuleQuery' (in Admin Service API)
            if (-not $collection.CollectionRules -or $collection.CollectionRules.Count -eq 0) {
                Write-Verbose "Collection '$targetCollectionId' has no collection rules defined"
                return $null
            }

            $queryRules = $collection.CollectionRules | Where-Object {
                $_.__CLASS -eq 'SMS_CollectionRuleQuery' -or
                $_.'@odata.type' -eq '#AdminService.SMS_CollectionRuleQuery'
            }

            if (-not $queryRules -or @($queryRules).Count -eq 0) {
                Write-Verbose "Collection '$targetCollectionId' has no query membership rules"
                return $null
            }

            # Apply rule name filter if specified
            if ($RuleName) {
                if ($RuleName -match '\*') {
                    # Handle wildcards
                    $pattern = $RuleName -replace '\*', '.*'
                    $pattern = "^$pattern$"
                    $queryRules = $queryRules | Where-Object { $_.RuleName -match $pattern }
                } else {
                    # Exact match
                    $queryRules = $queryRules | Where-Object { $_.RuleName -eq $RuleName }
                }
            }

            # Format results - exclude WMI metadata and OData metadata, add CollectionID
            if ($queryRules) {
                $rules = $queryRules | Select-Object -Property * -ExcludeProperty @odata* |
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
            Write-Error "Failed to retrieve collection query membership rules: $_"
            throw $_
        }
    }

    end {
    }
}

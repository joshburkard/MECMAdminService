function Remove-CMASCollectionMembershipRule {
    <#
        .SYNOPSIS
            Removes a membership rule from a Configuration Manager collection.

        .DESCRIPTION
            This function removes membership rules from Configuration Manager collections via the Admin Service API.
            Supports removing Direct, Query, Include, and Exclude membership rules.

            - Direct rules: Remove specific devices/users by ResourceID or ResourceName
            - Query rules: Remove dynamic membership based on rule name
            - Include rules: Remove include rules by collection name or ID
            - Exclude rules: Remove exclude rules by collection name or ID

        .PARAMETER CollectionName
            The name of the collection to remove the membership rule from.

        .PARAMETER CollectionId
            The ID of the collection to remove the membership rule from.

        .PARAMETER InputObject
            A collection object (from Get-CMASCollection) to remove the membership rule from.
            This parameter accepts pipeline input.

        .PARAMETER RuleType
            The type of membership rule to remove: Direct, Query, Include, or Exclude.

        .PARAMETER ResourceId
            The ResourceID of the device/user to remove (for Direct rules).
            Can be an array to remove multiple resources.

        .PARAMETER ResourceName
            The name of the device/user to remove (for Direct rules).
            Supports wildcards to remove multiple matching rules.

        .PARAMETER RuleName
            The name of the query membership rule to remove (for Query rules).
            Supports wildcards to remove multiple matching rules.

        .PARAMETER IncludeCollectionId
            The CollectionID to remove from include rules (for Include rules).

        .PARAMETER IncludeCollectionName
            The name of the collection to remove from include rules (for Include rules).
            Supports wildcards to remove multiple matching rules.

        .PARAMETER ExcludeCollectionId
            The CollectionID to remove from exclude rules (for Exclude rules).

        .PARAMETER ExcludeCollectionName
            The name of the collection to remove from exclude rules (for Exclude rules).
            Supports wildcards to remove multiple matching rules.

        .PARAMETER Force
            Skip confirmation prompts.

        .PARAMETER PassThru
            Returns the updated collection object after removing the rule.

        .EXAMPLE
            Remove-CMASCollectionMembershipRule -CollectionName "All Systems" -RuleType Direct -ResourceId 16777220
            Removes the direct membership rule for resource ID 16777220 from the "All Systems" collection.

        .EXAMPLE
            Remove-CMASCollectionMembershipRule -CollectionId "SMS00001" -RuleType Direct -ResourceName "SERVER01"
            Removes the direct membership rule for the device named "SERVER01" from collection SMS00001.

        .EXAMPLE
            Remove-CMASCollectionMembershipRule -CollectionName "Test Collection" -RuleType Query -RuleName "Test Servers"
            Removes the query membership rule named "Test Servers" from "Test Collection".

        .EXAMPLE
            Remove-CMASCollectionMembershipRule -CollectionName "Test Collection" -RuleType Query -RuleName "*Test*"
            Removes all query membership rules containing "Test" in their name.

        .EXAMPLE
            Remove-CMASCollectionMembershipRule -CollectionName "Production Servers" -RuleType Include -IncludeCollectionName "All Servers"
            Removes the include rule for "All Servers" collection.

        .EXAMPLE
            Remove-CMASCollectionMembershipRule -CollectionName "Workstations" -RuleType Exclude -ExcludeCollectionName "Test Devices"
            Removes the exclude rule for "Test Devices" collection.

        .EXAMPLE
            Get-CMASCollection -Name "My Collection" | Remove-CMASCollectionMembershipRule -RuleType Direct -ResourceId @(16777220, 16777221)
            Removes multiple direct membership rules from the piped collection object.

        .EXAMPLE
            Remove-CMASCollectionMembershipRule -CollectionName "Test Collection" -RuleType Direct -ResourceName "TEST-*" -Force
            Removes all direct membership rules for devices starting with "TEST-" without confirmation.

        .NOTES
            This function is part of the SCCM Admin Service module.
            Requires an active connection established via Connect-CMAS.

            The Admin Service uses the DeleteMembershipRule WMI method on the SMS_Collection class
            to remove membership rules. This function retrieves the rule objects first, then calls
            the delete method via POST for each rule to remove.

            When using wildcards, the function will prompt for confirmation before removing each rule
            unless -Force is specified.

        .LINK
            Connect-CMAS
            Get-CMASCollection
            Add-CMASCollectionMembershipRule
            Get-CMASCollectionDirectMembershipRule
            Get-CMASCollectionQueryMembershipRule
            Get-CMASCollectionIncludeMembershipRule
            Get-CMASCollectionExcludeMembershipRule
    #>
    [CmdletBinding(DefaultParameterSetName='ByName', SupportsShouldProcess=$true, ConfirmImpact='High')]
    param(
        [Parameter(Mandatory=$true, ParameterSetName='ByName')]
        [Parameter(Mandatory=$true, ParameterSetName='ByNameDirect')]
        [Parameter(Mandatory=$true, ParameterSetName='ByNameQuery')]
        [Parameter(Mandatory=$true, ParameterSetName='ByNameInclude')]
        [Parameter(Mandatory=$true, ParameterSetName='ByNameExclude')]
        [Alias('Name')]
        [string]$CollectionName,

        [Parameter(Mandatory=$true, ParameterSetName='ById')]
        [Parameter(Mandatory=$true, ParameterSetName='ByIdDirect')]
        [Parameter(Mandatory=$true, ParameterSetName='ByIdQuery')]
        [Parameter(Mandatory=$true, ParameterSetName='ByIdInclude')]
        [Parameter(Mandatory=$true, ParameterSetName='ByIdExclude')]
        [Alias('Id')]
        [string]$CollectionId,

        [Parameter(Mandatory=$true, ParameterSetName='ByValue', ValueFromPipeline=$true)]
        [Parameter(Mandatory=$true, ParameterSetName='ByValueDirect', ValueFromPipeline=$true)]
        [Parameter(Mandatory=$true, ParameterSetName='ByValueQuery', ValueFromPipeline=$true)]
        [Parameter(Mandatory=$true, ParameterSetName='ByValueInclude', ValueFromPipeline=$true)]
        [Parameter(Mandatory=$true, ParameterSetName='ByValueExclude', ValueFromPipeline=$true)]
        [Alias('Collection')]
        [object]$InputObject,

        [Parameter(Mandatory=$true)]
        [ValidateSet('Direct', 'Query', 'Include', 'Exclude')]
        [string]$RuleType,

        [Parameter(Mandatory=$false, ParameterSetName='ByNameDirect')]
        [Parameter(Mandatory=$false, ParameterSetName='ByIdDirect')]
        [Parameter(Mandatory=$false, ParameterSetName='ByValueDirect')]
        [long[]]$ResourceId,

        [Parameter(Mandatory=$false, ParameterSetName='ByNameDirect')]
        [Parameter(Mandatory=$false, ParameterSetName='ByIdDirect')]
        [Parameter(Mandatory=$false, ParameterSetName='ByValueDirect')]
        [SupportsWildcards()]
        [string]$ResourceName,

        [Parameter(Mandatory=$false, ParameterSetName='ByNameQuery')]
        [Parameter(Mandatory=$false, ParameterSetName='ByIdQuery')]
        [Parameter(Mandatory=$false, ParameterSetName='ByValueQuery')]
        [SupportsWildcards()]
        [string]$RuleName,

        [Parameter(Mandatory=$false, ParameterSetName='ByNameInclude')]
        [Parameter(Mandatory=$false, ParameterSetName='ByIdInclude')]
        [Parameter(Mandatory=$false, ParameterSetName='ByValueInclude')]
        [string]$IncludeCollectionId,

        [Parameter(Mandatory=$false, ParameterSetName='ByNameInclude')]
        [Parameter(Mandatory=$false, ParameterSetName='ByIdInclude')]
        [Parameter(Mandatory=$false, ParameterSetName='ByValueInclude')]
        [SupportsWildcards()]
        [string]$IncludeCollectionName,

        [Parameter(Mandatory=$false, ParameterSetName='ByNameExclude')]
        [Parameter(Mandatory=$false, ParameterSetName='ByIdExclude')]
        [Parameter(Mandatory=$false, ParameterSetName='ByValueExclude')]
        [string]$ExcludeCollectionId,

        [Parameter(Mandatory=$false, ParameterSetName='ByNameExclude')]
        [Parameter(Mandatory=$false, ParameterSetName='ByIdExclude')]
        [Parameter(Mandatory=$false, ParameterSetName='ByValueExclude')]
        [SupportsWildcards()]
        [string]$ExcludeCollectionName,

        [Parameter(Mandatory=$false)]
        [switch]$Force,

        [Parameter(Mandatory=$false)]
        [switch]$PassThru
    )

    begin {
        # Validate connection
        if (-not $script:CMASConnection.SiteServer) {
            throw "No active connection to SCCM Admin Service. Run Connect-CMAS first."
        }

        # Validate rule-specific parameters
        if ($RuleType -eq 'Direct') {
            if (-not $ResourceId -and -not $ResourceName) {
                throw "For Direct membership rules, either ResourceId or ResourceName must be specified."
            }
        }
        elseif ($RuleType -eq 'Query') {
            if (-not $RuleName) {
                throw "For Query membership rules, RuleName must be specified."
            }
        }
        elseif ($RuleType -eq 'Include') {
            if (-not $IncludeCollectionId -and -not $IncludeCollectionName) {
                throw "For Include membership rules, either IncludeCollectionId or IncludeCollectionName must be specified."
            }
        }
        elseif ($RuleType -eq 'Exclude') {
            if (-not $ExcludeCollectionId -and -not $ExcludeCollectionName) {
                throw "For Exclude membership rules, either ExcludeCollectionId or ExcludeCollectionName must be specified."
            }
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

            # Verify collection exists
            $path = "wmi/SMS_Collection('$targetCollectionId')"
            Write-Verbose "Verifying collection exists with path: $path"
            $res = Invoke-CMASApi -Path $path

            if (-not $res.value -or $res.value.Count -eq 0) {
                Write-Error "Collection '$targetCollectionId' not found."
                return
            }

            # Get rules to remove based on RuleType
            $rulesRemoved = 0
            $rulesToRemove = @()

            switch ($RuleType) {
                'Direct' {
                    # Get direct membership rules to remove
                    if ($ResourceId) {
                        foreach ($resId in $ResourceId) {
                            Write-Verbose "Getting direct membership rule for ResourceID '$resId'..."
                            $rule = Get-CMASCollectionDirectMembershipRule -CollectionId $targetCollectionId -ResourceId $resId
                            if ($rule) {
                                $rulesToRemove += $rule
                            } else {
                                Write-Warning "Direct membership rule for ResourceID $resId not found in collection '$targetCollectionId'."
                            }
                        }
                    }
                    if ($ResourceName) {
                        Write-Verbose "Getting direct membership rules for ResourceName '$ResourceName'..."
                        $rules = Get-CMASCollectionDirectMembershipRule -CollectionId $targetCollectionId -ResourceName $ResourceName
                        if ($rules) {
                            $rulesToRemove += @($rules)
                        } else {
                            Write-Warning "No direct membership rules matching ResourceName '$ResourceName' found in collection '$targetCollectionId'."
                        }
                    }
                }

                'Query' {
                    Write-Verbose "Getting query membership rules for RuleName '$RuleName'..."
                    $rules = Get-CMASCollectionQueryMembershipRule -CollectionId $targetCollectionId -RuleName $RuleName
                    if ($rules) {
                        $rulesToRemove += @($rules)
                    } else {
                        Write-Warning "No query membership rules matching RuleName '$RuleName' found in collection '$targetCollectionId'."
                    }
                }

                'Include' {
                    # Resolve IncludeCollectionName to ID if needed
                    $includeCollId = $IncludeCollectionId

                    if ($IncludeCollectionName -and -not $includeCollId) {
                        # Check if wildcard
                        if ($IncludeCollectionName -match '\*') {
                            Write-Verbose "Getting include membership rules for IncludeCollectionName '$IncludeCollectionName'..."
                            $rules = Get-CMASCollectionIncludeMembershipRule -CollectionId $targetCollectionId -IncludeCollectionName $IncludeCollectionName
                            if ($rules) {
                                $rulesToRemove += @($rules)
                            } else {
                                Write-Warning "No include membership rules matching IncludeCollectionName '$IncludeCollectionName' found in collection '$targetCollectionId'."
                            }
                        } else {
                            Write-Verbose "Resolving IncludeCollectionName '$IncludeCollectionName' to CollectionID..."
                            $includeCollection = Get-CMASCollection -Name $IncludeCollectionName
                            if (-not $includeCollection) {
                                Write-Error "Include collection with name '$IncludeCollectionName' not found."
                                return
                            }
                            $includeCollId = $includeCollection.CollectionID
                        }
                    }

                    if ($includeCollId) {
                        Write-Verbose "Getting include membership rule for CollectionID '$includeCollId'..."
                        $rule = Get-CMASCollectionIncludeMembershipRule -CollectionId $targetCollectionId -IncludeCollectionId $includeCollId
                        if ($rule) {
                            $rulesToRemove += $rule
                        } else {
                            Write-Warning "Include membership rule for CollectionID '$includeCollId' not found in collection '$targetCollectionId'."
                        }
                    }
                }

                'Exclude' {
                    # Resolve ExcludeCollectionName to ID if needed
                    $excludeCollId = $ExcludeCollectionId

                    if ($ExcludeCollectionName -and -not $excludeCollId) {
                        # Check if wildcard
                        if ($ExcludeCollectionName -match '\*') {
                            Write-Verbose "Getting exclude membership rules for ExcludeCollectionName '$ExcludeCollectionName'..."
                            $rules = Get-CMASCollectionExcludeMembershipRule -CollectionId $targetCollectionId -ExcludeCollectionName $ExcludeCollectionName
                            if ($rules) {
                                $rulesToRemove += @($rules)
                            } else {
                                Write-Warning "No exclude membership rules matching ExcludeCollectionName '$ExcludeCollectionName' found in collection '$targetCollectionId'."
                            }
                        } else {
                            Write-Verbose "Resolving ExcludeCollectionName '$ExcludeCollectionName' to CollectionID..."
                            $excludeCollection = Get-CMASCollection -Name $ExcludeCollectionName
                            if (-not $excludeCollection) {
                                Write-Error "Exclude collection with name '$ExcludeCollectionName' not found."
                                return
                            }
                            $excludeCollId = $excludeCollection.CollectionID
                        }
                    }

                    if ($excludeCollId) {
                        Write-Verbose "Getting exclude membership rule for CollectionID '$excludeCollId'..."
                        $rule = Get-CMASCollectionExcludeMembershipRule -CollectionId $targetCollectionId -ExcludeCollectionId $excludeCollId
                        if ($rule) {
                            $rulesToRemove += $rule
                        } else {
                            Write-Warning "Exclude membership rule for CollectionID '$excludeCollId' not found in collection '$targetCollectionId'."
                        }
                    }
                }
            }

            # Remove each rule
            foreach ($rule in $rulesToRemove) {
                $ruleDescription = switch ($RuleType) {
                    'Direct' { "Direct membership rule for '$($rule.RuleName)' (ResourceID $($rule.ResourceID))" }
                    'Query' { "Query membership rule '$($rule.RuleName)'" }
                    'Include' { "Include membership rule for collection '$($rule.RuleName)' ($($rule.IncludeCollectionID))" }
                    'Exclude' { "Exclude membership rule for collection '$($rule.RuleName)' ($($rule.ExcludeCollectionID))" }
                }

                if ($Force -or $PSCmdlet.ShouldProcess("Collection '$targetCollectionId'", "Remove $ruleDescription")) {
                    Write-Verbose "Removing $ruleDescription from collection '$targetCollectionId'"

                    # Build the rule object to delete - copy all properties from the rule except metadata
                    $ruleToDelete = @{
                        '@odata.type' = switch ($RuleType) {
                            'Direct' { '#AdminService.SMS_CollectionRuleDirect' }
                            'Query' { '#AdminService.SMS_CollectionRuleQuery' }
                            'Include' { '#AdminService.SMS_CollectionRuleIncludeCollection' }
                            'Exclude' { '#AdminService.SMS_CollectionRuleExcludeCollection' }
                        }
                    }

                    # Copy all properties from the retrieved rule (excluding metadata properties)
                    # This ensures the DeleteMembershipRule method can uniquely identify the rule
                    $rule.PSObject.Properties | Where-Object {
                        $_.Name -notlike '@odata.*' -and
                        $_.Name -notlike '__*' -and
                        $_.Name -ne 'CollectionID' -and
                        $null -ne $_.Value
                    } | ForEach-Object {
                        $ruleToDelete[$_.Name] = $_.Value
                    }

                    $body = @{
                        collectionRule = $ruleToDelete
                    }

                    try {
                        # Call DeleteMembershipRule WMI method
                        $methodPath = "wmi/SMS_Collection('$targetCollectionId')/AdminService.DeleteMembershipRule"
                        $result = Invoke-CMASApi -Path $methodPath -Method POST -Body $body
                        Write-Verbose "Successfully removed $ruleDescription"
                        $rulesRemoved++
                    }
                    catch {
                        # Check if error is due to rule not existing
                        if ($_.Exception.Message -like "*not found*" -or $_.Exception.Message -like "*does not exist*") {
                            Write-Warning "$ruleDescription may not exist in collection."
                        }
                        else {
                            Write-Error "Failed to remove $ruleDescription : $_"
                            throw
                        }
                    }
                }
            }

            if ($rulesRemoved -eq 0) {
                Write-Warning "No membership rules were removed from collection '$targetCollectionId'."
            } else {
                Write-Verbose "Successfully removed $rulesRemoved membership rule(s) from collection '$targetCollectionId'."
            }

            # Return updated collection if PassThru is specified and rules were removed
            if ($PassThru -and $rulesRemoved -gt 0) {
                Get-CMASCollection -CollectionId $targetCollectionId
            }
        }
        catch {
            Write-Error "Failed to remove membership rule from collection: $_"
            throw $_
        }
    }

    end {
    }
}

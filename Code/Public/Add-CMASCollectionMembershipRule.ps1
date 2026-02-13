function Add-CMASCollectionMembershipRule {
    <#
        .SYNOPSIS
            Adds a membership rule to a Configuration Manager collection.

        .DESCRIPTION
            This function adds membership rules to Configuration Manager collections via the Admin Service API.
            Supports adding Direct, Query, Include, and Exclude membership rules.

            - Direct rules: Add specific devices/users by ResourceID
            - Query rules: Add dynamic membership based on WQL queries
            - Include rules: Include members from another collection
            - Exclude rules: Exclude members from another collection

        .PARAMETER CollectionName
            The name of the collection to add the membership rule to.

        .PARAMETER CollectionId
            The ID of the collection to add the membership rule to.

        .PARAMETER InputObject
            A collection object (from Get-CMASCollection) to add the membership rule to.
            This parameter accepts pipeline input.

        .PARAMETER RuleType
            The type of membership rule to add: Direct, Query, Include, or Exclude.

        .PARAMETER ResourceId
            The ResourceID of the device/user to add (for Direct rules).
            Can be an array to add multiple resources.

        .PARAMETER ResourceName
            The name of the device/user to add (for Direct rules).
            If specified, the function will look up the ResourceID automatically.

        .PARAMETER QueryExpression
            The WQL query expression (for Query rules).
            Example: "select SMS_R_SYSTEM.ResourceID from SMS_R_System where SMS_R_System.Name like 'SERVER%'"

        .PARAMETER RuleName
            The name of the query membership rule (for Query rules).
            Required when adding a Query rule.

        .PARAMETER IncludeCollectionId
            The CollectionID to include members from (for Include rules).

        .PARAMETER IncludeCollectionName
            The name of the collection to include members from (for Include rules).
            If specified, the function will look up the CollectionID automatically.

        .PARAMETER ExcludeCollectionId
            The CollectionID to exclude members from (for Exclude rules).

        .PARAMETER ExcludeCollectionName
            The name of the collection to exclude members from (for Exclude rules).
            If specified, the function will look up the CollectionID automatically.

        .PARAMETER PassThru
            Returns the updated collection object after adding the rule.

        .EXAMPLE
            Add-CMASCollectionMembershipRule -CollectionName "All Systems" -RuleType Direct -ResourceId 16777220
            Adds a direct membership rule for resource ID 16777220 to the "All Systems" collection.

        .EXAMPLE
            Add-CMASCollectionMembershipRule -CollectionId "SMS00001" -RuleType Direct -ResourceName "SERVER01"
            Adds a direct membership rule for the device named "SERVER01" to collection SMS00001.

        .EXAMPLE
            $query = "select SMS_R_SYSTEM.ResourceID from SMS_R_System where SMS_R_System.Name like 'TEST-%'"
            Add-CMASCollectionMembershipRule -CollectionName "Test Collection" -RuleType Query -QueryExpression $query -RuleName "Test Servers"
            Adds a query membership rule to "Test Collection" that includes devices starting with "TEST-".

        .EXAMPLE
            Add-CMASCollectionMembershipRule -CollectionName "Production Servers" -RuleType Include -IncludeCollectionName "All Servers"
            Adds an include rule to include all members from "All Servers" collection.

        .EXAMPLE
            Add-CMASCollectionMembershipRule -CollectionName "Workstations" -RuleType Exclude -ExcludeCollectionName "Test Devices"
            Adds an exclude rule to exclude members from "Test Devices" collection.

        .EXAMPLE
            Get-CMASCollection -Name "My Collection" | Add-CMASCollectionMembershipRule -RuleType Direct -ResourceId @(16777220, 16777221, 16777222)
            Adds multiple direct membership rules to the piped collection object.

        .NOTES
            This function is part of the SCCM Admin Service module.
            Requires an active connection established via Connect-CMAS.

            The Admin Service uses the AddMembershipRule WMI method on the SMS_Collection class
            to add membership rules. This function calls this method via POST for each rule to add.
            The WMI method handles duplicate checking and validation on the server side.

            WARNING: Attempting to add duplicate rules may result in errors from the server,
            which will be caught and displayed as warnings.

        .LINK
            Connect-CMAS
            Get-CMASCollection
            Get-CMASCollectionDirectMembershipRule
            Get-CMASCollectionQueryMembershipRule
            Get-CMASCollectionIncludeMembershipRule
            Get-CMASCollectionExcludeMembershipRule
    #>
    [CmdletBinding(DefaultParameterSetName='ByName', SupportsShouldProcess=$true, ConfirmImpact='Medium')]
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

        [Parameter(Mandatory=$true)]
        [ValidateSet('Direct', 'Query', 'Include', 'Exclude')]
        [string]$RuleType,

        [Parameter(Mandatory=$false)]
        [long[]]$ResourceId,

        [Parameter(Mandatory=$false)]
        [string[]]$ResourceName,

        [Parameter(Mandatory=$false)]
        [string]$QueryExpression,

        [Parameter(Mandatory=$false)]
        [string]$RuleName,

        [Parameter(Mandatory=$false)]
        [string]$IncludeCollectionId,

        [Parameter(Mandatory=$false)]
        [string]$IncludeCollectionName,

        [Parameter(Mandatory=$false)]
        [string]$ExcludeCollectionId,

        [Parameter(Mandatory=$false)]
        [string]$ExcludeCollectionName,

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
            if (-not $QueryExpression -or -not $RuleName) {
                throw "For Query membership rules, both QueryExpression and RuleName must be specified."
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

            # Build new rule(s) based on RuleType and add them using AddMembershipRule WMI method
            $rulesAdded = 0

            switch ($RuleType) {
                'Direct' {
                    # Resolve ResourceNames to ResourceIds if needed
                    $resourceIdsToAdd = @()
                    $resourceNamesToAdd = @{}  # Hashtable to map ResourceID to ResourceName

                    if ($ResourceId) {
                        foreach ($resId in $ResourceId) {
                            $resourceIdsToAdd += $resId
                            # Get device name for this ResourceID
                            Write-Verbose "Resolving ResourceID '$resId' to device name..."
                            $device = Get-CMASDevice -ResourceId $resId
                            if ($device) {
                                $resourceNamesToAdd[$resId] = $device.Name
                            }
                            else {
                                Write-Warning "Could not resolve ResourceID $resId to device name. RuleName will be set to ResourceID."
                                $resourceNamesToAdd[$resId] = "Resource_$resId"
                            }
                        }
                    }
                    if ($ResourceName) {
                        foreach ($name in $ResourceName) {
                            Write-Verbose "Resolving ResourceName '$name' to ResourceID..."
                            $device = Get-CMASDevice -Name $name
                            if (-not $device) {
                                Write-Error "Device with name '$name' not found."
                                continue
                            }
                            $resourceIdsToAdd += $device.ResourceID
                            $resourceNamesToAdd[$device.ResourceID] = $device.Name
                        }
                    }

                    # Add direct membership rules one at a time
                    foreach ($resId in $resourceIdsToAdd) {
                        $resName = $resourceNamesToAdd[$resId]

                        # Check if direct rule for this ResourceID already exists
                        Write-Verbose "Checking for existing direct rule for ResourceID '$resId'..."
                        $existingRule = Get-CMASCollectionDirectMembershipRule -CollectionId $targetCollectionId -ResourceId $resId
                        if ($existingRule) {
                            Write-Warning "Direct membership rule for device '$resName' (ResourceID $resId) already exists in collection '$targetCollectionId'."
                            continue
                        }

                        $ruleDescription = "Direct membership rule for device '$resName' (ResourceID $resId)"

                        if ($PSCmdlet.ShouldProcess("Collection '$targetCollectionId'", "Add $ruleDescription")) {
                            Write-Verbose "Adding $ruleDescription to collection '$targetCollectionId'"

                            $newRule = @{
                                '@odata.type' = '#AdminService.SMS_CollectionRuleDirect'
                                ResourceClassName = 'SMS_R_System'
                                ResourceID = $resId
                                RuleName = $resName
                            }

                            $body = @{
                                collectionRule = $newRule
                            }

                            try {
                                # Call AddMembershipRule WMI method
                                $methodPath = "wmi/SMS_Collection('$targetCollectionId')/AdminService.AddMembershipRule"
                                $result = Invoke-CMASApi -Path $methodPath -Method POST -Body $body
                                Write-Verbose "Successfully added direct membership rule for ResourceID $resId"
                                $rulesAdded++
                            }
                            catch {
                                # Check if error is due to duplicate
                                if ($_.Exception.Message -like "*already exists*" -or $_.Exception.Message -like "*duplicate*") {
                                    Write-Warning "Direct membership rule for ResourceID $resId may already exist in collection."
                                }
                                else {
                                    throw
                                }
                            }
                        }
                    }
                }

                'Query' {
                    # Check if a query rule with the same name already exists
                    Write-Verbose "Checking for existing query rule with name '$RuleName'..."
                    $existingRule = Get-CMASCollectionQueryMembershipRule -CollectionId $targetCollectionId -RuleName $RuleName
                    if ($existingRule) {
                        Write-Warning "Query membership rule with name '$RuleName' already exists in collection '$targetCollectionId'."
                        return
                    }

                    $ruleDescription = "Query membership rule '$RuleName'"

                    if ($PSCmdlet.ShouldProcess("Collection '$targetCollectionId'", "Add $ruleDescription")) {
                        Write-Verbose "Adding $ruleDescription to collection '$targetCollectionId'"

                        $newRule = @{
                            '@odata.type' = '#AdminService.SMS_CollectionRuleQuery'
                            RuleName = $RuleName
                            QueryExpression = $QueryExpression
                        }

                        $body = @{
                            collectionRule = $newRule
                        }

                        try {
                            # Call AddMembershipRule WMI method
                            $methodPath = "wmi/SMS_Collection('$targetCollectionId')/AdminService.AddMembershipRule"
                            $result = Invoke-CMASApi -Path $methodPath -Method POST -Body $body
                            Write-Verbose "Successfully added query membership rule '$RuleName'"
                            $rulesAdded++
                        }
                        catch {
                            if ($_.Exception.Message -like "*already exists*" -or $_.Exception.Message -like "*duplicate*") {
                                Write-Warning "Query membership rule with name '$RuleName' may already exist in collection."
                            }
                            else {
                                throw
                            }
                        }
                    }
                }

                'Include' {
                    # Resolve IncludeCollectionName to ID if needed, or get name from ID
                    $includeCollId = $IncludeCollectionId
                    $includeCollName = $IncludeCollectionName

                    if ($IncludeCollectionName -and -not $includeCollId) {
                        Write-Verbose "Resolving IncludeCollectionName '$IncludeCollectionName' to CollectionID..."
                        $includeCollection = Get-CMASCollection -Name $IncludeCollectionName
                        if (-not $includeCollection) {
                            Write-Error "Include collection with name '$IncludeCollectionName' not found."
                            return
                        }
                        $includeCollId = $includeCollection.CollectionID
                        $includeCollName = $includeCollection.Name
                    }
                    elseif ($includeCollId -and -not $IncludeCollectionName) {
                        Write-Verbose "Resolving IncludeCollectionId '$includeCollId' to CollectionName..."
                        $includeCollection = Get-CMASCollection -CollectionId $includeCollId
                        if (-not $includeCollection) {
                            Write-Error "Include collection with ID '$includeCollId' not found."
                            return
                        }
                        $includeCollName = $includeCollection.Name
                    }

                    # Check if an include rule for this collection already exists
                    Write-Verbose "Checking for existing include rule for collection '$includeCollId'..."
                    $existingRule = Get-CMASCollectionIncludeMembershipRule -CollectionId $targetCollectionId -IncludeCollectionId $includeCollId
                    if ($existingRule) {
                        Write-Warning "Include membership rule for collection '$includeCollName' ($includeCollId) already exists in collection '$targetCollectionId'."
                        return
                    }

                    $ruleDescription = "Include membership rule for collection '$includeCollName' ($includeCollId)"

                    if ($PSCmdlet.ShouldProcess("Collection '$targetCollectionId'", "Add $ruleDescription")) {
                        Write-Verbose "Adding $ruleDescription to collection '$targetCollectionId'"

                        $newRule = @{
                            '@odata.type' = '#AdminService.SMS_CollectionRuleIncludeCollection'
                            RuleName = $includeCollName
                            IncludeCollectionID = $includeCollId
                        }

                        $body = @{
                            collectionRule = $newRule
                        }

                        try {
                            # Call AddMembershipRule WMI method
                            $methodPath = "wmi/SMS_Collection('$targetCollectionId')/AdminService.AddMembershipRule"
                            $result = Invoke-CMASApi -Path $methodPath -Method POST -Body $body
                            Write-Verbose "Successfully added include membership rule for CollectionID $includeCollId"
                            $rulesAdded++
                        }
                        catch {
                            if ($_.Exception.Message -like "*already exists*" -or $_.Exception.Message -like "*duplicate*") {
                                Write-Warning "Include membership rule for CollectionID $includeCollId may already exist in collection."
                            }
                            else {
                                throw
                            }
                        }
                    }
                }

                'Exclude' {
                    # Resolve ExcludeCollectionName to ID if needed, or get name from ID
                    $excludeCollId = $ExcludeCollectionId
                    $excludeCollName = $ExcludeCollectionName

                    if ($ExcludeCollectionName -and -not $excludeCollId) {
                        Write-Verbose "Resolving ExcludeCollectionName '$ExcludeCollectionName' to CollectionID..."
                        $excludeCollection = Get-CMASCollection -Name $ExcludeCollectionName
                        if (-not $excludeCollection) {
                            Write-Error "Exclude collection with name '$ExcludeCollectionName' not found."
                            return
                        }
                        $excludeCollId = $excludeCollection.CollectionID
                        $excludeCollName = $excludeCollection.Name
                    }
                    elseif ($excludeCollId -and -not $excludeCollId) {
                        Write-Verbose "Resolving ExcludeCollectionId '$excludeCollId' to CollectionName..."
                        $excludeCollection = Get-CMASCollection -CollectionId $excludeCollId
                        if (-not $excludeCollection) {
                            Write-Error "Exclude collection with ID '$excludeCollId' not found."
                            return
                        }
                        $excludeCollName = $excludeCollection.Name
                    }

                    # Check if an exclude rule for this collection already exists
                    Write-Verbose "Checking for existing exclude rule for collection '$excludeCollId'..."
                    $existingRule = Get-CMASCollectionExcludeMembershipRule -CollectionId $targetCollectionId -ExcludeCollectionId $excludeCollId
                    if ($existingRule) {
                        Write-Warning "Exclude membership rule for collection '$excludeCollName' ($excludeCollId) already exists in collection '$targetCollectionId'."
                        return
                    }

                    $ruleDescription = "Exclude membership rule for collection '$excludeCollName' ($excludeCollId)"

                    if ($PSCmdlet.ShouldProcess("Collection '$targetCollectionId'", "Add $ruleDescription")) {
                        Write-Verbose "Adding $ruleDescription to collection '$targetCollectionId'"

                        $newRule = @{
                            '@odata.type' = '#AdminService.SMS_CollectionRuleExcludeCollection'
                            RuleName = $excludeCollName
                            ExcludeCollectionID = $excludeCollId
                        }

                        $body = @{
                            collectionRule = $newRule
                        }

                        try {
                            # Call AddMembershipRule WMI method
                            $methodPath = "wmi/SMS_Collection('$targetCollectionId')/AdminService.AddMembershipRule"
                            $result = Invoke-CMASApi -Path $methodPath -Method POST -Body $body
                            Write-Verbose "Successfully added exclude membership rule for CollectionID $excludeCollId"
                            $rulesAdded++
                        }
                        catch {
                            if ($_.Exception.Message -like "*already exists*" -or $_.Exception.Message -like "*duplicate*") {
                                Write-Warning "Exclude membership rule for CollectionID $excludeCollId may already exist in collection."
                            }
                            else {
                                throw
                            }
                        }
                    }
                }
            }

            # Return updated collection if PassThru is specified and rules were added
            if ($PassThru -and $rulesAdded -gt 0) {
                Get-CMASCollection -CollectionId $targetCollectionId
            }
        }
        catch {
            Write-Error "Failed to add membership rule to collection: $_"
            throw $_
        }
    }

    end {
    }
}

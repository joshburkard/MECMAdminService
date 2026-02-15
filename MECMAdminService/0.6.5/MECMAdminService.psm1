<#
    Generated at 02/15/2026 10:28:03 by Josua Burkard
#>
#region namespace MECMAdminService
function Invoke-CMASApi {
    <#
        .SYNOPSIS
            Invokes a REST API call to the Configuration Manager Admin Service.

        .DESCRIPTION
            This function allows you to interact with the Configuration Manager Admin Service using REST API calls. You
            can specify the HTTP method, request body, and credentials for authentication.

        .PARAMETER Path
            The API endpoint path (e.g., "wmi/SMS_Collection" or "v1.0/AdministrationServiceInformation").

        .PARAMETER Method
            The HTTP method to use for the request (GET, POST, PUT, DELETE). Default is GET.

        .PARAMETER Body
            The request body to send with POST or PUT requests. This should be a PowerShell object that will be converted to JSON.

        .PARAMETER Credential
            The credentials to use for authentication. If not provided, the function will use the current user's credentials.

        .PARAMETER SiteServer
            The hostname or IP address of the Configuration Manager Site Server. This parameter is required.

        .EXAMPLE
            # Example 1: Get a list of collections using default credentials
            Invoke-CMASApi -Path "wmi/SMS_Collection" -SiteServer "sccm.domain.local"

        .EXAMPLE
            # Example 2: Get administration service information using specific credentials
            $cred = Get-Credential
            Invoke-CMSApi -Path "v1.0/AdministrationServiceInformation" -SiteServer "sccm.domain.local" -Credential $cred

        .NOTES
            This function is part of the SCCM Admin Service module.

    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,

        [Parameter(Mandatory=$false)]
        [ValidateSet("GET","POST","PUT","PATCH","DELETE")]
        [string]$Method = "GET",

        [Parameter(Mandatory=$false)]
        [object]$Body,

        [Parameter(Mandatory=$false)]
        [pscredential]$Credential,

        [Parameter(Mandatory=$false)]
        [string]$SiteServer

        ,
        [switch]$SkipCertificateCheck


    )

    # Use stored connection
    if (-not $SiteServer) { $SiteServer = $script:CMASConnection.SiteServer }
    if (-not $Credential) { $Credential = $script:CMASConnection.Credential }
    if (-not $SiteServer) { throw "No SiteServer specified. Run Connect-CMAS first." }
    if (-not $SkipCertificateCheck) { $SkipCertificateCheck = $script:CMASConnection.SkipCertificateCheck }

    $uri = "https://$SiteServer/AdminService/$Path"

    $params = @{
        Uri = $uri
        Method = $Method
    }

    if ($SkipCertificateCheck) {
        if ($PSVersionTable.PSVersion.Major -ge 6) {
            $params.SkipCertificateCheck = $true
        } else {
            # For PowerShell 5, we need to use a workaround to ignore certificate errors
            Add-Type @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAllCertsPolicy : ICertificatePolicy {
    public bool CheckValidationResult(
        ServicePoint srvPoint, X509Certificate certificate,
        WebRequest request, int certificateProblem) {
        return true;
    }
}
"@
            [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
        }
    }

    if ($Credential) {
        $params.Credential = $Credential
    } else {
        $params.UseDefaultCredentials = $true
    }

    if ($Body) {
        $params.Body = ($Body | ConvertTo-Json -Depth 10)
        $params.ContentType = "application/json"
    }

    Write-Verbose "Invoking API: $Method $uri"
    Invoke-RestMethod @params
}
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
function Connect-CMAS {
    <#
        .SYNOPSIS
            Connects to the SCCM Admin Service on a specified site server.

        .DESCRIPTION
            This function establishes a connection to the SCCM Admin Service API on the specified site server. It tests the connection by retrieving the administration service information and stores the connection details for use in subsequent API calls.

        .PARAMETER SiteServer
            The hostname or IP address of the SCCM site server hosting the Admin Service. This parameter is mandatory.

        .PARAMETER Credential
            Optional. A PSCredential object for authentication. If not provided, the current user's credentials will be used.

        .EXAMPLE
            # Connect to the Admin Service using default credentials
            Connect-CMAS -SiteServer "sccm.domain.local"
        .EXAMPLE
            # Connect to the Admin Service using specific credentials
            $cred = Get-Credential
            Connect-CMAS -SiteServer "sccm.domain.local" -Credential $cred

        .NOTES
            This function is part of the SCCM Admin Service module.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$SiteServer,

        [Parameter(Mandatory=$false)]
        [pscredential]$Credential
        ,
        [switch]$SkipCertificateCheck
    )

    # Test the connection
    $testPath = "wmi/SMS_Site"

    try {
        $InvokeParams = @{
            Path = $testPath
            SiteServer = $SiteServer
        }
        if ([boolean]$Credential) {
            $InvokeParams.Credential = $Credential
        }
        if ($SkipCertificateCheck) {
            $InvokeParams.SkipCertificateCheck = $true
        }

        $result = Invoke-CMASApi @InvokeParams

        # Store connection info
        $script:CMASConnection.SiteServer = $SiteServer
        $script:CMASConnection.Credential = $Credential
        $script:CMASConnection.SiteCode   = $result.value[0].SiteCode
        $script:CMASConnection.SkipCertificateCheck = $SkipCertificateCheck

        Write-Verbose "Connected to $SiteServer, SiteCode: $($script:CMASConnection.SiteCode)"
        return $result.value | Select-Object SiteCode, ServerName
    }
    catch {
        throw "Failed to connect to AdminService on $SiteServer. $($_.Exception.Message)"
    }
}

# Module-scoped variables
$script:CMASConnection = @{
    SiteServer  = $null
    Credential  = $null
    SiteCode    = $null
    SkipCertificateCheck = $false
}
function Get-CMASCollection {
    <#
        .SYNOPSIS
            Retrieves collections from the SCCM Admin Service.

        .DESCRIPTION
            This function connects to the SCCM Admin Service API to retrieve information about collections.
            You can filter collections by name using the -Name parameter.

        .PARAMETER Name
            Optional. The name of the collection to retrieve. If not specified, all collections will be returned.

        .PARAMETER CollectionID
            Optional. The ID of the collection to retrieve. If not specified, all collections will be returned.

        .EXAMPLE
            Get-CMASCollection

        .EXAMPLE
            Get-CMASCollection -Name "All Systems"

        .EXAMPLE
            Get-CMASCollection -CollectionID "SMS00001"

        .NOTES
            This function is part of the SCCM Admin Service module.
    #>
    [CmdletBinding()]
    param(
        [string]$Name,
        [string]$CollectionID
    )
    try {

        $path = "wmi/SMS_Collection"

        if ($Name) {
            $path += "?`$filter=Name eq '$Name'"
        }
        if ($CollectionID) {
            $path += "?`$filter=CollectionID eq '$CollectionID'"
        }

        $res = Invoke-CMASApi -Path $path

        # Return all collection properties
        return $res.value
    }
    catch {
        Write-Error "Failed to retrieve collections: $_"
        throw $_
    }
}
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
function Get-CMASCollectionVariable {
    <#
        .SYNOPSIS
            Gets collection variables for a Configuration Manager collection via the Admin Service.

        .DESCRIPTION
            This function retrieves custom variables that are assigned to a specific collection in Configuration Manager
            using the Admin Service API. Collection variables are name-value pairs that can be used in task sequences,
            scripts, and other Configuration Manager operations.

            The function supports identifying the target collection by either collection name or CollectionID.
            You can optionally filter the results to specific variable names using wildcard patterns.

        .PARAMETER CollectionName
            The name of the collection to retrieve variables from. Either CollectionName or CollectionID must be specified.

        .PARAMETER CollectionID
            The CollectionID of the collection to retrieve variables from. Either CollectionName or CollectionID must be specified.

        .PARAMETER VariableName
            Optional. The name of a specific variable to retrieve. Supports wildcard patterns (*).
            If not specified, all variables for the collection are returned.

        .EXAMPLE
            Get-CMASCollectionVariable -CollectionName "Production Servers"
            Retrieves all collection variables for collection "Production Servers".

        .EXAMPLE
            Get-CMASCollectionVariable -CollectionID "SMS00001"
            Retrieves all collection variables for the collection with CollectionID SMS00001.

        .EXAMPLE
            Get-CMASCollectionVariable -CollectionName "Production Servers" -VariableName "OSD*"
            Retrieves all collection variables starting with "OSD" for collection "Production Servers".

        .EXAMPLE
            Get-CMASCollectionVariable -CollectionName "Test Servers" -VariableName "AppPath"
            Retrieves the specific collection variable named "AppPath" for collection "Test Servers".

        .NOTES
            This function is part of the SCCM Admin Service module.
            Requires an active connection established via Connect-CMAS.

            The function queries the SMS_CollectionSettings WMI class via the Admin Service REST API.
            Returns an empty result if the collection has no variables configured.

            Collection variables are commonly used in:
            - Operating System Deployment (OSD) task sequences
            - Application deployment customization
            - Script execution with collection-specific values
            - Configuration baselines

        .LINK
            Connect-CMAS
            Get-CMASCollection
    #>
    [CmdletBinding(DefaultParameterSetName='ByCollectionName')]
    param(
        [Parameter(Mandatory=$false, ParameterSetName='ByCollectionName', Position=0)]
        [ValidateNotNullOrEmpty()]
        [string]$CollectionName,

        [Parameter(Mandatory=$false, ParameterSetName='ByCollectionID', Position=0)]
        [ValidateNotNullOrEmpty()]
        [string]$CollectionID,

        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [SupportsWildcards()]
        [string]$VariableName
    )

    begin {
        # Validate connection
        if (-not $script:CMASConnection.SiteServer) {
            throw "No active connection to SCCM Admin Service. Run Connect-CMAS first."
        }

        # Validate that either CollectionName or CollectionID is specified
        if (-not $CollectionName -and -not $CollectionID) {
            throw "Either CollectionName or CollectionID must be specified."
        }
    }

    process {
        try {
            # Resolve collection to CollectionID if needed
            $targetCollectionID = $null
            $targetCollectionName = $null

            if ($CollectionID) {
                $targetCollectionID = $CollectionID
                Write-Verbose "Using CollectionID: $targetCollectionID"

                # Get collection name for display purposes
                $collection = Get-CMASCollection -CollectionID $targetCollectionID
                if (-not $collection) {
                    throw "Collection with CollectionID '$targetCollectionID' not found."
                }
                $targetCollectionName = $collection.Name
            }
            elseif ($CollectionName) {
                Write-Verbose "Resolving CollectionName '$CollectionName' to CollectionID..."
                $collection = Get-CMASCollection -Name $CollectionName
                if (-not $collection) {
                    throw "Collection with name '$CollectionName' not found."
                }
                if (@($collection).Count -gt 1) {
                    throw "Multiple collections found with name '$CollectionName'. Use CollectionID instead."
                }
                $targetCollectionID = $collection.CollectionID
                $targetCollectionName = $collection.Name
                Write-Verbose "Resolved collection to CollectionID: $targetCollectionID"
            }

            # Query for collection settings
            # Note: Using parentheses syntax to properly load lazy properties like CollectionVariables
            Write-Verbose "Retrieving collection variables for CollectionID '$targetCollectionID'..."
            $settingsPath = "wmi/SMS_CollectionSettings('$targetCollectionID')"

            try {
                $response = Invoke-CMASApi -Path $settingsPath

                # Extract settings from response - API returns { value: [object] } when using parentheses syntax
                $settings = if ($response.value) {
                    $response.value | Select-Object -First 1
                } else {
                    $response
                }

                # If no settings found, return empty
                if (-not $settings) {
                    Write-Verbose "No CollectionSettings found for collection '$targetCollectionName' (CollectionID: $targetCollectionID)"
                    return
                }
            }
            catch {
                # 404 means no settings exist for this collection
                if ($_.Exception.Message -like "*404*" -or $_.Exception.Message -like "*Not Found*") {
                    Write-Verbose "No CollectionSettings found for collection '$targetCollectionName' (CollectionID: $targetCollectionID)"
                    return
                }
                else {
                    throw
                }
            }

            # Check if collection has any variables
            if (-not $settings.CollectionVariables) {
                Write-Verbose "Collection '$targetCollectionName' has no variables configured"
                return
            }

            $variables = @($settings.CollectionVariables)
            Write-Verbose "Found $($variables.Count) variable(s) for collection '$targetCollectionName'"

            # Filter by variable name if specified
            if ($VariableName) {
                Write-Verbose "Filtering variables by name: $VariableName"
                $variables = $variables | Where-Object { $_.Name -like $VariableName }
                Write-Verbose "After filtering: $($variables.Count) variable(s) match"
            }

            # If no variables match the filter, return empty
            if ($variables.Count -eq 0) {
                Write-Verbose "No variables match the specified criteria"
                return
            }

            # Return each variable with collection information
            foreach ($var in $variables) {
                # Add collection information to output
                $var | Add-Member -NotePropertyName 'CollectionID' -NotePropertyValue $targetCollectionID -Force
                $var | Add-Member -NotePropertyName 'CollectionName' -NotePropertyValue $targetCollectionName -Force

                # Format output - exclude WMI and OData metadata
                $output = $var | Select-Object -Property * -ExcludeProperty __*, @odata*

                # Return the variable
                Write-Output $output
            }
        }
        catch {
            throw "Failed to retrieve collection variables for collection '$targetCollectionName': $_"
        }
    }
}
function Get-CMASDevice {
    <#
        .SYNOPSIS
            Retrieves information about devices from the SCCM Admin Service.

        .DESCRIPTION
            This function connects to the SCCM Admin Service API to fetch details about devices.
            You can filter the results by device name or device ID.

        .PARAMETER Name
            The name of the device to retrieve information for. If not specified, all devices will be returned.

        .PARAMETER ResourceID
            The unique identifier of the device to retrieve information for. If not specified, all devices will be returned.

        .EXAMPLE
            Get-CMASDevice -Name "Device001"

        .EXAMPLE
            Get-CMASDevice -ResourceID "12345"

        .NOTES
            This function is part of the SCCM Admin Service module.

    #>
    [CmdletBinding()]
    param(
        [string]$Name,
        [long]$ResourceID
    )
    try {
        $path = "wmi/SMS_R_System"

        if ($Name) {
            $path += "?`$filter=Name eq '$Name'"
        }
        if ($ResourceID) {
            $path += "?`$filter=ResourceID eq $( $ResourceID.ToString() )"
        }

        Write-Verbose "Fetching device information from Admin Service with path: $path"
        $res = Invoke-CMASApi -Path $path

        # format results as needed, all properties except those starting with "__" (WMI metadata) and @odata.* (OData metadata)
        $devices = $res.value | Select-Object * -ExcludeProperty __*, @odata*

        return $devices
    }
    catch {
        Write-Error "Failed to retrieve device information: $_"
        throw $_
    }
}
function Get-CMASDeviceVariable {
    <#
        .SYNOPSIS
            Gets device variables for a Configuration Manager device via the Admin Service.

        .DESCRIPTION
            This function retrieves custom variables that are assigned to a specific device in Configuration Manager
            using the Admin Service API. Device variables are name-value pairs that can be used in task sequences,
            scripts, and other Configuration Manager operations.

            The function supports identifying the target device by either device name or ResourceID.
            You can optionally filter the results to specific variable names using wildcard patterns.

        .PARAMETER DeviceName
            The name of the device to retrieve variables from. Either DeviceName or ResourceID must be specified.

        .PARAMETER ResourceID
            The ResourceID of the device to retrieve variables from. Either DeviceName or ResourceID must be specified.

        .PARAMETER VariableName
            Optional. The name of a specific variable to retrieve. Supports wildcard patterns (*).
            If not specified, all variables for the device are returned.

        .EXAMPLE
            Get-CMASDeviceVariable -DeviceName "WORKSTATION01"
            Retrieves all device variables for device WORKSTATION01.

        .EXAMPLE
            Get-CMASDeviceVariable -ResourceID 16777220
            Retrieves all device variables for the device with ResourceID 16777220.

        .EXAMPLE
            Get-CMASDeviceVariable -DeviceName "WORKSTATION01" -VariableName "OSD*"
            Retrieves all device variables starting with "OSD" for device WORKSTATION01.

        .EXAMPLE
            Get-CMASDeviceVariable -DeviceName "SERVER01" -VariableName "AppPath"
            Retrieves the specific device variable named "AppPath" for device SERVER01.

        .NOTES
            This function is part of the SCCM Admin Service module.
            Requires an active connection established via Connect-CMAS.

            The function queries the SMS_MachineSettings WMI class via the Admin Service REST API.
            Returns an empty result if the device has no variables configured.

            Device variables are commonly used in:
            - Operating System Deployment (OSD) task sequences
            - Application deployment customization
            - Script execution with device-specific values
            - Configuration baselines

        .LINK
            Connect-CMAS
            Get-CMASDevice
            New-CMASDeviceVariable
    #>
    [CmdletBinding(DefaultParameterSetName='ByDeviceName')]
    param(
        [Parameter(Mandatory=$false, ParameterSetName='ByDeviceName', Position=0)]
        [ValidateNotNullOrEmpty()]
        [string]$DeviceName,

        [Parameter(Mandatory=$false, ParameterSetName='ByResourceID', Position=0)]
        [long]$ResourceID,

        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [SupportsWildcards()]
        [string]$VariableName
    )

    begin {
        # Validate connection
        if (-not $script:CMASConnection.SiteServer) {
            throw "No active connection to SCCM Admin Service. Run Connect-CMAS first."
        }

        # Validate that either DeviceName or ResourceID is specified
        if (-not $DeviceName -and -not $ResourceID) {
            throw "Either DeviceName or ResourceID must be specified."
        }
    }

    process {
        try {
            # Resolve device to ResourceID if needed
            $targetResourceID = $null
            $targetDeviceName = $null

            if ($ResourceID) {
                $targetResourceID = $ResourceID
                Write-Verbose "Using ResourceID: $targetResourceID"

                # Get device name for display purposes
                $device = Get-CMASDevice -ResourceID $targetResourceID
                if (-not $device) {
                    throw "Device with ResourceID '$targetResourceID' not found."
                }
                $targetDeviceName = $device.Name
            }
            elseif ($DeviceName) {
                Write-Verbose "Resolving DeviceName '$DeviceName' to ResourceID..."
                $device = Get-CMASDevice -Name $DeviceName
                if (-not $device) {
                    throw "Device with name '$DeviceName' not found."
                }
                if (@($device).Count -gt 1) {
                    throw "Multiple devices found with name '$DeviceName'. Use ResourceID instead."
                }
                $targetResourceID = $device.ResourceID
                $targetDeviceName = $device.Name
                Write-Verbose "Resolved device to ResourceID: $targetResourceID"
            }

            # Query for device settings
            Write-Verbose "Retrieving device variables for ResourceID '$targetResourceID'..."
            $settingsPath = "wmi/SMS_MachineSettings($targetResourceID)"

            try {
                $response = Invoke-CMASApi -Path $settingsPath

                # Extract settings from response - API returns { value: [object] } or object directly
                $settings = if ($response.value) {
                    $response.value | Select-Object -First 1
                } else {
                    $response
                }
            }
            catch {
                # 404 means no settings exist for this device
                if ($_.Exception.Message -like "*404*" -or $_.Exception.Message -like "*Not Found*") {
                    Write-Verbose "No MachineSettings found for device '$targetDeviceName' (ResourceID: $targetResourceID)"
                    return
                }
                else {
                    throw
                }
            }

            # Check if device has any variables
            if (-not $settings.MachineVariables) {
                Write-Verbose "Device '$targetDeviceName' has no variables configured"
                return
            }

            $variables = @($settings.MachineVariables)
            Write-Verbose "Found $($variables.Count) variable(s) for device '$targetDeviceName'"

            # Filter by variable name if specified
            if ($VariableName) {
                Write-Verbose "Filtering variables by name: $VariableName"
                $variables = $variables | Where-Object { $_.Name -like $VariableName }
                Write-Verbose "After filtering: $($variables.Count) variable(s) match"
            }

            # If no variables match the filter, return empty
            if ($variables.Count -eq 0) {
                Write-Verbose "No variables match the specified criteria"
                return
            }

            # Return each variable with device information
            foreach ($var in $variables) {
                # Add device information to output
                $var | Add-Member -NotePropertyName 'ResourceID' -NotePropertyValue $targetResourceID -Force
                $var | Add-Member -NotePropertyName 'DeviceName' -NotePropertyValue $targetDeviceName -Force

                # Format output - exclude WMI and OData metadata
                $output = $var | Select-Object -Property * -ExcludeProperty __*, @odata*

                # Return the variable
                Write-Output $output
            }
        }
        catch {
            throw "Failed to retrieve device variables for device '$targetDeviceName': $_"
        }
    }
}
function Get-CMASScript {
    <#
        .SYNOPSIS
        List CMScripts from AdminService

        .DESCRIPTION
        This function retrieves the content of a specified CMAS script from the AdminService.

        .PARAMETER Name
        The name of the CMAS script to retrieve.

        .EXAMPLE
        Get-CMASScript -Name "Get-SomeSettings"

        .NOTES
        Date, Author, Version, Notes

    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [String]$Name
    )
    try {

        $path = "wmi/SMS_Scripts"
        if ($Name) {
            $path += "?`$filter=ScriptName eq '$Name'"
        }
        $res = Invoke-CMASApi -Path $path
        return $res.value | Select-Object ScriptName, ScriptGUID, Script -ExcludeProperty __*, @odata*
    }
    catch {
        Write-Error "Failed to retrieve CMAS script: $_"
        throw $_
    }
}
function Get-CMASScriptExecutionStatus {
    <#
        .SYNOPSIS
            Returns the current status of a SCCM Script execution via Admin Service.

        .DESCRIPTION
            This function retrieves the execution status of SCCM scripts through the Admin Service REST API.
            It queries SMS_ScriptsExecutionTask and SMS_ScriptsExecutionStatus to get detailed information
            about script execution status, including output from individual clients.

        .PARAMETER OperationID
            The ClientOperationId returned from Invoke-CMASScript. When specified, retrieves status for
            this specific operation.

        .PARAMETER CollectionName
            Filter by collection name. Can be combined with ScriptName.

        .PARAMETER CollectionID
            Filter by collection ID. Can be combined with ScriptName.

        .PARAMETER ScriptName
            Filter by script name. Can be combined with CollectionName or CollectionID.

        .EXAMPLE
            # Get status for a specific operation
            $result = Invoke-CMASScript -ScriptName "Get Info" -ResourceId 16777219
            Get-CMASScriptExecutionStatus -OperationID $result.OperationId

        .EXAMPLE
            # Get all script executions for a collection
            Get-CMASScriptExecutionStatus -CollectionName "All Systems"

        .EXAMPLE
            # Get executions for a specific script
            Get-CMASScriptExecutionStatus -ScriptName "Set Registry Value"

        .EXAMPLE
            # Get executions for a specific script on a collection
            Get-CMASScriptExecutionStatus -CollectionID "SMS00001" -ScriptName "Get Info"

        .NOTES
            This function is part of the SCCM Admin Service module.
            Requires connection via Connect-CMAS before use.

            The function returns:
            - OperationID: The client operation ID
            - ScriptName: Name of the executed script
            - ScriptGuid: GUID of the script
            - CollectionID/Name: Target collection information
            - Results: Array of per-device results including output
            - Status: Overall execution status
            - Client counts: Total, Completed, Failed, Offline, NotApplicable, Unknown
            - LastUpdateTime: Last status update

    #>
    [OutputType([System.Object[]])]
    [CmdletBinding(DefaultParameterSetName='NoFilter')]
    param(
        [Parameter(Mandatory=$false, ParameterSetName='OperationID')]
        [ValidateNotNullOrEmpty()]
        [string]$OperationID,

        [Parameter(Mandatory=$true, ParameterSetName='CollectionName')]
        [Parameter(Mandatory=$false, ParameterSetName='CollectionName_ScriptName')]
        [Parameter(Mandatory=$false, ParameterSetName='NoFilter')]
        [string]$CollectionName,

        [Parameter(Mandatory=$true, ParameterSetName='CollectionID')]
        [Parameter(Mandatory=$false, ParameterSetName='CollectionID_ScriptName')]
        [Parameter(Mandatory=$false, ParameterSetName='NoFilter')]
        [string]$CollectionID,

        [Parameter(Mandatory=$true, ParameterSetName='ScriptName')]
        [Parameter(Mandatory=$false, ParameterSetName='CollectionName_ScriptName')]
        [Parameter(Mandatory=$false, ParameterSetName='CollectionID_ScriptName')]
        [Parameter(Mandatory=$false, ParameterSetName='NoFilter')]
        [string]$ScriptName
    )

    try {
        # Build the filter query based on parameters
        $filters = @()

        if ($OperationID) {
            $filters += "ClientOperationId eq $OperationID"
        }

        if ($CollectionName) {
            $filters += "CollectionName eq '$CollectionName'"
        }

        if ($CollectionID) {
            $filters += "CollectionId eq '$CollectionID'"
        }

        if ($ScriptName) {
            $filters += "ScriptName eq '$ScriptName'"
        }

        # Construct the query path
        $path = "wmi/SMS_ScriptsExecutionTask"
        if ($filters.Count -gt 0) {
            $filterString = $filters -join ' and '
            $path += "?`$filter=$filterString"
        }

        Write-Verbose "Querying script execution tasks: $path"
        $taskResponse = Invoke-CMASApi -Path $path

        if (-not $taskResponse.value -or $taskResponse.value.Count -eq 0) {
            Write-Verbose "No script execution tasks found"
            return [PSCustomObject]@{
                OperationID          = if ($OperationID) { $OperationID } else { $null }
                ScriptName           = if ($ScriptName) { $ScriptName } else { 'Operation not found' }
                ScriptVersion        = $null
                ScriptGuid           = $null
                CollectionID         = $null
                CollectionName       = $null
                Results              = $null
                Status               = 'error'
                TotalClients         = $null
                CompletedClients     = $null
                FailedClients        = $null
                OfflineClients       = $null
                NotApplicableClients = $null
                UnknownClients       = $null
                LastUpdateTime       = $null
            }
        }

        # Process each task
        $allResults = @()
        foreach ($task in $taskResponse.value) {
            Write-Verbose "Processing operation ID $($task.ClientOperationId)"

            $results = @()
            $status = 'no client completed'

            # If clients have completed, get detailed status
            if ($task.CompletedClients -gt 0) {
                Write-Verbose "Fetching client execution status for operation $($task.ClientOperationId)"

                $statusPath = "wmi/SMS_ScriptsExecutionStatus?`$filter=ClientOperationId eq $($task.ClientOperationId)"
                $clientStatusResponse = Invoke-CMASApi -Path $statusPath

                if ($clientStatusResponse.value -and $clientStatusResponse.value.Count -gt 0) {
                    foreach ($clientStatus in $clientStatusResponse.value) {
                        # Parse script output
                        $scriptOutput = $clientStatus.ScriptOutput
                        $outputObject = $null

                        if ($scriptOutput) {
                            try {
                                # Clean up JSON escaping that may be present
                                $cleanedOutput = $scriptOutput -replace '\\r\\n', [System.Environment]::NewLine
                                $cleanedOutput = $cleanedOutput -replace '\\"', '"'
                                $cleanedOutput = $cleanedOutput -replace '\\\\', '\'
                                $outputObject = $cleanedOutput | ConvertFrom-Json -ErrorAction Stop
                            }
                            catch {
                                # If not valid JSON, use raw output
                                $outputObject = $scriptOutput
                            }
                        }

                        $results += [PSCustomObject]@{
                            ResourceID           = $clientStatus.ResourceId
                            DeviceName           = $clientStatus.DeviceName
                            ScriptExecutionState = $clientStatus.ScriptExecutionState
                            ScriptExitCode       = $clientStatus.ScriptExitCode
                            ScriptOutput         = $scriptOutput
                            OutputObject         = $outputObject
                        }
                    }

                    # Determine overall status
                    if ($task.CompletedClients -eq $task.TotalClients) {
                        $status = "all clients completed"
                    }
                    else {
                        $status = "some clients completed"
                    }
                }
            }

            # Build result object
            $allResults += [PSCustomObject]@{
                OperationID          = $task.ClientOperationId
                ScriptName           = $task.ScriptName
                ScriptVersion        = $task.ScriptVersion
                ScriptGuid           = $task.ScriptGuid
                CollectionID         = $task.CollectionId
                CollectionName       = $task.CollectionName
                Results              = $results
                Status               = $status
                TotalClients         = $task.TotalClients
                CompletedClients     = $task.CompletedClients
                FailedClients        = $task.FailedClients
                OfflineClients       = $task.OfflineClients
                NotApplicableClients = $task.NotApplicableClients
                UnknownClients       = $task.UnknownClients
                LastUpdateTime       = $task.LastUpdateTime
            }
        }

        return $allResults
    }
    catch {
        $function = $MyInvocation.MyCommand.Name
        Write-Error "Failed to get script execution status: $_"

        return [PSCustomObject]@{
            Succeeded  = $false
            Function   = $function
            Activity   = $_.CategoryInfo.Activity
            Message    = $_.Exception.Message
            Category   = $_.CategoryInfo.Category
            Exception  = $_.Exception.GetType().FullName
            TargetName = $_.CategoryInfo.TargetName
        }
    }
}
function Invoke-CMASCollectionUpdate {
    <#
        .SYNOPSIS
            Triggers a membership update for a Configuration Manager collection via the Admin Service.

        .DESCRIPTION
            This function initiates a manual membership evaluation for a Configuration Manager collection
            using the Admin Service API. It calls the RequestRefresh method on the SMS_Collection WMI class.

            This is equivalent to the Invoke-CMCollectionUpdate cmdlet in the ConfigurationManager module
            or right-clicking a collection in the SCCM console and selecting "Update Membership".

            The function supports three ways to specify the target collection:
            - By collection name
            - By collection ID
            - By passing a collection object (supports pipeline input)

        .PARAMETER CollectionName
            The name of the collection to update.

        .PARAMETER CollectionId
            The ID of the collection to update.

        .PARAMETER InputObject
            A collection object (from Get-CMASCollection) to update.
            This parameter accepts pipeline input.

        .PARAMETER PassThru
            Returns information about the update operation.

        .EXAMPLE
            Invoke-CMASCollectionUpdate -CollectionName "All Systems"
            Triggers a membership update for the "All Systems" collection.

        .EXAMPLE
            Invoke-CMASCollectionUpdate -CollectionId "SMS00001"
            Triggers a membership update using the collection ID.

        .EXAMPLE
            Get-CMASCollection -Name "Test Collection" | Invoke-CMASCollectionUpdate
            Updates collection membership via pipeline.

        .EXAMPLE
            Get-CMASCollection -Name "Test*" | Invoke-CMASCollectionUpdate -Verbose
            Updates membership for all collections starting with "Test", showing verbose progress.

        .EXAMPLE
            Invoke-CMASCollectionUpdate -CollectionName "Production Servers" -PassThru
            Updates the collection and returns operation details.

        .NOTES
            This function is part of the SCCM Admin Service module.
            Requires an active connection established via Connect-CMAS.

            The function uses the Admin Service REST API to call the RequestRefresh method
            on a specific SMS_Collection instance.

            Important considerations:
            - The RequestRefresh method initiates membership evaluation but returns immediately
            - The actual membership update is processed asynchronously by SCCM
            - For large collections, the update may take several minutes to complete
            - Check the collection's LastMemberChangeTime property to verify when the update completed

        .LINK
            Connect-CMAS
            Get-CMASCollection
            Set-CMASCollection
            New-CMASCollection
    #>
    [CmdletBinding(DefaultParameterSetName='ByName', SupportsShouldProcess=$true, ConfirmImpact='Low')]
    param(
        [Parameter(Mandatory=$true, ParameterSetName='ByName')]
        [ValidateNotNullOrEmpty()]
        [Alias('Name')]
        [string]$CollectionName,

        [Parameter(Mandatory=$true, ParameterSetName='ById')]
        [ValidateNotNullOrEmpty()]
        [Alias('Id')]
        [string]$CollectionId,

        [Parameter(Mandatory=$true, ParameterSetName='ByValue', ValueFromPipeline=$true)]
        [ValidateNotNull()]
        [Alias('Collection')]
        [object]$InputObject,

        [Parameter(Mandatory=$false)]
        [switch]$PassThru
    )

    begin {
        # Validate connection
        if (-not $script:CMASConnection.SiteServer) {
            throw "No active connection to SCCM Admin Service. Run Connect-CMAS first."
        }
    }

    process {
        try {
            # Determine target collection based on parameter set
            $targetCollection = $null

            switch ($PSCmdlet.ParameterSetName) {
                'ByName' {
                    Write-Verbose "Looking up collection by name: $CollectionName"
                    $targetCollection = Get-CMASCollection -Name $CollectionName
                    if (-not $targetCollection) {
                        throw "Collection '$CollectionName' not found."
                    }
                }
                'ById' {
                    Write-Verbose "Looking up collection by ID: $CollectionId"
                    $targetCollection = Get-CMASCollection -CollectionId $CollectionId
                    if (-not $targetCollection) {
                        throw "Collection with ID '$CollectionId' not found."
                    }
                }
                'ByValue' {
                    Write-Verbose "Using collection object from pipeline"
                    $targetCollection = $InputObject
                    if (-not $targetCollection.CollectionID) {
                        throw "Invalid collection object provided. Expected object with CollectionID property."
                    }
                }
            }

            # Ensure we have a valid collection
            if (-not $targetCollection -or -not $targetCollection.CollectionID) {
                throw "Failed to identify target collection."
            }

            $description = "collection '$($targetCollection.Name)' ($($targetCollection.CollectionID))"

            if ($PSCmdlet.ShouldProcess($description, "Trigger membership update for Configuration Manager collection")) {
                Write-Verbose "Triggering membership update for: $($targetCollection.Name) ($($targetCollection.CollectionID))"

                # Build the method call to RequestRefresh
                # For WMI instance methods via Admin Service, the path format is:
                # wmi/ClassName('KeyValue')/AdminService.MethodName
                $methodPath = "wmi/SMS_Collection('$($targetCollection.CollectionID)')/AdminService.RequestRefresh"

                Write-Verbose "Calling RequestRefresh method on collection: $($targetCollection.CollectionID)"

                # Call the RequestRefresh method via Admin Service
                # RequestRefresh takes no parameters, but we need to pass an empty body for proper Content-Type header
                $result = Invoke-CMASApi -Path $methodPath -Method POST -Body @{}

                Write-Verbose "Membership update initiated successfully"
                Write-Host "Collection '$($targetCollection.Name)' membership update initiated." -ForegroundColor Green

                if ($PassThru) {
                    # Return information about the operation
                    [PSCustomObject]@{
                        CollectionId = $targetCollection.CollectionID
                        CollectionName = $targetCollection.Name
                        UpdateInitiated = $true
                        Timestamp = Get-Date
                    }
                }
            }
        }
        catch {
            Write-Error "Failed to update collection membership: $_"
            throw
        }
    }

    end {
    }
}
function Invoke-CMASScript {
    <#
        .SYNOPSIS
            Executes an approved SCCM script on clients using the Admin Service.

        .DESCRIPTION
            This function looks up a script via the SCCM Admin Service REST API, then executes it using
            the Admin Service's InitiateClientOperationEx endpoint. This enables script execution with
            parameters in PowerShell 7.x without requiring WMI.

            For scripts without parameters targeting a single device, the simpler Device.RunScript
            REST endpoint is used automatically.

            IMPORTANT: The Admin Service does not return lazy properties (ScriptHash, ScriptVersion,
            ParamsDefinition) needed for executing scripts with parameters. To work around this:

            1. Use -ScriptHash and -ScriptVersion parameters to provide metadata manually
            2. Enable CIM/WinRM to the Site Server (automatic fallback)
            3. For scripts WITHOUT parameters, no workaround needed

        .PARAMETER ScriptName
            The name of the script. Either ScriptName or ScriptID must be specified.

        .PARAMETER ScriptID
            The GUID of the script. Either ScriptName or ScriptID must be specified.

        .PARAMETER InputParameters
            Optional. A hashtable of input parameters to pass to the script.

        .PARAMETER CollectionId
            The ID of the collection on which to execute the script.

        .PARAMETER ResourceId
            The ResourceID of a specific device to target. Can be a single ID or an array of IDs.

        .EXAMPLE
            # Simple script without parameters
            Invoke-CMASScript -ScriptName "Get Info" -ResourceId 16777219

        .EXAMPLE
            # Script with parameters - provide metadata manually
            $params = @{ Key = 'HKLM:\SOFTWARE\Test'; Name = 'Value' }
            Invoke-CMASScript -ScriptName "Set Registry" -ResourceId 16777219 -InputParameters $params


        .EXAMPLE
            # Multiple devices
            Invoke-CMASScript -ScriptName "Get Info" -ResourceId @(16777219, 16777220, 16777221)

        .NOTES
            This function is part of the SCCM Admin Service module.

            To get script metadata from PowerShell 5.1:
              $s = Get-CMScript -ScriptName "Script Name"
              $s | Select ScriptGuid, ScriptHash, ScriptVersion, ParamsDefinition
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$ScriptName = ''
        ,

        [Parameter(Mandatory=$false)]
        [string]$ScriptID = ''
        ,

        [Parameter(Mandatory=$false)]
        [string]$CollectionId = ''
        ,

        [Parameter(Mandatory=$false)]
        [long[]]$ResourceId = @(),

        [Parameter(Mandatory=$false)]
        [hashtable]$InputParameters = @{}
    )
    try {

        # Validate parameters
        if (-not $ScriptName -and -not $ScriptID) {
            throw "Either ScriptName or ScriptID must be specified."
        }
        if ($ScriptName -and $ScriptID) {
            throw "Only one of ScriptName or ScriptID can be specified."
        }
        if (-not $CollectionId -and -not $ResourceId) {
            throw "Either CollectionId or ResourceId must be specified."
        }

        # Step 1: Check Script
        $Path = "wmi/SMS_Scripts"
        if ($ScriptName) {
            $Path += "?`$filter=ScriptName eq '$ScriptName'"
        }
        if ($ScriptID) {
            $Path += "?`$filter=ScriptGUID eq '$ScriptID'"
        }

        Write-Verbose "Checking for existing script with path: $Path"
        $res = Invoke-CMASApi -Path $Path

        if ($res.value.Count -gt 0) {
            $scriptInfo = $res.value[0]
            Write-Verbose "Script '$($scriptInfo.ScriptName)' found with GUID $($scriptInfo.ScriptGuid)."

            # Fetch the full script object with lazy properties
            # The Admin Service requires explicit $select for lazy properties in WMI classes
            # SMS_Scripts lazy properties: Script, ParamsDefinition, ScriptHash
            Write-Verbose "Fetching full script details for GUID: $($scriptInfo.ScriptGuid)"

            # Method 1: Try fetching with $select=* to get all properties including lazy ones
            $lazyProperties = "ScriptGuid,ScriptName,ScriptVersion,ScriptType,ScriptHash,ApprovalState,ParamsDefinition,Script,Author,Comment,LastUpdateTime"
            try {
                # $scriptFull = Invoke-CMASApi -Path "wmi/SMS_Scripts('$($scriptInfo.ScriptGuid)')?`$select=$lazyProperties"
                $scriptFull = Invoke-CMASApi -Path "wmi/SMS_Scripts('$($scriptInfo.ScriptGuid)')"
                $script = if ($scriptFull | Get-Member -Name ScriptGuid) { $scriptFull } else { $scriptFull.value }
            }
            catch {
                Write-Verbose "Fetch with `$select failed, trying without: $_"
                $scriptFull = Invoke-CMASApi -Path "wmi/SMS_Scripts('$($scriptInfo.ScriptGuid)')"
                $script = if ($scriptFull | Get-Member -Name ScriptGuid) { $scriptFull } else { $scriptFull.value }
            }

            if (-not $script.ScriptHash) {
                Write-Verbose "ScriptHash is missing from the returned properties. This means the Admin Service does not support returning lazy properties via filter queries. Parameterized execution will not work without workarounds."
                throw "ScriptHash is required for executing scripts with parameters. The Admin Service did not return this property. Use a script without parameters or enable CIM/WinRM to the Site Server for a fallback method."
            }
        }
        else {
            Write-Verbose "Script '$ScriptName' not found."
            throw "Script '$ScriptName' not found. Please create the script first using New-CMASScript or specify an existing ScriptID."
        }

        # Check approval state (may be empty if lazy properties not loaded)
        if ($script.ApprovalState -and $script.ApprovalState -ne 3) {
            throw "Script '$($script.ScriptName)' is not approved (ApprovalState: $($script.ApprovalState)). Please approve the script before executing."
        }

        # Get the ScriptGuid for execution
        $ScriptGuid = $script.ScriptGuid
        Write-Verbose "Using Script GUID: $ScriptGuid"
        Write-Verbose "ScriptVersion: $($script.ScriptVersion)"
        Write-Verbose "ScriptType: $($script.ScriptType)"
        Write-Verbose "ScriptHash: $($script.ScriptHash)"

        # Check if script has parameters (only if ParamsDefinition is available)
        $hasParameters = $false
        $Parameters = $null
        if ($script.ParamsDefinition) {
            Write-Verbose "Parsing script parameters..."
            $Parameters = [xml]([string]::new([Convert]::FromBase64String($script.ParamsDefinition)))
            $hasParameters = $Parameters.ScriptParameters.ChildNodes.Count -gt 0
        }

        # Determine if user is trying to pass parameters
        $userProvidedParams = $InputParameters -and $InputParameters.Count -gt 0

        Write-Verbose "Using InitiateClientOperationEx for all script execution with parameters"

        # Validate required parameters (only if ParamsDefinition is available)
        if ($hasParameters) {
            $Parameters.ScriptParameters.ChildNodes | ForEach-Object {
                if ( ( $_.IsRequired ) -and ( $_.IsHidden -ne $true ) -and ( $_.Name -notin $InputParameters.Keys ) ) {
                    throw "Script '$ScriptName' has required parameter '$($_.Name)' but it was not provided."
                }
            }
        }

        # Build parameter XML
        # Note: Based on testing, ParameterGroupGuid can be empty and ParameterGroupName='PG0' works

        # create GUID used for parametergroup
        $ParameterGroupGUID = $(New-Guid)

        if ((-not $hasParameters -and -not $userProvidedParams) -or ($InputParameters.Count -eq 0)) {
            # No parameters needed
            $ParametersXML = "<ScriptParameters></ScriptParameters>"
            $ParametersHash = ""
        }
        elseif ($hasParameters) {
            # Use ParamsDefinition to build parameters (validates types/required fields)
            $InnerParametersXML = ''

            foreach ( $ChildNode in $Parameters.ScriptParameters.ChildNodes ) {
                $ParamName = $ChildNode.Name
                if ( $ChildNode.IsHidden -eq 'true' ) {
                    $Value = $ChildNode.DefaultValue
                }
                else {
                    if ( $ParamName -in $InputParameters.Keys ) {
                        $Value = $InputParameters."$ParamName"
                    }
                    else {
                        $Value = ''
                    }
                }

                # Escape XML special characters in the value
                $EscapedValue = [System.Security.SecurityElement]::Escape($Value)

                # Use format matching working WMI version
                $InnerParametersXML = "$InnerParametersXML<ScriptParameter ParameterGroupGuid=`"${ParameterGroupGUID}`" ParameterGroupName=`"PG_${ParameterGroupGUID}`" ParameterName=`"$ParamName`" ParameterDataType=`"$( $ChildNode.Type )`" ParameterValue=`"$EscapedValue`"/>"
            }
            $ParametersXML = "<ScriptParameters>$InnerParametersXML</ScriptParameters>"

            # Compute ParameterGroupHash from the full ParametersXML using Unicode (UTF16-LE) encoding
            # This matches how SCCM client verifies the hash
            # Use SHA256.Create() which works in both PowerShell 5.1 and 7
            $SHA256 = [System.Security.Cryptography.SHA256]::Create()
            $Bytes = $SHA256.ComputeHash([System.Text.Encoding]::Unicode.GetBytes($ParametersXML))
            $ParametersHash = ($Bytes | ForEach-Object { $_.ToString('X2') }) -join ''

            Write-Verbose "ParametersXML for hash: $ParametersXML"
            Write-Verbose "ParametersHash: $ParametersHash"
        }
        else {
            # User provided parameters but ParamsDefinition is not available
            # Build parameters directly from InputParameters hashtable
            Write-Verbose "Building parameters directly from InputParameters (no ParamsDefinition available)"
            $InnerParametersXML = ''

            foreach ($key in $InputParameters.Keys) {
                $Value = $InputParameters[$key]
                $EscapedValue = [System.Security.SecurityElement]::Escape($Value)

                # Use format matching working WMI version (simplified, ParameterDataType only)
                $InnerParametersXML = "$InnerParametersXML<ScriptParameter ParameterGroupGuid=`"${ParameterGroupGUID}`" ParameterGroupName=`"PG_${ParameterGroupGUID}`" ParameterName=`"$key`" ParameterDataType=`"System.String`" ParameterValue=`"$EscapedValue`"/>"
            }
            $ParametersXML = "<ScriptParameters>$InnerParametersXML</ScriptParameters>"

            # Compute ParameterGroupHash from the full ParametersXML using Unicode (UTF16-LE) encoding
            # This matches how SCCM client verifies the hash
            $SHA256 = [System.Security.Cryptography.SHA256]::Create()
            $Bytes = $SHA256.ComputeHash([System.Text.Encoding]::Unicode.GetBytes($ParametersXML))
            $ParametersHash = ($Bytes | ForEach-Object { $_.ToString('X2') }) -join ''

            Write-Verbose "ParametersXML for hash: $ParametersXML"
            Write-Verbose "ParametersHash: $ParametersHash"
        }

        # Build RunScript XML
        $RunScriptXMLDefinition = "<ScriptContent ScriptGuid='{0}'><ScriptVersion>{1}</ScriptVersion><ScriptType>{2}</ScriptType><ScriptHash ScriptHashAlg='SHA256'>{3}</ScriptHash>{4}<ParameterGroupHash ParameterHashAlg='SHA256'>{5}</ParameterGroupHash></ScriptContent>"
        $RunScriptXML = $RunScriptXMLDefinition -f $script.ScriptGuid,$script.ScriptVersion,$script.ScriptType,$script.ScriptHash,$ParametersXML,$ParametersHash

        Write-Verbose "RunScript XML: $RunScriptXML"

        # Build target arrays - when targeting specific resources, TargetCollectionID can be empty
        if ($ResourceId -and $ResourceId.Count -gt 0) {
            $TargetResourceIDs = [System.Collections.ArrayList]@()
            foreach ($id in $ResourceId) {
                [void]$TargetResourceIDs.Add([long]$id)
            }
            # Empty string works for specific resource targeting (confirmed via testing)
            $TargetCollectionID = if ($CollectionId) { $CollectionId } else { "" }
            Write-Verbose "Targeting specific resources: $($TargetResourceIDs -join ', ')$(if($TargetCollectionID){" in collection: $TargetCollectionID"})"
        }
        else {
            $TargetResourceIDs = [System.Collections.ArrayList]@()
            $TargetCollectionID = $CollectionId
            Write-Verbose "Targeting collection: $CollectionId"
        }

        # Execute via Admin Service REST API
        # The Admin Service WMI method call expects parameters in a specific format
        $base64Param = [Convert]::ToBase64String(([System.Text.Encoding]::UTF8).GetBytes($RunScriptXML))

        # Build operation body - Admin Service expects specific types for WMI method parameters
        $operationBody = @{
            Param               = $base64Param
            RandomizationWindow = 0
            TargetCollectionID  = $TargetCollectionID
            TargetResourceIDs   = @($TargetResourceIDs)
            Type                = 135
        }

        Write-Verbose "Operation body JSON: $($operationBody | ConvertTo-Json -Depth 10 -Compress)"
        Write-Verbose "Initiating script execution via Admin Service REST API..."

        try {
            $result = Invoke-CMASApi -Path "wmi/SMS_ClientOperation.InitiateClientOperationEx" -Method POST -Body $operationBody
            Write-Verbose "Script execution initiated. Result: $($result | ConvertTo-Json -Depth 5 -Compress)"

            # Extract the OperationID from the result
            $operationId = if ($result.OperationID) { $result.OperationID } elseif ($result.value) { $result.value } else { $result }

            return [PSCustomObject]@{
                OperationId       = $operationId
                ScriptGuid        = $ScriptGuid
                ScriptName        = $script.ScriptName
                TargetResourceIDs = $TargetResourceIDs
                TargetCollectionID = $TargetCollectionID
            }
        }
        catch {
            $lastError = $_
            $errorMessage = $_.Exception.Message
            $statusCode = $_.Exception.Response.StatusCode.value__

            Write-Verbose "InitiateClientOperationEx failed (HTTP $statusCode): $errorMessage"
            Write-Verbose "Request body was: $($operationBody | ConvertTo-Json -Depth 10)"
        }

    }
    catch {
        Write-Error "Failed to execute script: $_"
        throw $_
    }
}
function New-CMASCollection {
    <#
        .SYNOPSIS
            Creates a new Configuration Manager collection via the Admin Service.

        .DESCRIPTION
            This function creates a new device or user collection in Configuration Manager using the Admin Service API.
            You can specify collection properties such as name, type, limiting collection, refresh schedule, and comments.

            The function supports creating both device and user collections with various refresh types:
            - Manual: Collection membership is only updated manually
            - Periodic: Collection membership is updated on a schedule
            - Continuous: Collection membership is continuously evaluated (incremental updates)
            - Both: Combination of Periodic and Continuous refresh

        .PARAMETER Name
            The name of the new collection to create. Must be unique within Configuration Manager.

        .PARAMETER CollectionType
            The type of collection to create: Device or User.
            - Device (2): Creates a device collection
            - User (1): Creates a user collection
            Default is Device.

        .PARAMETER LimitingCollectionId
            The CollectionID of the limiting collection. The new collection can only contain members
            of this limiting collection. For device collections, typically "SMS00001" (All Systems).

        .PARAMETER LimitingCollectionName
            The name of the limiting collection. If specified, the function will look up the
            CollectionID automatically. Either LimitingCollectionId or LimitingCollectionName must be provided.

        .PARAMETER Comment
            Optional comment or description for the collection.

        .PARAMETER RefreshType
            The refresh type for the collection:
            - Manual (1): Manual updates only
            - Periodic (2): Scheduled updates
            - Continuous (4): Incremental updates (continuous evaluation)
            - Both (6): Periodic and Continuous (2 + 4)
            Default is Manual.


        .EXAMPLE
            New-CMASCollection -Name "My Device Collection" -LimitingCollectionName "All Systems"
            Creates a new device collection with manual refresh, limited to All Systems.

        .EXAMPLE
            New-CMASCollection -Name "Test Servers" -LimitingCollectionId "SMS00001" -RefreshType Periodic -Comment "Test environment servers"
            Creates a device collection with periodic refresh and a comment.

        .EXAMPLE
            New-CMASCollection -Name "My Users" -CollectionType User -LimitingCollectionName "All Users" -RefreshType Continuous
            Creates a user collection with continuous (incremental) updates.

        .EXAMPLE
            New-CMASCollection -Name "Production Servers" -LimitingCollectionId "SMS00001" -RefreshType Both -PassThru
            Creates a device collection with both periodic and continuous refresh, returning the collection object.

        .NOTES
            This function is part of the SCCM Admin Service module.
            Requires an active connection established via Connect-CMAS.

            The function uses the Admin Service REST API to POST to the SMS_Collection WMI class.
            Collection names must be unique across all collections in Configuration Manager.

            Collection Types:
            - 0 = Other
            - 1 = User
            - 2 = Device (default)

            Refresh Types:
            - 1 = Manual only
            - 2 = Scheduled (Periodic) only
            - 4 = Incremental (Continuous) only
            - 6 = Scheduled and Incremental (Both)

        .LINK
            Connect-CMAS
            Get-CMASCollection
            Add-CMASCollectionMembershipRule
            Remove-CMASCollectionMembershipRule
    #>
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory=$false)]
        [ValidateSet('Device', 'User', '1', '2')]
        [string]$CollectionType = 'Device',

        [Parameter(Mandatory=$false, ParameterSetName='ByLimitingId')]
        [string]$LimitingCollectionId,

        [Parameter(Mandatory=$false, ParameterSetName='ByLimitingName')]
        [string]$LimitingCollectionName,

        [Parameter(Mandatory=$false)]
        [string]$Comment,

        [Parameter(Mandatory=$false)]
        [ValidateSet('Manual', 'Periodic', 'Continuous', 'Both', '1', '2', '4', '6')]
        [string]$RefreshType = 'Manual',

        [Parameter(Mandatory=$false)]
        [switch]$PassThru
    )

    begin {
        # Validate connection
        if (-not $script:CMASConnection.SiteServer) {
            throw "No active connection to SCCM Admin Service. Run Connect-CMAS first."
        }

        # Validate that a limiting collection is specified
        if (-not $LimitingCollectionId -and -not $LimitingCollectionName) {
            throw "Either LimitingCollectionId or LimitingCollectionName must be specified."
        }

        # Convert CollectionType string to integer
        $collectionTypeInt = switch ($CollectionType) {
            'User' { 1 }
            '1' { 1 }
            'Device' { 2 }
            '2' { 2 }
            default { 2 }
        }

        # Convert RefreshType string to integer
        $refreshTypeInt = switch ($RefreshType) {
            'Manual' { 1 }
            '1' { 1 }
            'Periodic' { 2 }
            '2' { 2 }
            'Continuous' { 4 }
            '4' { 4 }
            'Both' { 6 }
            '6' { 6 }
            default { 1 }
        }

        # Inform about schedule behavior when RefreshType includes Periodic
        if ($refreshTypeInt -eq 2 -or $refreshTypeInt -eq 6) {
            Write-Verbose "RefreshType set to Periodic/Both. The collection will use a default schedule."
            Write-Verbose "Note: To set a custom schedule, use Set-CMASCollectionSchedule function after creating the collection."
        }
    }

    process {
        try {
            # Resolve LimitingCollectionName to LimitingCollectionId if needed
            $targetLimitingCollectionId = $null

            if ($LimitingCollectionId) {
                $targetLimitingCollectionId = $LimitingCollectionId
            } elseif ($LimitingCollectionName) {
                Write-Verbose "Resolving LimitingCollectionName '$LimitingCollectionName' to CollectionID..."
                $limitingCollection = Get-CMASCollection -Name $LimitingCollectionName
                if (-not $limitingCollection) {
                    throw "Limiting collection with name '$LimitingCollectionName' not found."
                }
                $targetLimitingCollectionId = $limitingCollection.CollectionID
                Write-Verbose "Resolved limiting collection to ID: $targetLimitingCollectionId"
            }

            # Verify limiting collection exists
            Write-Verbose "Verifying limiting collection '$targetLimitingCollectionId' exists..."
            $path = "wmi/SMS_Collection('$targetLimitingCollectionId')"
            $limitingRes = Invoke-CMASApi -Path $path

            if (-not $limitingRes.value -or $limitingRes.value.Count -eq 0) {
                throw "Limiting collection '$targetLimitingCollectionId' not found."
            }

            # Check if collection with the same name already exists
            Write-Verbose "Checking if collection with name '$Name' already exists..."
            $existingCollection = Get-CMASCollection -Name $Name
            if ($existingCollection) {
                throw "A collection with the name '$Name' already exists."
            }

            # Build the collection object
            $newCollection = @{
                Name = $Name
                CollectionType = $collectionTypeInt
                LimitToCollectionID = $targetLimitingCollectionId
                RefreshType = $refreshTypeInt
            }

            # Add optional properties
            if ($Comment) {
                $newCollection.Comment = $Comment
            }

            # RefreshSchedule updates are blocked in the begin block
            # This code is never reached but kept for reference
            # The Admin Service API does not support RefreshSchedule operations

            $description = "collection '$Name' (Type: $CollectionType, Limiting: $targetLimitingCollectionId)"

            if ($PSCmdlet.ShouldProcess($description, "Create new Configuration Manager collection")) {
                Write-Verbose "Creating new collection: $Name"
                Write-Verbose "Collection Type: $collectionTypeInt ($(if($collectionTypeInt -eq 1){'User'}else{'Device'}))"
                Write-Verbose "Limiting Collection: $targetLimitingCollectionId"
                Write-Verbose "Refresh Type: $refreshTypeInt"

                # Create the collection via POST to SMS_Collection
                $createPath = "wmi/SMS_Collection"
                $result = Invoke-CMASApi -Path $createPath -Method POST -Body $newCollection

                if ($result) {
                    Write-Verbose "Collection created successfully"

                    # Retrieve the newly created collection
                    if ($PassThru) {
                        Write-Verbose "Retrieving newly created collection..."
                        Start-Sleep -Seconds 2  # Brief delay to allow replication
                        $createdCollection = Get-CMASCollection -Name $Name

                        if ($createdCollection) {
                            Write-Verbose "Successfully retrieved collection: $($createdCollection.CollectionID)"
                            return $createdCollection
                        } else {
                            Write-Warning "Collection was created but could not be retrieved immediately. Try Get-CMASCollection -Name '$Name'"
                        }
                    } else {
                        Write-Host "Collection '$Name' created successfully." -ForegroundColor Green
                    }
                } else {
                    Write-Error "Failed to create collection. No result returned from API."
                }
            }
        }
        catch {
            Write-Error "Failed to create collection '$Name': $_"
            throw
        }
    }
}
function New-CMASCollectionVariable {
    <#
        .SYNOPSIS
            Creates a new collection variable for a Configuration Manager collection via the Admin Service.

        .DESCRIPTION
            This function creates a custom variable that can be assigned to a specific collection in Configuration Manager
            using the Admin Service API. Collection variables are name-value pairs that can be used in task sequences,
            scripts, and other Configuration Manager operations for all members of the collection.

            Variables can be marked as masked (sensitive) to hide their values in the Configuration Manager console.
            The function supports identifying the target collection by either collection name or CollectionID.

        .PARAMETER CollectionName
            The name of the collection to create the variable for. Either CollectionName or CollectionID must be specified.

        .PARAMETER CollectionID
            The CollectionID of the collection to create the variable for. Either CollectionName or CollectionID must be specified.

        .PARAMETER VariableName
            The name of the variable to create. Variable names should not contain spaces or special characters.
            The name must be unique for the collection.

        .PARAMETER VariableValue
            The value to assign to the variable. Can be any string value.

        .PARAMETER IsMasked
            If specified, marks the variable as masked (sensitive). Masked variables have their values hidden
            in the Configuration Manager console for security purposes.

        .PARAMETER PassThru
            If specified, returns the created variable object.

        .EXAMPLE
            New-CMASCollectionVariable -CollectionName "Production Servers" -VariableName "OSDComputerOU" -VariableValue "OU=Servers,DC=contoso,DC=com"
            Creates a new collection variable named "OSDComputerOU" with the specified OU path for the "Production Servers" collection.

        .EXAMPLE
            New-CMASCollectionVariable -CollectionID "SMS00001" -VariableName "AppPath" -VariableValue "C:\Apps\MyApp" -PassThru
            Creates a new collection variable by CollectionID and returns the created variable object.

        .EXAMPLE
            New-CMASCollectionVariable -CollectionName "Finance Workstations" -VariableName "DBPassword" -VariableValue "P@ssw0rd" -IsMasked
            Creates a new masked (sensitive) collection variable for storing a password.

        .EXAMPLE
            New-CMASCollectionVariable -CollectionName "Test Collection" -VariableName "InstallPath" -VariableValue "D:\Software"
            Creates a simple collection variable for use in deployment task sequences.

        .NOTES
            This function is part of the SCCM Admin Service module.
            Requires an active connection established via Connect-CMAS.

            The function uses the Admin Service REST API to interact with the SMS_CollectionSettings WMI class.
            Variable names must be unique per collection. If a variable with the same name already exists,
            the function will fail.

            Collection variables are commonly used in:
            - Operating System Deployment (OSD) task sequences
            - Application deployment customization
            - Script execution with collection-specific values
            - Configuration baselines

        .LINK
            Connect-CMAS
            Get-CMASCollection
            Get-CMASCollectionVariable
    #>
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
    param(
        [Parameter(Mandatory=$false, ParameterSetName='ByCollectionName')]
        [ValidateNotNullOrEmpty()]
        [string]$CollectionName,

        [Parameter(Mandatory=$false, ParameterSetName='ByCollectionID')]
        [ValidateNotNullOrEmpty()]
        [string]$CollectionID,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^[a-zA-Z0-9_-]+$')]
        [string]$VariableName,

        [Parameter(Mandatory=$true)]
        [AllowEmptyString()]
        [string]$VariableValue,

        [Parameter(Mandatory=$false)]
        [switch]$IsMasked,

        [Parameter(Mandatory=$false)]
        [switch]$PassThru
    )

    begin {
        # Validate connection
        if (-not $script:CMASConnection.SiteServer) {
            throw "No active connection to SCCM Admin Service. Run Connect-CMAS first."
        }

        # Validate that either CollectionName or CollectionID is specified
        if (-not $CollectionName -and -not $CollectionID) {
            throw "Either CollectionName or CollectionID must be specified."
        }
    }

    process {
        try {
            # Resolve collection to CollectionID if needed
            $targetCollectionID = $null
            $targetCollectionName = $null

            if ($CollectionID) {
                $targetCollectionID = $CollectionID
                Write-Verbose "Using CollectionID: $targetCollectionID"

                # Get collection name for display purposes
                $collection = Get-CMASCollection -CollectionID $targetCollectionID
                if (-not $collection) {
                    throw "Collection with CollectionID '$targetCollectionID' not found."
                }
                $targetCollectionName = $collection.Name
            }
            elseif ($CollectionName) {
                Write-Verbose "Resolving CollectionName '$CollectionName' to CollectionID..."
                $collection = Get-CMASCollection -Name $CollectionName
                if (-not $collection) {
                    throw "Collection with name '$CollectionName' not found."
                }
                if (@($collection).Count -gt 1) {
                    throw "Multiple collections found with name '$CollectionName'. Use CollectionID instead."
                }
                $targetCollectionID = $collection.CollectionID
                $targetCollectionName = $collection.Name
                Write-Verbose "Resolved collection to CollectionID: $targetCollectionID"
            }

            # Check if collection settings already exist for this collection
            Write-Verbose "Checking for existing collection settings for CollectionID '$targetCollectionID'..."
            $settingsPath = "wmi/SMS_CollectionSettings('$targetCollectionID')"

            $existingSettings = $null
            $settingsExist = $false

            try {
                $response = Invoke-CMASApi -Path $settingsPath

                # Extract settings from response - API returns { value: [object] }
                $existingSettings = if ($response.value) {
                    $response.value | Select-Object -First 1
                } else {
                    $response
                }

                if ($existingSettings) {
                    # Settings exist
                    $settingsExist = $true
                    Write-Verbose "Found existing CollectionSettings for CollectionID: $targetCollectionID"

                    # Get existing variables for this collection
                    if ($existingSettings.CollectionVariables) {
                        Write-Verbose "Found $(@($existingSettings.CollectionVariables).Count) existing variables"
                        # Check if variable already exists
                        $existingVar = $existingSettings.CollectionVariables | Where-Object { $_.Name -eq $VariableName }
                        if ($existingVar) {
                            throw "A variable with name '$VariableName' already exists for collection '$targetCollectionName'. Use Set-CMASCollectionVariable to modify it."
                        }
                    } else {
                        Write-Verbose "No existing variables found"
                    }
                }
            }
            catch {
                # Check if this is a 404 error (settings don't exist) or another error
                if ($_.Exception.Message -like "*404*" -or $_.Exception.Message -like "*Not Found*") {
                    # Settings don't exist (404 error expected), need to create them
                    Write-Verbose "No existing CollectionSettings found for collection. Will create new CollectionSettings..."
                    $settingsExist = $false
                }
                else {
                    # This is a different error (like duplicate variable), re-throw it
                    throw
                }
            }

            # Build the new variable object
            $newVariable = @{
                Name = $VariableName
                Value = $VariableValue
                IsMasked = $IsMasked.IsPresent
            }

            $description = "collection variable '$VariableName' for collection '$targetCollectionName' (CollectionID: $targetCollectionID)"

            if ($PSCmdlet.ShouldProcess($description, "Create new collection variable")) {
                Write-Verbose "Creating collection variable: $VariableName"
                Write-Verbose "Value: $(if($IsMasked){'[MASKED]'}else{$VariableValue})"
                Write-Verbose "IsMasked: $($IsMasked.IsPresent)"
                Write-Verbose "CollectionID: $targetCollectionID"

                # Determine the variables array
                $variablesArray = @()
                if ($settingsExist) {
                    # Add to existing variables
                    if ($existingSettings.CollectionVariables) {
                        $variablesArray = @($existingSettings.CollectionVariables)
                    }
                }
                # Add the new variable
                $variablesArray = @($variablesArray) + @($newVariable)

                # Prepare the body for PUT
                $updateBody = @{
                    CollectionID = $targetCollectionID
                    CollectionVariables = $variablesArray
                }

                # Add ReplicateToSubSites if it exists in settings
                if ($settingsExist -and $null -ne $existingSettings.ReplicateToSubSites) {
                    $updateBody.ReplicateToSubSites = $existingSettings.ReplicateToSubSites
                }

                # Use PUT to create or update
                $updatePath = "wmi/SMS_CollectionSettings('$targetCollectionID')"
                $result = Invoke-CMASApi -Path $updatePath -Method PUT -Body $updateBody

                if ($result) {
                    Write-Verbose "Collection variable created successfully"

                    if ($PassThru) {
                        # Retrieve the settings again to get the created variable
                        Write-Verbose "PassThru requested - retrieving updated settings..."
                        Start-Sleep -Seconds 2

                        $updatedResponse = Invoke-CMASApi -Path $settingsPath

                        # Extract settings from response - API returns { value: [object] }
                        $updatedSettings = if ($updatedResponse.value) {
                            $updatedResponse.value | Select-Object -First 1
                        } else {
                            $updatedResponse
                        }

                        Write-Verbose "Retrieved settings: $($updatedSettings -ne $null)"
                        Write-Verbose "CollectionVariables exists: $($null -ne $updatedSettings.CollectionVariables)"

                        if ($updatedSettings -and $updatedSettings.CollectionVariables) {
                            Write-Verbose "Number of variables in settings: $(@($updatedSettings.CollectionVariables).Count)"
                            Write-Verbose "Looking for variable: $VariableName"

                            # Find the newly created variable
                            $createdVariable = $updatedSettings.CollectionVariables | Where-Object { $_.Name -eq $VariableName }

                            if ($createdVariable) {
                                # Add collection information to output
                                $createdVariable | Add-Member -NotePropertyName 'CollectionID' -NotePropertyValue $targetCollectionID -Force
                                $createdVariable | Add-Member -NotePropertyName 'CollectionName' -NotePropertyValue $targetCollectionName -Force

                                # Format output - exclude WMI and OData metadata
                                $output = $createdVariable | Select-Object -Property * -ExcludeProperty __*, @odata*

                                Write-Verbose "Successfully retrieved variable"
                                return $output
                            } else {
                                Write-Verbose "Variable names in settings: $($updatedSettings.CollectionVariables.Name -join ', ')"
                                Write-Warning "Variable was created but could not be retrieved immediately."
                            }
                        } else {
                            Write-Warning "Variable was created but could not be retrieved immediately."
                        }
                    } else {
                        Write-Host "Collection variable '$VariableName' created successfully for collection '$targetCollectionName'." -ForegroundColor Green
                    }
                } else {
                    Write-Error "Failed to create collection variable. No result returned from API."
                }
            }
        }
        catch {
            # Just throw the error - don't Write-Error first as it shows up in tests
            throw "Failed to create collection variable '$VariableName' for collection '$targetCollectionName': $_"
        }
    }
}
function New-CMASDeviceVariable {
    <#
        .SYNOPSIS
            Creates a new device variable for a Configuration Manager device via the Admin Service.

        .DESCRIPTION
            This function creates a custom variable that can be assigned to a specific device in Configuration Manager
            using the Admin Service API. Device variables are name-value pairs that can be used in task sequences,
            scripts, and other Configuration Manager operations.

            Variables can be marked as masked (sensitive) to hide their values in the Configuration Manager console.
            The function supports identifying the target device by either device name or ResourceID.

        .PARAMETER DeviceName
            The name of the device to create the variable for. Either DeviceName or ResourceID must be specified.

        .PARAMETER ResourceID
            The ResourceID of the device to create the variable for. Either DeviceName or ResourceID must be specified.

        .PARAMETER VariableName
            The name of the variable to create. Variable names should not contain spaces or special characters.
            The name must be unique for the device.

        .PARAMETER VariableValue
            The value to assign to the variable. Can be any string value.

        .PARAMETER IsMasked
            If specified, marks the variable as masked (sensitive). Masked variables have their values hidden
            in the Configuration Manager console for security purposes.

        .PARAMETER PassThru
            If specified, returns the created variable object.

        .EXAMPLE
            New-CMASDeviceVariable -DeviceName "WORKSTATION01" -VariableName "OSDComputerName" -VariableValue "WS01-NEW"
            Creates a new device variable named "OSDComputerName" with value "WS01-NEW" for device WORKSTATION01.

        .EXAMPLE
            New-CMASDeviceVariable -ResourceID 16777220 -VariableName "AppPath" -VariableValue "C:\Apps\MyApp" -PassThru
            Creates a new device variable by ResourceID and returns the created variable object.

        .EXAMPLE
            New-CMASDeviceVariable -DeviceName "SERVER01" -VariableName "DBPassword" -VariableValue "P@ssw0rd" -IsMasked
            Creates a new masked (sensitive) device variable for storing a password.

        .EXAMPLE
            New-CMASDeviceVariable -DeviceName "WORKSTATION01" -VariableName "InstallPath" -VariableValue "D:\Software"
            Creates a simple device variable for use in deployment task sequences.

        .NOTES
            This function is part of the SCCM Admin Service module.
            Requires an active connection established via Connect-CMAS.

            The function uses the Admin Service REST API to interact with the SMS_MachineSettings WMI class.
            Variable names must be unique per device. If a variable with the same name already exists,
            the function will fail.

            Device variables are commonly used in:
            - Operating System Deployment (OSD) task sequences
            - Application deployment customization
            - Script execution with device-specific values
            - Configuration baselines

        .LINK
            Connect-CMAS
            Get-CMASDevice
    #>
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
    param(
        [Parameter(Mandatory=$false, ParameterSetName='ByDeviceName')]
        [ValidateNotNullOrEmpty()]
        [string]$DeviceName,

        [Parameter(Mandatory=$false, ParameterSetName='ByResourceID')]
        [long]$ResourceID,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^[a-zA-Z0-9_-]+$')]
        [string]$VariableName,

        [Parameter(Mandatory=$true)]
        [AllowEmptyString()]
        [string]$VariableValue,

        [Parameter(Mandatory=$false)]
        [switch]$IsMasked,

        [Parameter(Mandatory=$false)]
        [switch]$PassThru
    )

    begin {
        # Validate connection
        if (-not $script:CMASConnection.SiteServer) {
            throw "No active connection to SCCM Admin Service. Run Connect-CMAS first."
        }

        # Validate that either DeviceName or ResourceID is specified
        if (-not $DeviceName -and -not $ResourceID) {
            throw "Either DeviceName or ResourceID must be specified."
        }
    }

    process {
        try {
            # Resolve device to ResourceID if needed
            $targetResourceID = $null
            $targetDeviceName = $null

            if ($ResourceID) {
                $targetResourceID = $ResourceID
                Write-Verbose "Using ResourceID: $targetResourceID"

                # Get device name for display purposes
                $device = Get-CMASDevice -ResourceID $targetResourceID
                if (-not $device) {
                    throw "Device with ResourceID '$targetResourceID' not found."
                }
                $targetDeviceName = $device.Name
            }
            elseif ($DeviceName) {
                Write-Verbose "Resolving DeviceName '$DeviceName' to ResourceID..."
                $device = Get-CMASDevice -Name $DeviceName
                if (-not $device) {
                    throw "Device with name '$DeviceName' not found."
                }
                if (@($device).Count -gt 1) {
                    throw "Multiple devices found with name '$DeviceName'. Use ResourceID instead."
                }
                $targetResourceID = $device.ResourceID
                $targetDeviceName = $device.Name
                Write-Verbose "Resolved device to ResourceID: $targetResourceID"
            }

            # Check if device settings already exist for this device
            Write-Verbose "Checking for existing device settings for ResourceID '$targetResourceID'..."
            $settingsPath = "wmi/SMS_MachineSettings($targetResourceID)"

            $existingSettings = $null
            $settingsExist = $false

            try {
                $response = Invoke-CMASApi -Path $settingsPath

                # Extract settings from response - API returns { value: [object] }
                $existingSettings = if ($response.value) {
                    $response.value | Select-Object -First 1
                } else {
                    $response
                }

                if ($existingSettings) {
                    # Settings exist
                    $settingsExist = $true
                    Write-Verbose "Found existing MachineSettings for ResourceID: $targetResourceID"

                    # Get existing variables for this device
                    if ($existingSettings.MachineVariables) {
                        Write-Verbose "Found $(@($existingSettings.MachineVariables).Count) existing variables"
                        # Check if variable already exists
                        $existingVar = $existingSettings.MachineVariables | Where-Object { $_.Name -eq $VariableName }
                        if ($existingVar) {
                            throw "A variable with name '$VariableName' already exists for device '$targetDeviceName'. Use Set-CMASDeviceVariable to modify it."
                        }
                    } else {
                        Write-Verbose "No existing variables found"
                    }
                }
            }
            catch {
                # Check if this is a 404 error (settings don't exist) or another error
                if ($_.Exception.Message -like "*404*" -or $_.Exception.Message -like "*Not Found*") {
                    # Settings don't exist (404 error expected), need to create them
                    Write-Verbose "No existing MachineSettings found for device. Will create new MachineSettings..."
                    $settingsExist = $false
                }
                else {
                    # This is a different error (like duplicate variable), re-throw it
                    throw
                }
            }

            # Build the new variable object
            $newVariable = @{
                Name = $VariableName
                Value = $VariableValue
                IsMasked = $IsMasked.IsPresent
            }

            $description = "device variable '$VariableName' for device '$targetDeviceName' (ResourceID: $targetResourceID)"

            if ($PSCmdlet.ShouldProcess($description, "Create new device variable")) {
                Write-Verbose "Creating device variable: $VariableName"
                Write-Verbose "Value: $(if($IsMasked){'[MASKED]'}else{$VariableValue})"
                Write-Verbose "IsMasked: $($IsMasked.IsPresent)"
                Write-Verbose "ResourceID: $targetResourceID"

                # Determine the variables array
                $variablesArray = @()
                if ($settingsExist) {
                    # Add to existing variables
                    if ($existingSettings.MachineVariables) {
                        $variablesArray = @($existingSettings.MachineVariables)
                    }
                }
                # Add the new variable
                $variablesArray = @($variablesArray) + @($newVariable)

                # Prepare the body for PUT
                $updateBody = @{
                    ResourceID = $targetResourceID
                    MachineVariables = $variablesArray
                }

                # Add SourceSite and LocaleID (required for new or updated settings)
                if ($settingsExist) {
                    # Copy from existing settings if available
                    if ($existingSettings.LocaleID) {
                        $updateBody.LocaleID = $existingSettings.LocaleID
                    }
                    if ($existingSettings.SourceSite) {
                        $updateBody.SourceSite = $existingSettings.SourceSite
                    }
                }

                # If settings don't exist or missing required properties, set defaults
                if (-not $updateBody.ContainsKey('LocaleID') -or -not $updateBody.LocaleID) {
                    $updateBody.LocaleID = 1033
                }
                if (-not $updateBody.ContainsKey('SourceSite') -or [string]::IsNullOrEmpty($updateBody.SourceSite)) {
                    $deviceSiteCode = if ($device.SiteCode) { $device.SiteCode } else { "SD1" }
                    $updateBody.SourceSite = $deviceSiteCode
                }

                # Use PUT to create or update
                $updatePath = "wmi/SMS_MachineSettings($targetResourceID)"
                $result = Invoke-CMASApi -Path $updatePath -Method PUT -Body $updateBody

                if ($result) {
                    Write-Verbose "Device variable created successfully"

                    if ($PassThru) {
                        # Retrieve the settings again to get the created variable
                        Write-Verbose "PassThru requested - retrieving updated settings..."
                        Start-Sleep -Seconds 2

                        $updatedResponse = Invoke-CMASApi -Path $settingsPath

                        # Extract settings from response - API returns { value: [object] }
                        $updatedSettings = if ($updatedResponse.value) {
                            $updatedResponse.value | Select-Object -First 1
                        } else {
                            $updatedResponse
                        }

                        Write-Verbose "Retrieved settings: $($updatedSettings -ne $null)"
                        Write-Verbose "MachineVariables exists: $($null -ne $updatedSettings.MachineVariables)"

                        if ($updatedSettings -and $updatedSettings.MachineVariables) {
                            Write-Verbose "Number of variables in settings: $(@($updatedSettings.MachineVariables).Count)"
                            Write-Verbose "Looking for variable: $VariableName"

                            # Find the newly created variable
                            $createdVariable = $updatedSettings.MachineVariables | Where-Object { $_.Name -eq $VariableName }

                            if ($createdVariable) {
                                # Add device information to output
                                $createdVariable | Add-Member -NotePropertyName 'ResourceID' -NotePropertyValue $targetResourceID -Force
                                $createdVariable | Add-Member -NotePropertyName 'DeviceName' -NotePropertyValue $targetDeviceName -Force

                                # Format output - exclude WMI and OData metadata
                                $output = $createdVariable | Select-Object -Property * -ExcludeProperty __*, @odata*

                                Write-Verbose "Successfully retrieved variable"
                                return $output
                            } else {
                                Write-Verbose "Variable names in settings: $($updatedSettings.MachineVariables.Name -join ', ')"
                                Write-Warning "Variable was created but could not be retrieved immediately."
                            }
                        } else {
                            Write-Warning "Variable was created but could not be retrieved immediately."
                        }
                    } else {
                        Write-Host "Device variable '$VariableName' created successfully for device '$targetDeviceName'." -ForegroundColor Green
                    }
                } else {
                    Write-Error "Failed to create device variable. No result returned from API."
                }
            }
        }
        catch {
            # Just throw the error - don't Write-Error first as it shows up in tests
            throw "Failed to create device variable '$VariableName' for device '$targetDeviceName': $_"
        }
    }
}
function Remove-CMASCollection {
    <#
        .SYNOPSIS
            Removes a Configuration Manager collection via the Admin Service.

        .DESCRIPTION
            This function deletes a device or user collection from Configuration Manager using the Admin Service API.
            The collection can be specified by name, ID, or by passing a collection object via pipeline.

            Important notes:
            - Built-in collections (e.g., SMS00001, SMS00002) cannot be deleted
            - Collections containing child collections must have those relationships removed first
            - Collections with deployed applications, packages, or task sequences may need those removed first
            - The function will warn if the collection has members, but will still allow deletion with confirmation

            The function uses the Admin Service REST API to DELETE the SMS_Collection WMI class instance.

        .PARAMETER CollectionName
            The name of the collection to remove.

        .PARAMETER CollectionId
            The ID of the collection to remove.

        .PARAMETER InputObject
            A collection object (from Get-CMASCollection) to remove.
            This parameter accepts pipeline input.

        .PARAMETER Force
            Skip confirmation prompts and suppress warnings about collection members.

        .PARAMETER PassThru
            Returns a boolean indicating success ($true) or failure ($false).

        .EXAMPLE
            Remove-CMASCollection -CollectionName "Test Collection"
            Removes the collection named "Test Collection" with confirmation prompt.

        .EXAMPLE
            Remove-CMASCollection -CollectionId "SMS00100" -Force
            Removes the collection with ID SMS00100 without confirmation.

        .EXAMPLE
            Get-CMASCollection -Name "Old*" | Remove-CMASCollection -Force
            Removes all collections starting with "Old" without confirmation.

        .EXAMPLE
            $collection = Get-CMASCollection -Name "Temporary Collection"
            Remove-CMASCollection -InputObject $collection -PassThru
            Removes the collection and returns a boolean result.

        .EXAMPLE
            Remove-CMASCollection -CollectionName "Test Collection" -WhatIf
            Shows what would happen if the collection were removed, without actually removing it.

        .NOTES
            This function is part of the SCCM Admin Service module.
            Requires an active connection established via Connect-CMAS.

            The Admin Service uses DELETE method on the SMS_Collection class endpoint
            to remove collections. This is a destructive operation that cannot be undone.

            Built-in and system collections are protected and cannot be deleted.

        .LINK
            Connect-CMAS
            Get-CMASCollection
            New-CMASCollection
            Add-CMASCollectionMembershipRule
            Remove-CMASCollectionMembershipRule
    #>
    [CmdletBinding(DefaultParameterSetName='ByName', SupportsShouldProcess=$true, ConfirmImpact='High')]
    param(
        [Parameter(Mandatory=$true, ParameterSetName='ByName')]
        [ValidateNotNullOrEmpty()]
        [Alias('Name')]
        [string]$CollectionName,

        [Parameter(Mandatory=$true, ParameterSetName='ById')]
        [ValidateNotNullOrEmpty()]
        [Alias('Id')]
        [string]$CollectionId,

        [Parameter(Mandatory=$true, ParameterSetName='ByValue', ValueFromPipeline=$true)]
        [ValidateNotNull()]
        [Alias('Collection')]
        [object]$InputObject,

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

        # Protected collections that cannot be deleted
        $protectedCollections = @(
            'SMS00001',  # All Systems
            'SMS00002',  # All Users
            'SMS00003',  # All User Groups
            'SMS00004'   # All Systems
        )
    }

    process {
        try {
            # Resolve the collection
            $targetCollection = $null

            switch ($PSCmdlet.ParameterSetName) {
                'ByName' {
                    Write-Verbose "Resolving collection by name: $CollectionName"
                    $targetCollection = Get-CMASCollection -Name $CollectionName
                    if (-not $targetCollection) {
                        Write-Error "Collection with name '$CollectionName' not found."
                        if ($PassThru) { return $false }
                        return
                    }
                    # Handle multiple collections with same name
                    if ($targetCollection -is [array] -and $targetCollection.Count -gt 1) {
                        Write-Error "Multiple collections found with name '$CollectionName'. Use -CollectionId to specify which one to remove."
                        if ($PassThru) { return $false }
                        return
                    }
                }
                'ById' {
                    Write-Verbose "Resolving collection by ID: $CollectionId"
                    $targetCollection = Get-CMASCollection -CollectionId $CollectionId
                    if (-not $targetCollection) {
                        Write-Error "Collection with ID '$CollectionId' not found."
                        if ($PassThru) { return $false }
                        return
                    }
                }
                'ByValue' {
                    Write-Verbose "Using provided collection object"
                    $targetCollection = $InputObject
                    if (-not $targetCollection.CollectionID) {
                        Write-Error "Invalid collection object. Missing CollectionID property."
                        if ($PassThru) { return $false }
                        return
                    }
                }
            }

            # Extract collection details
            $collectionId = $targetCollection.CollectionID
            $collectionName = $targetCollection.Name
            $collectionType = $targetCollection.CollectionType
            $memberCount = if ($targetCollection.MemberCount) { $targetCollection.MemberCount } else { 0 }

            Write-Verbose "Target Collection: $collectionName (ID: $collectionId)"
            Write-Verbose "Collection Type: $collectionType ($(if($collectionType -eq 1){'User'}elseif($collectionType -eq 2){'Device'}else{'Other'}))"
            Write-Verbose "Member Count: $memberCount"

            # Check if collection is protected
            if ($collectionId -in $protectedCollections) {
                Write-Error "Cannot remove protected system collection '$collectionName' (ID: $collectionId)."
                if ($PassThru) { return $false }
                return
            }

            # Warn about member count
            if ($memberCount -gt 0 -and -not $Force) {
                Write-Warning "Collection '$collectionName' has $memberCount member(s). These memberships will be removed along with the collection."
            }

            # Build description for ShouldProcess
            $description = "collection '$collectionName' (ID: $collectionId)"
            if ($memberCount -gt 0) {
                $description += " with $memberCount member(s)"
            }

            # Determine if we should prompt
            $shouldContinue = $true
            if (-not $Force -and -not $PSCmdlet.ShouldProcess($description, "Remove Configuration Manager collection")) {
                $shouldContinue = $false
            }

            if ($shouldContinue) {
                Write-Verbose "Removing collection: $collectionName (ID: $collectionId)"

                # Delete the collection via DELETE method
                $deletePath = "wmi/SMS_Collection('$collectionId')"
                $result = Invoke-CMASApi -Path $deletePath -Method DELETE

                # The DELETE method typically returns no content on success
                Write-Host "Collection '$collectionName' (ID: $collectionId) removed successfully." -ForegroundColor Green

                if ($PassThru) {
                    return $true
                }
            } else {
                Write-Verbose "Collection removal cancelled by user."
                if ($PassThru) {
                    return $false
                }
            }
        }
        catch {
            $errorMessage = $_.Exception.Message
           
            # Build error message with available information
            $identifier = if ($PSCmdlet.ParameterSetName -eq 'ByName') {
                "'$CollectionName'"
            } elseif ($PSCmdlet.ParameterSetName -eq 'ById') {
                "'$CollectionId'"
            } else {
                "provided collection"
            }
            
            Write-Error "Failed to remove collection $identifier : $errorMessage"

            if ($PassThru) {
                return $false
            }
            throw
        }
    }
}
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
function Remove-CMASDeviceVariable {
    <#
        .SYNOPSIS
            Removes device variables from a Configuration Manager device via the Admin Service.

        .DESCRIPTION
            This function removes custom variables that are assigned to a specific device in Configuration Manager
            using the Admin Service API. Device variables can be removed by exact name or using wildcard patterns
            to remove multiple variables at once.

            The function supports identifying the target device by either device name or ResourceID.
            Supports pipeline input from Get-CMASDevice or Get-CMASDeviceVariable.

        .PARAMETER DeviceName
            The name of the device to remove variables from. Either DeviceName or ResourceID must be specified.

        .PARAMETER ResourceID
            The ResourceID of the device to remove variables from. Either DeviceName or ResourceID must be specified.

        .PARAMETER VariableName
            The name of the variable(s) to remove. Supports wildcard patterns (*) for removing multiple variables.
            If using wildcards, all matching variables will be removed.

        .PARAMETER Force
            If specified, suppresses confirmation prompts when removing variables.

        .PARAMETER WhatIf
            Shows what would happen if the cmdlet runs. The cmdlet is not run.

        .PARAMETER Confirm
            Prompts you for confirmation before running the cmdlet.

        .EXAMPLE
            Remove-CMASDeviceVariable -DeviceName "WORKSTATION01" -VariableName "OSDComputerName" -Force
            Removes the device variable named "OSDComputerName" from device WORKSTATION01 without confirmation.

        .EXAMPLE
            Remove-CMASDeviceVariable -ResourceID 16777220 -VariableName "AppPath"
            Removes the device variable named "AppPath" from the device with ResourceID 16777220 with confirmation prompt.

        .EXAMPLE
            Remove-CMASDeviceVariable -DeviceName "SERVER01" -VariableName "Temp*" -Force
            Removes all device variables starting with "Temp" from device SERVER01 without confirmation.

        .EXAMPLE
            Get-CMASDevice -Name "WORKSTATION01" | Remove-CMASDeviceVariable -VariableName "OSDVar" -Force
            Uses pipeline input to remove a device variable.

        .EXAMPLE
            Get-CMASDeviceVariable -DeviceName "SERVER01" -VariableName "OldVar*" | Remove-CMASDeviceVariable -Force
            Removes all variables matching the pattern by piping from Get-CMASDeviceVariable.

        .EXAMPLE
            Remove-CMASDeviceVariable -DeviceName "WORKSTATION01" -VariableName "TestVar" -WhatIf
            Shows what would be removed without actually removing the variable.

        .NOTES
            This function is part of the SCCM Admin Service module.
            Requires an active connection established via Connect-CMAS.

            The function uses the Admin Service REST API to interact with the SMS_MachineSettings WMI class.
            When removing variables, the entire SMS_MachineSettings object is updated. If all variables are
            removed, an empty MachineVariables array is maintained to preserve the settings object.

            Returns the removed variable object(s) to the pipeline.

        .LINK
            Connect-CMAS
            Get-CMASDevice
            Get-CMASDeviceVariable
            New-CMASDeviceVariable
    #>
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High', DefaultParameterSetName='ByDeviceName')]
    param(
        [Parameter(Mandatory=$false, ParameterSetName='ByDeviceName', Position=0)]
        [ValidateNotNullOrEmpty()]
        [string]$DeviceName,

        [Parameter(Mandatory=$false, ParameterSetName='ByResourceID', Position=0, ValueFromPipelineByPropertyName=$true)]
        [long]$ResourceID,

        [Parameter(Mandatory=$true, Position=1, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [SupportsWildcards()]
        [Alias('Name')]
        [string]$VariableName,

        [Parameter(Mandatory=$false)]
        [switch]$Force
    )

    begin {
        # Validate connection
        if (-not $script:CMASConnection.SiteServer) {
            throw "No active connection to SCCM Admin Service. Run Connect-CMAS first."
        }

        # Collection to hold removed variables
        $removedVariables = @()
    }

    process {
        try {
            # Validate that either DeviceName or ResourceID is specified
            if (-not $DeviceName -and -not $ResourceID) {
                throw "Either DeviceName or ResourceID must be specified."
            }

            # Resolve device to ResourceID if needed
            $targetResourceID = $null
            $targetDeviceName = $null

            if ($ResourceID) {
                $targetResourceID = $ResourceID
                Write-Verbose "Using ResourceID: $targetResourceID"

                # Get device name for display purposes
                $device = Get-CMASDevice -ResourceID $targetResourceID
                if (-not $device) {
                    throw "Device with ResourceID '$targetResourceID' not found."
                }
                $targetDeviceName = $device.Name
            }
            elseif ($DeviceName) {
                Write-Verbose "Resolving DeviceName '$DeviceName' to ResourceID..."
                $device = Get-CMASDevice -Name $DeviceName
                if (-not $device) {
                    throw "Device with name '$DeviceName' not found."
                }
                if (@($device).Count -gt 1) {
                    throw "Multiple devices found with name '$DeviceName'. Use ResourceID instead."
                }
                $targetResourceID = $device.ResourceID
                $targetDeviceName = $device.Name
                Write-Verbose "Resolved device to ResourceID: $targetResourceID"
            }

            # Get current device settings
            Write-Verbose "Retrieving device settings for ResourceID '$targetResourceID'..."
            $settingsPath = "wmi/SMS_MachineSettings($targetResourceID)"

            $existingSettings = $null
            try {
                $response = Invoke-CMASApi -Path $settingsPath

                # Extract settings from response
                $existingSettings = if ($response.value) {
                    $response.value | Select-Object -First 1
                } else {
                    $response
                }

                if (-not $existingSettings) {
                    Write-Warning "No device settings found for device '$targetDeviceName' (ResourceID: $targetResourceID)."
                    return
                }
            }
            catch {
                if ($_.Exception.Message -like "*404*" -or $_.Exception.Message -like "*Not Found*") {
                    Write-Warning "No device settings found for device '$targetDeviceName' (ResourceID: $targetResourceID)."
                    return
                }
                else {
                    throw
                }
            }

            # Check if device has any variables
            if (-not $existingSettings.MachineVariables -or @($existingSettings.MachineVariables).Count -eq 0) {
                Write-Warning "Device '$targetDeviceName' has no variables to remove."
                return
            }

            # Convert to array for consistency
            $currentVariables = @($existingSettings.MachineVariables)
            Write-Verbose "Found $($currentVariables.Count) existing variable(s)"

            # Find variables to remove using wildcard matching
            $variablesToRemove = @()
            $variablesToKeep = @()

            # Check if VariableName contains wildcards
            $hasWildcard = $VariableName -match '[*?]'

            foreach ($var in $currentVariables) {
                if ($hasWildcard) {
                    # Use wildcard matching
                    if ($var.Name -like $VariableName) {
                        $variablesToRemove += $var
                        Write-Verbose "Matched variable for removal: $($var.Name)"
                    }
                    else {
                        $variablesToKeep += $var
                    }
                }
                else {
                    # Exact match
                    if ($var.Name -eq $VariableName) {
                        $variablesToRemove += $var
                        Write-Verbose "Found exact match for removal: $($var.Name)"
                    }
                    else {
                        $variablesToKeep += $var
                    }
                }
            }

            # Check if any variables were found to remove
            if ($variablesToRemove.Count -eq 0) {
                Write-Warning "No variables matching '$VariableName' found on device '$targetDeviceName'."
                return
            }

            Write-Verbose "Variables to remove: $($variablesToRemove.Count)"
            Write-Verbose "Variables to keep: $($variablesToKeep.Count)"

            # Build description for ShouldProcess
            if ($variablesToRemove.Count -eq 1) {
                $description = "device variable '$($variablesToRemove[0].Name)' from device '$targetDeviceName' (ResourceID: $targetResourceID)"
            }
            else {
                $varNames = ($variablesToRemove | ForEach-Object { $_.Name }) -join "', '"
                $description = "$($variablesToRemove.Count) device variables ('$varNames') from device '$targetDeviceName' (ResourceID: $targetResourceID)"
            }

            # Determine if confirmation is needed
            $shouldProcessConfirm = $true
            if ($Force) {
                # Force parameter overrides confirmation
                $shouldProcessConfirm = $PSCmdlet.ShouldProcess($description, "Remove")
            }
            else {
                # Show confirmation prompt
                $shouldProcessConfirm = $PSCmdlet.ShouldProcess($description, "Remove device variable(s)")
            }

            if ($shouldProcessConfirm) {
                Write-Verbose "Removing $($variablesToRemove.Count) variable(s)..."

                # Prepare the updated settings
                $updateBody = @{
                    ResourceID = $targetResourceID
                    MachineVariables = $variablesToKeep
                }

                # Copy required properties
                if ($existingSettings.LocaleID) {
                    $updateBody.LocaleID = $existingSettings.LocaleID
                }
                else {
                    $updateBody.LocaleID = 1033
                }

                if ($existingSettings.SourceSite) {
                    $updateBody.SourceSite = $existingSettings.SourceSite
                }
                else {
                    $deviceSiteCode = if ($device.SiteCode) { $device.SiteCode } else { "SD1" }
                    $updateBody.SourceSite = $deviceSiteCode
                }

                # Update the settings
                $updatePath = "wmi/SMS_MachineSettings($targetResourceID)"
                $result = Invoke-CMASApi -Path $updatePath -Method PUT -Body $updateBody

                if ($result) {
                    Write-Verbose "Device variable(s) removed successfully"

                    # Add device information to the removed variables and return them
                    foreach ($var in $variablesToRemove) {
                        $var | Add-Member -NotePropertyName 'ResourceID' -NotePropertyValue $targetResourceID -Force
                        $var | Add-Member -NotePropertyName 'DeviceName' -NotePropertyValue $targetDeviceName -Force

                        # Format output - exclude WMI and OData metadata
                        $output = $var | Select-Object -Property * -ExcludeProperty __*, @odata*
                        $removedVariables += $output
                    }

                    # Output summary message
                    if ($variablesToRemove.Count -eq 1) {
                        Write-Host "Device variable '$($variablesToRemove[0].Name)' removed from device '$targetDeviceName'." -ForegroundColor Green
                    }
                    else {
                        Write-Host "Removed $($variablesToRemove.Count) device variable(s) from device '$targetDeviceName'." -ForegroundColor Green
                    }
                }
                else {
                    Write-Error "Failed to remove device variable(s). No result returned from API."
                }
            }
            else {
                Write-Verbose "Operation cancelled by user or WhatIf"
            }
        }
        catch {
            Write-Error "Failed to remove device variable: $($_.Exception.Message)"
            Write-Verbose "Error details: $($_ | Out-String)"
        }
    }

    end {
        # Return all removed variables
        if ($removedVariables.Count -gt 0) {
            return $removedVariables
        }
    }
}
function Set-CMASCollection {
    <#
        .SYNOPSIS
            Modifies properties of a Configuration Manager collection via the Admin Service.

        .DESCRIPTION
            This function updates an existing device or user collection in Configuration Manager using the Admin Service API.
            You can modify collection properties such as name, comment, refresh type, and refresh schedule.

            The function supports updating various collection properties:
            - Name: Change the collection name
            - Comment: Add or modify the collection description
            - RefreshType: Change between Manual, Periodic, Continuous, or Both
            - LimitingCollectionId/Name: Change the limiting collection (use with caution)

            Note: RefreshSchedule updates are NOT supported via Admin Service API.
            Use Set-CMASCollectionSchedule (CIM-based) to manage collection schedules.

            The function uses the Admin Service REST API to PATCH the SMS_Collection WMI class instance.

        .PARAMETER CollectionName
            The current name of the collection to modify.

        .PARAMETER CollectionId
            The ID of the collection to modify.

        .PARAMETER InputObject
            A collection object (from Get-CMASCollection) to modify.
            This parameter accepts pipeline input.

        .PARAMETER NewName
            The new name for the collection. Must be unique within Configuration Manager.

        .PARAMETER Comment
            The new comment or description for the collection. Pass empty string to clear.

        .PARAMETER RefreshType
            The new refresh type for the collection:
            - Manual (1): Manual updates only
            - Periodic (2): Scheduled updates
            - Continuous (4): Incremental updates (continuous evaluation)
            - Both (6): Periodic and Continuous (2 + 4)


        .PARAMETER LimitingCollectionName
            The name of the new limiting collection. The function will look up the CollectionID automatically.

        .PARAMETER PassThru
            Returns the updated collection object.

        .EXAMPLE
            Set-CMASCollection -CollectionName "Old Name" -NewName "New Name"
            Renames a collection.

        .EXAMPLE
            Set-CMASCollection -CollectionId "SMS00100" -Comment "Updated description" -PassThru
            Updates the collection comment and returns the updated collection object.

        .EXAMPLE
            Set-CMASCollection -CollectionName "My Collection" -RefreshType Continuous -Comment "Auto-updating collection"
            Changes the refresh type to continuous and updates the comment.

        .EXAMPLE
            Set-CMASCollection -CollectionName "My Collection" -RefreshType Periodic
            Changes the refresh type to periodic. The collection will use its existing schedule or a default schedule.
            Note: RefreshSchedule cannot be updated via Admin Service API. Use SCCM Console or ConfigurationManager module.

        .EXAMPLE
            Get-CMASCollection -Name "Test*" | Set-CMASCollection -Comment "Test collection" -RefreshType Manual
            Updates all collections starting with "Test" via pipeline.

        .EXAMPLE
            Set-CMASCollection -CollectionName "My Collection" -NewName "Renamed Collection" -RefreshType Both -PassThru
            Updates both the name and refresh type, returning the updated collection.

        .EXAMPLE
            Set-CMASCollection -CollectionName "Collection A" -LimitingCollectionName "All Systems" -WhatIf
            Shows what would happen if the limiting collection were changed, without actually changing it.

        .NOTES
            This function is part of the SCCM Admin Service module.
            Requires an active connection established via Connect-CMAS.

            The Admin Service uses PATCH method on the SMS_Collection class endpoint to update collections.

            Important considerations:
            - Changing the limiting collection can cause members to be removed if they don't match the new limiting collection
            - Collection names must be unique across all collections in Configuration Manager
            - When changing RefreshType to Periodic, the collection will use its existing schedule or a default schedule
            - To update RefreshSchedule, use Set-CMASCollectionSchedule function

            Refresh Types:
            - 1 = Manual only
            - 2 = Scheduled (Periodic) only
            - 4 = Incremental (Continuous) only
            - 6 = Scheduled and Incremental (Both)

        .LINK
            Connect-CMAS
            Get-CMASCollection
            New-CMASCollection
            Remove-CMASCollection
            Set-CMASCollectionSchedule
    #>
    [CmdletBinding(DefaultParameterSetName='ByName', SupportsShouldProcess=$true, ConfirmImpact='Medium')]
    param(
        [Parameter(Mandatory=$true, ParameterSetName='ByName')]
        [ValidateNotNullOrEmpty()]
        [Alias('Name')]
        [string]$CollectionName,

        [Parameter(Mandatory=$true, ParameterSetName='ById')]
        [ValidateNotNullOrEmpty()]
        [Alias('Id')]
        [string]$CollectionId,

        [Parameter(Mandatory=$true, ParameterSetName='ByValue', ValueFromPipeline=$true)]
        [ValidateNotNull()]
        [Alias('Collection')]
        [object]$InputObject,

        [Parameter(Mandatory=$false)]
        [string]$NewName,

        [Parameter(Mandatory=$false)]
        [string]$Comment,

        [Parameter(Mandatory=$false)]
        [ValidateSet('Manual', 'Periodic', 'Continuous', 'Both', '1', '2', '4', '6')]
        [string]$RefreshType,

        [Parameter(Mandatory=$false)]
        [string]$LimitingCollectionId,

        [Parameter(Mandatory=$false)]
        [string]$LimitingCollectionName,

        [Parameter(Mandatory=$false)]
        [switch]$PassThru
    )

    begin {
        # Validate connection
        if (-not $script:CMASConnection.SiteServer) {
            throw "No active connection to SCCM Admin Service. Run Connect-CMAS first."
        }

        # Check if at least one property to update is specified
        if (-not $NewName -and -not $PSBoundParameters.ContainsKey('Comment') -and
            -not $RefreshType -and -not $LimitingCollectionId -and -not $LimitingCollectionName) {
            throw "At least one property to update must be specified (NewName, Comment, RefreshType, or LimitingCollection)."
        }

        # Convert RefreshType string to integer if provided
        $refreshTypeInt = $null
        if ($RefreshType) {
            $refreshTypeInt = switch ($RefreshType) {
                'Manual' { 1 }
                '1' { 1 }
                'Periodic' { 2 }
                '2' { 2 }
                'Continuous' { 4 }
                '4' { 4 }
                'Both' { 6 }
                '6' { 6 }
                default { $null }
            }
        }

        # Inform about schedule behavior when RefreshType includes Periodic
        if ($refreshTypeInt -and ($refreshTypeInt -eq 2 -or $refreshTypeInt -eq 6)) {
            Write-Verbose "RefreshType set to Periodic/Both. The collection will keep its existing schedule or use a default schedule."
            Write-Verbose "Note: To update RefreshSchedule, use the Set-CMASCollectionSchedule function."
        }
    }

    process {
        try {
            # Resolve the collection
            $targetCollection = $null

            switch ($PSCmdlet.ParameterSetName) {
                'ByName' {
                    Write-Verbose "Resolving collection by name: $CollectionName"
                    $targetCollection = Get-CMASCollection -Name $CollectionName
                    if (-not $targetCollection) {
                        throw "Collection with name '$CollectionName' not found."
                    }
                    # Handle multiple collections with same name
                    if ($targetCollection -is [array] -and $targetCollection.Count -gt 1) {
                        throw "Multiple collections found with name '$CollectionName'. Use -CollectionId to specify which one to modify."
                    }
                }
                'ById' {
                    Write-Verbose "Resolving collection by ID: $CollectionId"
                    $targetCollection = Get-CMASCollection -CollectionId $CollectionId
                    if (-not $targetCollection) {
                        throw "Collection with ID '$CollectionId' not found."
                    }
                }
                'ByValue' {
                    Write-Verbose "Using provided collection object"
                    $targetCollection = $InputObject
                    if (-not $targetCollection.CollectionID) {
                        throw "Invalid collection object. Missing CollectionID property."
                    }
                }
            }

            # Build the update object with required properties and properties that should be changed
            # Always include required fields for PUT/PATCH operations
            $updateObject = @{
                CollectionID = $targetCollection.CollectionID
                Name = $targetCollection.Name
                CollectionType = $targetCollection.CollectionType
                LimitToCollectionID = $targetCollection.LimitToCollectionID
                RefreshType = $targetCollection.RefreshType
            }

            # Include Comment if it exists on the target collection
            if ($targetCollection.PSObject.Properties.Name -contains 'Comment' -and $null -ne $targetCollection.Comment) {
                $updateObject.Comment = $targetCollection.Comment
            }

            # Only include RefreshSchedule if it exists and has a valid value
            # AND we're not explicitly updating it (to avoid null conflicts)
            # This avoids sending null or empty values which cause API errors
            if (-not $RefreshSchedule -and ($targetCollection.PSObject.Properties.Name -contains 'RefreshSchedule')) {
                $schedule = $targetCollection.RefreshSchedule
                $hasValidSchedule = $false

                if ($null -ne $schedule -and $schedule -isnot [System.DBNull]) {
                    if ($schedule -is [array]) {
                        $hasValidSchedule = $schedule.Count -gt 0
                    } else {
                        $hasValidSchedule = $true
                    }
                }

                if ($hasValidSchedule) {
                    # Ensure RefreshSchedule is always an array for PUT operations
                    $updateObject.RefreshSchedule = if ($schedule -is [array]) { $schedule } else { @($schedule) }
                }
            }

            $changeDescription = @()

            # Update Name
            if ($NewName) {
                if ($NewName -ne $targetCollection.Name) {
                    # Check if new name already exists
                    $existingCollection = Get-CMASCollection -Name $NewName
                    if ($existingCollection) {
                        throw "A collection with the name '$NewName' already exists."
                    }
                    $updateObject.Name = $NewName
                    $changeDescription += "Name: '$($targetCollection.Name)' -> '$NewName'"
                } else {
                    Write-Verbose "NewName is the same as current name, skipping."
                }
            }

            # Update Comment
            if ($PSBoundParameters.ContainsKey('Comment')) {
                if ($Comment -ne $targetCollection.Comment) {
                    $updateObject.Comment = $Comment
                    $changeDescription += "Comment: '$($targetCollection.Comment)' -> '$Comment'"
                } else {
                    Write-Verbose "Comment is the same as current comment, skipping."
                }
            }

            # Update RefreshType
            if ($refreshTypeInt -and $refreshTypeInt -ne $targetCollection.RefreshType) {
                $updateObject.RefreshType = $refreshTypeInt
                $changeDescription += "RefreshType: $($targetCollection.RefreshType) -> $refreshTypeInt"
            }

            # Note: RefreshSchedule updates are blocked in the begin block
            # The Admin Service API does not support RefreshSchedule operations
            # Use Set-CMASCollectionSchedule instead for schedule management via CIM

            # Update LimitingCollection
            $targetLimitingCollectionId = $null
            if ($LimitingCollectionId) {
                $targetLimitingCollectionId = $LimitingCollectionId
            } elseif ($LimitingCollectionName) {
                Write-Verbose "Resolving LimitingCollectionName '$LimitingCollectionName' to CollectionID..."
                $limitingCollection = Get-CMASCollection -Name $LimitingCollectionName
                if (-not $limitingCollection) {
                    throw "Limiting collection with name '$LimitingCollectionName' not found."
                }
                $targetLimitingCollectionId = $limitingCollection.CollectionID
                Write-Verbose "Resolved limiting collection to ID: $targetLimitingCollectionId"
            }

            if ($targetLimitingCollectionId) {
                if ($targetLimitingCollectionId -ne $targetCollection.LimitToCollectionID) {
                    # Verify limiting collection exists
                    Write-Verbose "Verifying limiting collection '$targetLimitingCollectionId' exists..."
                    $path = "wmi/SMS_Collection('$targetLimitingCollectionId')"
                    $limitingRes = Invoke-CMASApi -Path $path

                    if (-not $limitingRes.value -or $limitingRes.value.Count -eq 0) {
                        throw "Limiting collection '$targetLimitingCollectionId' not found."
                    }

                    $updateObject.LimitToCollectionID = $targetLimitingCollectionId
                    $changeDescription += "LimitToCollectionID: '$($targetCollection.LimitToCollectionID)' -> '$targetLimitingCollectionId'"
                } else {
                    Write-Verbose "LimitingCollectionId is the same as current limiting collection, skipping."
                }
            }

            # Check if there are actually changes to make
            if ($changeDescription.Count -eq 0) {
                Write-Warning "No changes detected. All specified values match current collection properties."
                if ($PassThru) {
                    return $targetCollection
                }
                return
            }

            $description = "collection '$($targetCollection.Name)' ($($targetCollection.CollectionID)): $($changeDescription -join ', ')"

            if ($PSCmdlet.ShouldProcess($description, "Update Configuration Manager collection")) {
                Write-Verbose "Updating collection: $($targetCollection.Name) ($($targetCollection.CollectionID))"
                foreach ($change in $changeDescription) {
                    Write-Verbose "  $change"
                }

                Write-Verbose "Update object being sent to API:"
                Write-Verbose ($updateObject | ConvertTo-Json -Depth 10 -Compress)

                # Update the collection via PUT to SMS_Collection
                $updatePath = "wmi/SMS_Collection('$($targetCollection.CollectionID)')"
                $result = Invoke-CMASApi -Path $updatePath -Method PUT -Body $updateObject

                Write-Verbose "Collection updated successfully"

                if ($PassThru) {
                    Write-Verbose "Retrieving updated collection..."
                    Start-Sleep -Seconds 2  # Brief delay to allow replication

                    # Retrieve by ID since name might have changed
                    $updatedCollection = Get-CMASCollection -CollectionId $targetCollection.CollectionID

                    if ($updatedCollection) {
                        Write-Verbose "Successfully retrieved updated collection"
                        return $updatedCollection
                    } else {
                        Write-Warning "Collection was updated but could not be retrieved immediately."
                    }
                } else {
                    Write-Host "Collection '$($targetCollection.Name)' updated successfully." -ForegroundColor Green
                }
            }
        }
        catch {
            Write-Error "Failed to update collection '$($targetCollection.Name)': $_"
            throw
        }
    }
}
function Set-CMASCollectionSchedule {
    <#
        .SYNOPSIS
            Sets the refresh schedule for a collection using CIM cmdlets.

        .DESCRIPTION
            This function uses CIM (WMI) directly to set the refresh schedule for a Configuration Manager collection.
            This is a workaround for the Admin Service API limitation that doesn't support RefreshSchedule operations.

            ** REQUIREMENTS **:
            - WinRM must be enabled on the SMS Provider server
            - You must have permissions to access the SMS Provider via CIM/WMI
            - Works in PowerShell 5.1 and PowerShell 7.x

            This function creates a schedule token using the same approach as the ConfigurationManager module,
            but works directly with CIM cmdlets so it's compatible with PowerShell 7.x.

        .PARAMETER CollectionName
            The name of the collection to update.

        .PARAMETER CollectionId
            The ID of the collection to update.

        .PARAMETER RecurInterval
            The interval for recurring schedules. Valid values: Minutes, Hours, Days

        .PARAMETER RecurCount
            The number of intervals between recurrences (e.g., 1 for daily, 7 for weekly).

        .PARAMETER StartTime
            Optional. The start date/time for the schedule. Defaults to current time.

        .PARAMETER SiteServer
            Optional. The SMS Provider server name. Uses the connected server from Connect-CMAS if not specified.

        .PARAMETER SiteCode
            Optional. The site code. Uses the connected site from Connect-CMAS if not specified.

        .PARAMETER Credential
            Optional. Credentials for CIM connection. Uses current credentials if not specified.

        .EXAMPLE
            Set-CMASCollectionSchedule -CollectionName "My Collection" -RecurInterval Days -RecurCount 1
            Sets the collection to refresh daily starting now.

        .EXAMPLE
            Set-CMASCollectionSchedule -CollectionId "SMS00100" -RecurInterval Days -RecurCount 7 -StartTime (Get-Date "2026-02-15 02:00")
            Sets the collection to refresh weekly starting at 2 AM on Feb 15.

        .EXAMPLE
            Set-CMASCollectionSchedule -CollectionName "Servers" -RecurInterval Hours -RecurCount 4 -Credential $Cred
            Sets the collection to refresh every 4 hours using specific credentials.

        .NOTES
            This function requires WinRM/CIM access to the SMS Provider server.
            If WinRM is not available, use the SCCM Console or ConfigurationManager PowerShell module instead.

        .LINK
            Set-CMASCollection
            Connect-CMAS
    #>
    [CmdletBinding(DefaultParameterSetName='ByName', SupportsShouldProcess=$true, ConfirmImpact='Medium')]
    param(
        [Parameter(Mandatory=$true, ParameterSetName='ByName')]
        [ValidateNotNullOrEmpty()]
        [string]$CollectionName,

        [Parameter(Mandatory=$true, ParameterSetName='ById')]
        [ValidateNotNullOrEmpty()]
        [string]$CollectionId,

        [Parameter(Mandatory=$true)]
        [ValidateSet('Minutes', 'Hours', 'Days')]
        [string]$RecurInterval,

        [Parameter(Mandatory=$true)]
        [ValidateRange(1, 365)]
        [int]$RecurCount,

        [Parameter(Mandatory=$false)]
        [DateTime]$StartTime = (Get-Date),

        [Parameter(Mandatory=$false)]
        [string]$SiteServer,

        [Parameter(Mandatory=$false)]
        [string]$SiteCode,

        [Parameter(Mandatory=$false)]
        [pscredential]$Credential
    )

    begin {
        # Use stored connection if parameters not provided
        if (-not $SiteServer) {
            $SiteServer = $script:CMASConnection.SiteServer
            if (-not $SiteServer) {
                throw "No SiteServer specified and no active connection. Run Connect-CMAS first or provide -SiteServer parameter."
            }
        }
        if (-not $SiteCode) {
            $SiteCode = $script:CMASConnection.SiteCode
            if (-not $SiteCode) {
                throw "No SiteCode specified and no active connection. Run Connect-CMAS first or provide -SiteCode parameter."
            }
        }
        if (-not $Credential) {
            $Credential = $script:CMASConnection.Credential
        }

        $namespace = "root\sms\site_$SiteCode"
        Write-Verbose "Using SMS Provider: $SiteServer, Namespace: $namespace"
    }

    process {
        try {
            # Create CIM session
            Write-Verbose "Creating CIM session to $SiteServer..."
            $sessionParams = @{
                ComputerName = $SiteServer
                ErrorAction = 'Stop'
            }
            if ($Credential) {
                $sessionParams.Credential = $Credential
            }

            try {
                $cimSession = New-CimSession @sessionParams
            }
            catch {
                throw "Failed to create CIM session to '$SiteServer'. Ensure WinRM is enabled and accessible. Error: $_"
            }

            # Get the collection
            Write-Verbose "Retrieving collection..."
            if ($PSCmdlet.ParameterSetName -eq 'ByName') {
                $collection = Get-CimInstance -CimSession $cimSession -Namespace $namespace `
                    -ClassName SMS_Collection -Filter "Name='$CollectionName'" -ErrorAction Stop
                if (-not $collection) {
                    throw "Collection '$CollectionName' not found."
                }
            }
            else {
                $collection = Get-CimInstance -CimSession $cimSession -Namespace $namespace `
                    -ClassName SMS_Collection -Filter "CollectionID='$CollectionId'" -ErrorAction Stop
                if (-not $collection) {
                    throw "Collection '$CollectionId' not found."
                }
            }

            # Get the lazy properties (RefreshSchedule is a lazy property)
            Write-Verbose "Getting full collection properties..."
            $collection = $collection | Get-CimInstance

            # Create schedule token
            Write-Verbose "Creating schedule token: $RecurInterval every $RecurCount interval(s)"
            $scheduleClass = Get-CimClass -CimSession $cimSession -Namespace $namespace `
                -ClassName SMS_ST_RecurInterval -ErrorAction Stop

            # Build schedule properties hashtable
            $scheduleProperties = @{
                DaySpan = 0
                HourSpan = 0
                MinuteSpan = 0
                StartTime = $StartTime  # CIM expects DateTime object, not string
                IsGMT = $false
            }

            # Set the appropriate span based on interval type
            switch ($RecurInterval) {
                'Minutes' { $scheduleProperties.MinuteSpan = $RecurCount }
                'Hours' { $scheduleProperties.HourSpan = $RecurCount }
                'Days' { $scheduleProperties.DaySpan = $RecurCount }
            }

            Write-Verbose "Schedule properties: Interval=$RecurInterval, Count=$RecurCount, StartTime=$StartTime"
            $scheduleToken = New-CimInstance -CimClass $scheduleClass -Property $scheduleProperties -ClientOnly

            # Update the collection
            $collection.RefreshSchedule = @($scheduleToken)
            $collection.RefreshType = 2  # 2 = Periodic

            $description = "collection '$($collection.Name)' ($($collection.CollectionID)) with $RecurInterval/$RecurCount schedule"

            if ($PSCmdlet.ShouldProcess($description, "Update refresh schedule")) {
                Write-Verbose "Saving collection changes via CIM..."
                Set-CimInstance -CimSession $cimSession -InputObject $collection -ErrorAction Stop
                Write-Host "Successfully updated refresh schedule for collection '$($collection.Name)'" -ForegroundColor Green
            }
        }
        catch {
            Write-Error "Failed to set collection schedule: $_"
            throw
        }
        finally {
            if ($cimSession) {
                Remove-CimSession -CimSession $cimSession
                Write-Verbose "CIM session closed"
            }
        }
    }
}
function Set-CMASDeviceVariable {
    <#
        .SYNOPSIS
            Modifies an existing device variable for a Configuration Manager device via the Admin Service.

        .DESCRIPTION
            This function modifies the properties of an existing custom variable that is assigned to a specific device
            in Configuration Manager using the Admin Service API. You can change the variable's value and/or its
            masked (sensitive) status.

            Device variables are name-value pairs that can be used in task sequences, scripts, and other
            Configuration Manager operations. The function supports identifying the target device by either
            device name or ResourceID.

        .PARAMETER DeviceName
            The name of the device containing the variable to modify. Either DeviceName or ResourceID must be specified.

        .PARAMETER ResourceID
            The ResourceID of the device containing the variable to modify. Either DeviceName or ResourceID must be specified.

        .PARAMETER VariableName
            The name of the variable to modify. The variable must already exist on the device.

        .PARAMETER VariableValue
            The new value to assign to the variable. Can be any string value.

        .PARAMETER IsMasked
            If specified, marks the variable as masked (sensitive). Masked variables have their values hidden
            in the Configuration Manager console for security purposes.

        .PARAMETER IsNotMasked
            If specified, marks the variable as not masked (visible). This allows you to unmask a previously masked variable.

        .PARAMETER PassThru
            If specified, returns the modified variable object.

        .EXAMPLE
            Set-CMASDeviceVariable -DeviceName "WORKSTATION01" -VariableName "OSDComputerName" -VariableValue "WS01-NEW"
            Updates the value of the device variable "OSDComputerName" to "WS01-NEW" for device WORKSTATION01.

        .EXAMPLE
            Set-CMASDeviceVariable -ResourceID 16777220 -VariableName "AppPath" -VariableValue "D:\Apps\MyApp" -PassThru
            Updates the device variable by ResourceID and returns the modified variable object.

        .EXAMPLE
            Set-CMASDeviceVariable -DeviceName "SERVER01" -VariableName "DBPassword" -VariableValue "NewP@ssw0rd" -IsMasked
            Updates a device variable and marks it as masked (sensitive).

        .EXAMPLE
            Set-CMASDeviceVariable -DeviceName "WORKSTATION01" -VariableName "TestVar" -VariableValue "Public" -IsNotMasked
            Updates a variable and explicitly sets it as not masked (visible).

        .NOTES
            This function is part of the SCCM Admin Service module.
            Requires an active connection established via Connect-CMAS.

            The function uses the Admin Service REST API to interact with the SMS_MachineSettings WMI class.
            The specified variable must already exist on the device. To create new variables, use New-CMASDeviceVariable.

            Device variables are commonly used in:
            - Operating System Deployment (OSD) task sequences
            - Application deployment customization
            - Script execution with device-specific values
            - Configuration baselines

        .LINK
            Connect-CMAS
            Get-CMASDevice
            Get-CMASDeviceVariable
            New-CMASDeviceVariable
            Remove-CMASDeviceVariable
    #>
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium', DefaultParameterSetName='ByDeviceName')]
    param(
        [Parameter(Mandatory=$false, ParameterSetName='ByDeviceName', Position=0, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$DeviceName,

        [Parameter(Mandatory=$false, ParameterSetName='ByResourceID', Position=0, ValueFromPipelineByPropertyName=$true)]
        [long]$ResourceID,

        [Parameter(Mandatory=$true, Position=1, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [Alias('Name')]
        [string]$VariableName,

        [Parameter(Mandatory=$true, Position=2)]
        [AllowEmptyString()]
        [Alias('Value')]
        [string]$VariableValue,

        [Parameter(Mandatory=$false)]
        [switch]$IsMasked,

        [Parameter(Mandatory=$false)]
        [switch]$IsNotMasked,

        [Parameter(Mandatory=$false)]
        [switch]$PassThru
    )

    begin {
        # Validate connection
        if (-not $script:CMASConnection.SiteServer) {
            throw "No active connection to SCCM Admin Service. Run Connect-CMAS first."
        }

        # Validate that IsMasked and IsNotMasked are not both specified
        if ($IsMasked -and $IsNotMasked) {
            throw "Cannot specify both -IsMasked and -IsNotMasked. Choose one or neither."
        }
    }

    process {
        try {
            # Validate that either DeviceName or ResourceID is specified
            # This is in Process block to support pipeline input
            if (-not $DeviceName -and -not $ResourceID) {
                throw "Either DeviceName or ResourceID must be specified."
            }

            # Resolve device to ResourceID if needed
            $targetResourceID = $null
            $targetDeviceName = $null

            if ($ResourceID) {
                $targetResourceID = $ResourceID
                Write-Verbose "Using ResourceID: $targetResourceID"

                # Get device name for display purposes
                $device = Get-CMASDevice -ResourceID $targetResourceID
                if (-not $device) {
                    throw "Device with ResourceID '$targetResourceID' not found."
                }
                $targetDeviceName = $device.Name
            }
            elseif ($DeviceName) {
                Write-Verbose "Resolving DeviceName '$DeviceName' to ResourceID..."
                $device = Get-CMASDevice -Name $DeviceName
                if (-not $device) {
                    throw "Device with name '$DeviceName' not found."
                }
                if (@($device).Count -gt 1) {
                    throw "Multiple devices found with name '$DeviceName'. Use ResourceID instead."
                }
                $targetResourceID = $device.ResourceID
                $targetDeviceName = $device.Name
                Write-Verbose "Resolved device to ResourceID: $targetResourceID"
            }

            # Get current device settings
            Write-Verbose "Retrieving device settings for ResourceID '$targetResourceID'..."
            $settingsPath = "wmi/SMS_MachineSettings($targetResourceID)"

            $existingSettings = $null
            try {
                $response = Invoke-CMASApi -Path $settingsPath

                # Extract settings from response
                $existingSettings = if ($response.value) {
                    $response.value | Select-Object -First 1
                } else {
                    $response
                }
            }
            catch {
                # 404 means no settings exist for this device
                if ($_.Exception.Message -like "*404*" -or $_.Exception.Message -like "*Not Found*") {
                    throw "No device settings found for device '$targetDeviceName' (ResourceID: $targetResourceID). Use New-CMASDeviceVariable to create variables."
                }
                else {
                    throw
                }
            }

            # Check if device has any variables
            if (-not $existingSettings.MachineVariables) {
                throw "Device '$targetDeviceName' has no variables configured. Use New-CMASDeviceVariable to create variables."
            }

            # Find the variable to modify
            $variables = @($existingSettings.MachineVariables)
            $existingVariable = $variables | Where-Object { $_.Name -eq $VariableName }

            if (-not $existingVariable) {
                throw "Variable '$VariableName' not found on device '$targetDeviceName'. Use New-CMASDeviceVariable to create it."
            }

            # Determine the new masked state
            $newMaskedState = $existingVariable.IsMasked
            if ($IsMasked) {
                $newMaskedState = $true
            }
            elseif ($IsNotMasked) {
                $newMaskedState = $false
            }

            # Check if anything is actually changing
            if ($existingVariable.Value -eq $VariableValue -and $existingVariable.IsMasked -eq $newMaskedState) {
                Write-Verbose "Variable '$VariableName' already has the specified value and masked state. No changes needed."
                if ($PassThru) {
                    # Return the existing variable
                    $existingVariable | Add-Member -NotePropertyName 'ResourceID' -NotePropertyValue $targetResourceID -Force
                    $existingVariable | Add-Member -NotePropertyName 'DeviceName' -NotePropertyValue $targetDeviceName -Force
                    return ($existingVariable | Select-Object -Property * -ExcludeProperty __*, @odata*)
                }
                return
            }

            $description = "device variable '$VariableName' for device '$targetDeviceName' (ResourceID: $targetResourceID)"

            if ($PSCmdlet.ShouldProcess($description, "Modify device variable")) {
                Write-Verbose "Modifying device variable: $VariableName"
                Write-Verbose "Old Value: $(if($existingVariable.IsMasked){'[MASKED]'}else{$existingVariable.Value})"
                Write-Verbose "New Value: $(if($newMaskedState){'[MASKED]'}else{$VariableValue})"
                Write-Verbose "Old IsMasked: $($existingVariable.IsMasked)"
                Write-Verbose "New IsMasked: $newMaskedState"

                # Update the variable in the array
                $updatedVariables = @()
                foreach ($var in $variables) {
                    if ($var.Name -eq $VariableName) {
                        # Update this variable
                        $updatedVariables += @{
                            Name = $VariableName
                            Value = $VariableValue
                            IsMasked = $newMaskedState
                        }
                    }
                    else {
                        # Keep existing variable as-is
                        $updatedVariables += @{
                            Name = $var.Name
                            Value = $var.Value
                            IsMasked = $var.IsMasked
                        }
                    }
                }

                # Prepare the body for PUT
                $updateBody = @{
                    ResourceID = $targetResourceID
                    MachineVariables = $updatedVariables
                }

                # Copy required properties from existing settings
                if ($existingSettings.LocaleID) {
                    $updateBody.LocaleID = $existingSettings.LocaleID
                }
                if ($existingSettings.SourceSite) {
                    $updateBody.SourceSite = $existingSettings.SourceSite
                }

                # Use PUT to update
                $updatePath = "wmi/SMS_MachineSettings($targetResourceID)"
                $result = Invoke-CMASApi -Path $updatePath -Method PUT -Body $updateBody

                if ($result) {
                    Write-Verbose "Device variable modified successfully"

                    if ($PassThru) {
                        # Retrieve the settings again to get the modified variable
                        Write-Verbose "PassThru requested - retrieving updated settings..."
                        Start-Sleep -Seconds 2

                        $updatedResponse = Invoke-CMASApi -Path $settingsPath

                        # Extract settings from response
                        $updatedSettings = if ($updatedResponse.value) {
                            $updatedResponse.value | Select-Object -First 1
                        } else {
                            $updatedResponse
                        }

                        if ($updatedSettings -and $updatedSettings.MachineVariables) {
                            # Find the modified variable
                            $modifiedVariable = $updatedSettings.MachineVariables | Where-Object { $_.Name -eq $VariableName }

                            if ($modifiedVariable) {
                                # Add device information to output
                                $modifiedVariable | Add-Member -NotePropertyName 'ResourceID' -NotePropertyValue $targetResourceID -Force
                                $modifiedVariable | Add-Member -NotePropertyName 'DeviceName' -NotePropertyValue $targetDeviceName -Force

                                # Format output - exclude WMI and OData metadata
                                $output = $modifiedVariable | Select-Object -Property * -ExcludeProperty __*, @odata*

                                Write-Verbose "Successfully retrieved modified variable"
                                return $output
                            } else {
                                Write-Warning "Variable was modified but could not be retrieved immediately."
                            }
                        } else {
                            Write-Warning "Variable was modified but could not be retrieved immediately."
                        }
                    } else {
                        Write-Host "Device variable '$VariableName' modified successfully for device '$targetDeviceName'." -ForegroundColor Green
                    }
                } else {
                    Write-Error "Failed to modify device variable. No result returned from API."
                }
            }
        }
        catch {
            throw "Failed to modify device variable '$VariableName' for device '$targetDeviceName': $_"
        }
    }
}
#endregion

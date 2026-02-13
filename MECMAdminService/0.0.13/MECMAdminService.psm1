<#
    Generated at 02/13/2026 13:56:30 by Josua Burkard
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
        [ValidateSet("GET","POST","PUT","DELETE")]
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

        # format results as needed, for example:
        $collections = $res.value | Select-Object Name, CollectionID, CollectionType

        return $collections
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
#endregion

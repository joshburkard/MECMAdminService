<#
    Generated at 02/11/2026 11:02:02 by Josua Burkard
#>
#region namespace SCCMAdminService
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
function Get-CMASDevice {
    <#
        .SYNOPSIS
            Retrieves information about devices from the SCCM Admin Service.

        .DESCRIPTION
            This function connects to the SCCM Admin Service API to fetch details about devices.
            You can filter the results by device name or device ID.

        .PARAMETER Name
            The name of the device to retrieve information for. If not specified, all devices will be returned.

        .PARAMETER DeviceID
            The unique identifier of the device to retrieve information for. If not specified, all devices will be returned.

        .EXAMPLE
            Get-CMASDevice -Name "Device001"

        .EXAMPLE
            Get-CMASDevice -DeviceID "12345"

        .NOTES
            This function is part of the SCCM Admin Service module.

    #>
    [CmdletBinding()]
    param(
        [string]$Name,
        [int]$ResourceID
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
            2. Use Register-CMASScriptMetadata to cache metadata, then use -UseCache
            3. Enable CIM/WinRM to the Site Server (automatic fallback)
            4. For scripts WITHOUT parameters, no workaround needed

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

        .PARAMETER ScriptHash
            Optional. The SHA256 hash of the script. Required for scripts with parameters when Admin
            Service doesn't return lazy properties. Get from CM console or PowerShell 5.1:
            (Get-CMScript -ScriptName "Name").ScriptHash

        .PARAMETER ScriptVersion
            Optional. The version of the script. Required for scripts with parameters when Admin
            Service doesn't return lazy properties.

        .PARAMETER ScriptType
            Optional. The script type (0 = PowerShell). Default is 0.

        .PARAMETER ParamsDefinitionBase64
            Optional. Base64-encoded ParamsDefinition XML for scripts with parameters.

        .PARAMETER UseCache
            Use cached script metadata from Register-CMASScriptMetadata.

        .EXAMPLE
            # Simple script without parameters
            Invoke-CMASScript -ScriptName "Get Info" -ResourceId 16777219

        .EXAMPLE
            # Script with parameters - provide metadata manually
            $params = @{ Key = 'HKLM:\SOFTWARE\Test'; Name = 'Value' }
            Invoke-CMASScript -ScriptName "Set Registry" -ResourceId 16777219 -InputParameters $params `
                -ScriptHash "A57C9F8FF6B66..." -ScriptVersion "1"

        .EXAMPLE
            # Register metadata once, then use cache
            Register-CMASScriptMetadata -ScriptGuid "A7CCF80E-..." -ScriptHash "A57C9F8..." -ScriptVersion "1"
            Invoke-CMASScript -ScriptName "Set Registry" -ResourceId 16777219 -InputParameters @{...} -UseCache

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
        [string]$ScriptName,

        [Parameter(Mandatory=$false)]
        [string]$ScriptID,

        [Parameter(Mandatory=$false)]
        [string]$CollectionId,

        [Parameter(Mandatory=$false)]
        [int[]]$ResourceId,

        [Parameter(Mandatory=$false)]
        [hashtable]$InputParameters,

        # Optional: Provide script metadata manually when Admin Service doesn't return lazy properties
        # These can be obtained from the CM console or by running Get-CMScript in PowerShell 5.1
        [Parameter(Mandatory=$false)]
        [string]$ScriptHash,

        [Parameter(Mandatory=$false)]
        [string]$ScriptVersion,

        [Parameter(Mandatory=$false)]
        [int]$ScriptType = 0,  # 0 = PowerShell

        [Parameter(Mandatory=$false)]
        [string]$ParamsDefinitionBase64,  # Base64-encoded ParamsDefinition XML

        # Use cached script metadata from module-level cache
        [Parameter(Mandatory=$false)]
        [switch]$UseCache
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
                $scriptFull = Invoke-CMASApi -Path "wmi/SMS_Scripts('$($scriptInfo.ScriptGuid)')?`$select=$lazyProperties"
                $script = if ($scriptFull.ScriptGuid) { $scriptFull } else { $scriptFull.value }
            }
            catch {
                Write-Verbose "Fetch with `$select failed, trying without: $_"
                $scriptFull = Invoke-CMASApi -Path "wmi/SMS_Scripts('$($scriptInfo.ScriptGuid)')"
                $script = if ($scriptFull.ScriptGuid) { $scriptFull } else { $scriptFull.value }
            }

            # If lazy properties are still empty, try fetching via filter which sometimes returns more properties
            if (-not $script.ScriptHash -or -not $script.ScriptVersion) {
                Write-Verbose "Lazy properties not returned via key lookup, trying filter query..."
                $scriptByFilter = Invoke-CMASApi -Path "wmi/SMS_Scripts?`$filter=ScriptGuid eq '$($scriptInfo.ScriptGuid)'"
                if ($scriptByFilter.value.Count -gt 0 -and $scriptByFilter.value[0].ScriptHash) {
                    $script = $scriptByFilter.value[0]
                    Write-Verbose "Got lazy properties via filter query"
                }
            }

            # If still missing, check for manually provided metadata or cache
            if (-not $script.ScriptHash) {
                Write-Verbose "Admin Service didn't return lazy properties. Checking alternatives..."

                # Priority 1: Use parameters provided by user
                if ($ScriptHash -and $ScriptVersion) {
                    Write-Verbose "Using manually provided script metadata"
                    $script = [PSCustomObject]@{
                        ScriptGuid       = $scriptInfo.ScriptGuid
                        ScriptName       = $scriptInfo.ScriptName
                        ScriptVersion    = $ScriptVersion
                        ScriptType       = $ScriptType
                        ScriptHash       = $ScriptHash
                        ApprovalState    = $scriptInfo.ApprovalState
                        ParamsDefinition = $ParamsDefinitionBase64
                    }
                }
                # Priority 2: Check module-level cache
                elseif ($UseCache -and $script:CMASScriptCache -and $script:CMASScriptCache[$scriptInfo.ScriptGuid]) {
                    Write-Verbose "Using cached script metadata"
                    $cached = $script:CMASScriptCache[$scriptInfo.ScriptGuid]
                    $script = [PSCustomObject]@{
                        ScriptGuid       = $scriptInfo.ScriptGuid
                        ScriptName       = $scriptInfo.ScriptName
                        ScriptVersion    = $cached.ScriptVersion
                        ScriptType       = $cached.ScriptType
                        ScriptHash       = $cached.ScriptHash
                        ApprovalState    = $scriptInfo.ApprovalState
                        ParamsDefinition = $cached.ParamsDefinition
                    }
                }
                # Priority 3: Try CIM fallback (if available)
                else {
                    $cimHelperPath = Join-Path (Split-Path $PSScriptRoot -Parent) "Private\Get-CMASScriptDetailViaCIM.ps1"
                    if (Test-Path $cimHelperPath) {
                        . $cimHelperPath
                    }

                    if (Get-Command Get-CMASScriptDetailViaCIM -ErrorAction SilentlyContinue) {
                        try {
                            Write-Verbose "Trying CIM fallback to fetch lazy properties..."
                            $cimParams = @{
                                SiteServer = $script:CMASConnection.SiteServer
                                SiteCode   = $script:CMASConnection.SiteCode
                                ScriptGuid = $scriptInfo.ScriptGuid
                            }
                            if ($script:CMASConnection.Credential) {
                                $cimParams.Credential = $script:CMASConnection.Credential
                            }

                            $script = Get-CMASScriptDetailViaCIM @cimParams
                            Write-Verbose "Got lazy properties via CIM"

                            # Cache for future use
                            if (-not $script:CMASScriptCache) { $script:CMASScriptCache = @{} }
                            $script:CMASScriptCache[$script.ScriptGuid] = @{
                                ScriptVersion    = $script.ScriptVersion
                                ScriptType       = $script.ScriptType
                                ScriptHash       = $script.ScriptHash
                                ParamsDefinition = $script.ParamsDefinition
                            }
                        }
                        catch {
                            Write-Verbose "CIM fallback failed: $_"
                        }
                    }
                    else {
                        Write-Warning "Admin Service doesn't return lazy properties and no manual metadata provided."
                        Write-Warning "Provide -ScriptHash, -ScriptVersion parameters or use Register-CMASScriptMetadata to cache."
                    }
                }
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

        # If lazy properties (ScriptHash) are missing, we can't use InitiateClientOperationEx with parameters
        # The simple Device.RunScript endpoint will be used instead for parameterless calls
        if (-not $script.ScriptHash -and $userProvidedParams) {
            throw @"
Cannot execute script with parameters via Admin Service.

The Admin Service did not return the required ScriptHash property needed to build
the script execution XML. This can happen if:
1. The script doesn't exist or isn't approved
2. The Admin Service version doesn't support returning ScriptHash via filter query

Workarounds:
1. Use a script without parameters (the simple Device.RunScript endpoint works)
2. Use the ConfigMgr console to run the script manually
"@
        }

        # For simple execution without parameters, use the v1.0/Device/AdminService.RunScript endpoint
        # This endpoint works but doesn't support parameters
        $canUseSimpleEndpoint = $ResourceId -and $ResourceId.Count -eq 1 -and -not $userProvidedParams

        if ($canUseSimpleEndpoint -and (-not $hasParameters -or -not $script.ScriptHash)) {
            Write-Verbose "Executing script on device $($ResourceId[0]) using simple Device.RunScript endpoint (no parameters)"

            $Body = @{
                ScriptGuid = $ScriptGuid
            }

            try {
                $result = Invoke-CMASApi -Path "v1.0/Device($($ResourceId[0]))/AdminService.RunScript" -Method POST -Body $body

                $ResultObj = [PSCustomObject]@{
                    OperationId = if ($result.value) { $result.value } else { $result }
                    ResourceId  = $ResourceId[0]
                    ScriptGuid  = $ScriptGuid
                    ScriptName  = $script.ScriptName
                    Method      = "Device.RunScript"
                }

                Write-Verbose "Script execution initiated. Operation ID: $($ResultObj.OperationId)"
                return $ResultObj
            }
            catch {
                Write-Warning "Simple RunScript endpoint failed, falling back to InitiateClientOperationEx: $_"
                # Fall through to use InitiateClientOperationEx
            }
        }

        # Verify required properties for InitiateClientOperationEx are present
        if (-not $script.ScriptHash) {
            throw "Script property 'ScriptHash' is empty. Cannot use InitiateClientOperationEx without lazy properties. Use the simple Device.RunScript endpoint for scripts without parameters."
        }

        # For scripts with parameters or collection targeting, use InitiateClientOperationEx
        Write-Verbose "Using InitiateClientOperationEx for script execution with parameters"

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

        if ((-not $hasParameters -and -not $userProvidedParams) -or ($InputParameters.Count -eq 0)) {
            # No parameters needed
            $ParametersXML = "<ScriptParameters></ScriptParameters>"
            $ParametersHash = ""
        }
        elseif ($hasParameters) {
            # Use ParamsDefinition to build parameters (validates types/required fields)
            $InnerParametersXML = ''
            $paramValues = @()

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

                # Use simplified format that works with Admin Service
                $InnerParametersXML = "$InnerParametersXML<ScriptParameter ParameterGroupGuid='' ParameterGroupName='PG0' ParameterName='$ParamName' ParameterDataType='System.String' ParameterVisibility='0' ParameterType='0' ParameterValue='$EscapedValue'/>"

                # Collect values for hash computation
                $paramValues += $Value
            }
            $ParametersXML = "<ScriptParameters>$InnerParametersXML</ScriptParameters>"

            # Compute ParameterGroupHash from concatenated parameter values (UTF8)
            $hashInput = $paramValues -join ''
            $SHA256 = [System.Security.Cryptography.SHA256]::Create()
            $Bytes = $SHA256.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($hashInput))
            $ParametersHash = [BitConverter]::ToString($Bytes).Replace('-', '')
        }
        else {
            # User provided parameters but ParamsDefinition is not available
            # Build parameters directly from InputParameters hashtable
            Write-Verbose "Building parameters directly from InputParameters (no ParamsDefinition available)"
            $InnerParametersXML = ''
            $paramValues = @()

            foreach ($key in $InputParameters.Keys) {
                $Value = $InputParameters[$key]
                $EscapedValue = [System.Security.SecurityElement]::Escape($Value)

                $InnerParametersXML = "$InnerParametersXML<ScriptParameter ParameterGroupGuid='' ParameterGroupName='PG0' ParameterName='$key' ParameterDataType='System.String' ParameterVisibility='0' ParameterType='0' ParameterValue='$EscapedValue'/>"
                $paramValues += $Value
            }
            $ParametersXML = "<ScriptParameters>$InnerParametersXML</ScriptParameters>"

            # Compute ParameterGroupHash from concatenated parameter values (UTF8)
            $hashInput = $paramValues -join ''
            $SHA256 = [System.Security.Cryptography.SHA256]::Create()
            $Bytes = $SHA256.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($hashInput))
            $ParametersHash = [BitConverter]::ToString($Bytes).Replace('-', '')
        }

        # Build RunScript XML
        $RunScriptXMLDefinition = "<ScriptContent ScriptGuid='{0}'><ScriptVersion>{1}</ScriptVersion><ScriptType>{2}</ScriptType><ScriptHash ScriptHashAlg='SHA256'>{3}</ScriptHash>{4}<ParameterGroupHash ParameterHashAlg='SHA256'>{5}</ParameterGroupHash></ScriptContent>"
        $RunScriptXML = $RunScriptXMLDefinition -f $script.ScriptGuid,$script.ScriptVersion,$script.ScriptType,$script.ScriptHash,$ParametersXML,$ParametersHash

        Write-Verbose "RunScript XML: $RunScriptXML"

        # Build target arrays - when targeting specific resources, TargetCollectionID can be empty
        if ($ResourceId -and $ResourceId.Count -gt 0) {
            $TargetResourceIDs = [System.Collections.ArrayList]@()
            foreach ($id in $ResourceId) {
                [void]$TargetResourceIDs.Add([int]$id)
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

            <#
            # Approach 2: Try CreateScriptsOperation (CM 2006+)
            try {
                Write-Verbose "Trying v1.0/Scripts.CreateScriptsOperation endpoint (CM 2006+)..."

                # Build script parameters array for the newer endpoint
                $scriptParams = @()
                if ($hasParameters -and $InputParameters -and $InputParameters.Count -gt 0) {
                    foreach ($ChildNode in $Parameters.ScriptParameters.ChildNodes) {
                        $ParamName = $ChildNode.Name
                        $Value = if ($ChildNode.IsHidden -eq 'true') {
                            $ChildNode.DefaultValue
                        } elseif ($ParamName -in $InputParameters.Keys) {
                            $InputParameters."$ParamName"
                        } else {
                            $ChildNode.DefaultValue
                        }
                        $scriptParams += @{
                            Name  = $ParamName
                            Value = [string]$Value
                        }
                    }
                }

                $scriptsOperationBody = @{
                    ScriptGuid = $ScriptGuid
                }

                if ($TargetCollectionID -and $TargetCollectionID -ne "") {
                    $scriptsOperationBody.CollectionId = $TargetCollectionID
                }
                if ($TargetResourceIDs -and $TargetResourceIDs.Count -gt 0) {
                    $scriptsOperationBody.DeviceIds = @($TargetResourceIDs)
                }
                if ($scriptParams.Count -gt 0) {
                    $scriptsOperationBody.ScriptParameters = $scriptParams
                }

                Write-Verbose "CreateScriptsOperation body: $($scriptsOperationBody | ConvertTo-Json -Depth 10 -Compress)"
                $result = Invoke-CMASApi -Path "v1.0/Scripts.CreateScriptsOperation" -Method POST -Body $scriptsOperationBody

                Write-Verbose "Script execution initiated via CreateScriptsOperation. Result: $($result | ConvertTo-Json -Depth 5 -Compress)"

                $operationId = if ($result.OperationId) { $result.OperationId } elseif ($result.value) { $result.value } else { $result }

                return [PSCustomObject]@{
                    OperationId        = $operationId
                    ScriptGuid         = $ScriptGuid
                    ScriptName         = $script.ScriptName
                    TargetResourceIDs  = $TargetResourceIDs
                    TargetCollectionID = $TargetCollectionID
                }
            }
            catch {
                Write-Verbose "CreateScriptsOperation also failed: $_"

                # Approach 3: Try with different path format
                try {
                    Write-Verbose "Trying alternate method invocation format (SMS_ClientOperation/InitiateClientOperationEx)..."
                    $result = Invoke-CMASApi -Path "wmi/SMS_ClientOperation/InitiateClientOperationEx" -Method POST -Body $operationBody

                    $operationId = if ($result.ReturnValue) { $result.ReturnValue } elseif ($result.value) { $result.value } else { $result }

                    return [PSCustomObject]@{
                        OperationId        = $operationId
                        ScriptGuid         = $ScriptGuid
                        ScriptName         = $script.ScriptName
                        TargetResourceIDs  = $TargetResourceIDs
                        TargetCollectionID = $TargetCollectionID
                    }
                }
                catch {
                    Write-Verbose "All REST API approaches failed. Trying CIM fallback..."

                    # Approach 4: Use CIM as fallback (works in PowerShell 7)
                    try {
                        Write-Verbose "Attempting script execution via CIM remoting..."

                        # Dot-source the CIM helper if needed
                        $cimHelperPath = Join-Path (Split-Path $PSScriptRoot -Parent) "Private\Invoke-CMASScriptViaCIM.ps1"
                        if (Test-Path $cimHelperPath) {
                            . $cimHelperPath
                        }

                        if (Get-Command Invoke-CMASScriptViaCIM -ErrorAction SilentlyContinue) {
                            $cimParams = @{
                                SiteServer        = $script:CMASConnection.SiteServer
                                SiteCode          = $script:CMASConnection.SiteCode
                                ScriptGuid        = $ScriptGuid
                                InputParameters   = $InputParameters
                                TargetCollectionID = $TargetCollectionID
                                TargetResourceIDs = @($TargetResourceIDs)
                            }
                            if ($script:CMASConnection.Credential) {
                                $cimParams.Credential = $script:CMASConnection.Credential
                            }

                            return Invoke-CMASScriptViaCIM @cimParams
                        }
                        else {
                            Write-Verbose "CIM helper function not available"
                            throw "CIM fallback not available"
                        }
                    }
                    catch {
                        Write-Verbose "CIM fallback also failed: $_"

                        # Provide detailed troubleshooting info
                        Write-Error "Script execution with parameters failed. Tried:
  1. wmi/SMS_ClientOperation.InitiateClientOperationEx - HTTP $statusCode
  2. v1.0/Scripts.CreateScriptsOperation - Not available (404)
  3. wmi/SMS_ClientOperation/InitiateClientOperationEx - Failed
  4. CIM remoting fallback - Failed

  Original error: $errorMessage

  The Admin Service does not return lazy properties (ScriptHash, ParamsDefinition)
  required for executing scripts with parameters.

  Workarounds:
  - For scripts WITHOUT parameters: Remove -InputParameters (Device.RunScript works)
  - Enable CIM/WinRM remoting to the Site Server for CIM fallback
  - Use PowerShell 5.1 with the WMI-based Invoke-SCCMScript function"
                        throw $lastError
                    }
                }
            }
            #>
        }

    }
    catch {
        Write-Error "Failed to execute script: $_"
        throw $_
    }
}
function Register-CMASScriptMetadata {
    <#
        .SYNOPSIS
            Registers script metadata for use with Invoke-CMASScript.

        .DESCRIPTION
            The Admin Service doesn't return lazy properties (ScriptHash, ScriptVersion,
            ParamsDefinition) for SMS_Scripts. This function allows you to manually register
            script metadata obtained from PowerShell 5.1 or the CM console.

            Once registered, use -UseCache with Invoke-CMASScript to use the cached metadata.

        .PARAMETER ScriptGuid
            The GUID of the script.

        .PARAMETER ScriptName
            Optional. The name of the script (for display purposes).

        .PARAMETER ScriptHash
            The SHA256 hash of the script content. Required.

        .PARAMETER ScriptVersion
            The version number of the script. Required.

        .PARAMETER ScriptType
            The script type (0 = PowerShell). Default is 0.

        .PARAMETER ParamsDefinition
            Optional. Base64-encoded ParamsDefinition XML for scripts with parameters.

        .EXAMPLE
            # Register a script without parameters
            Register-CMASScriptMetadata -ScriptGuid "A7CCF80E-F75F-47B9-AFD6-8880DA660F4D" `
                -ScriptHash "A57C9F8FF6B66FE4287604407E428715D60E0F0A646381B83E8E55533869714E" `
                -ScriptVersion "1"

        .EXAMPLE
            # Get metadata from PowerShell 5.1 and register
            # In PS 5.1:
            # $s = Get-CMScript -ScriptName "Set Registry Value" -Fast
            # $s.ScriptGuid, $s.ScriptHash, $s.ScriptVersion, $s.ParamsDefinition
            #
            # Then in PS 7:
            Register-CMASScriptMetadata -ScriptGuid "A7CCF80E-F75F-47B9-AFD6-8880DA660F4D" `
                -ScriptHash "A57C9F8FF6B66FE4287604407E428715D60E0F0A646381B83E8E55533869714E" `
                -ScriptVersion "1" `
                -ParamsDefinition "PHNjcmlwdFBhcmFtZXRlcnM+..."

        .EXAMPLE
            # Then use with Invoke-CMASScript:
            Invoke-CMASScript -ScriptName "Set Registry Value" -ResourceId 16777219 -InputParameters @{...} -UseCache

        .NOTES
            This is a workaround for the Admin Service limitation of not returning lazy properties.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ScriptGuid,

        [Parameter()]
        [string]$ScriptName,

        [Parameter(Mandatory)]
        [string]$ScriptHash,

        [Parameter(Mandatory)]
        [string]$ScriptVersion,

        [Parameter()]
        [int]$ScriptType = 0,

        [Parameter()]
        [string]$ParamsDefinition
    )

    # Initialize cache if needed
    if (-not $script:CMASScriptCache) {
        $script:CMASScriptCache = @{}
    }

    $script:CMASScriptCache[$ScriptGuid] = @{
        ScriptName       = $ScriptName
        ScriptHash       = $ScriptHash
        ScriptVersion    = $ScriptVersion
        ScriptType       = $ScriptType
        ParamsDefinition = $ParamsDefinition
    }

    Write-Verbose "Registered metadata for script '$ScriptName' ($ScriptGuid)"

    return [PSCustomObject]@{
        ScriptGuid       = $ScriptGuid
        ScriptName       = $ScriptName
        ScriptHash       = $ScriptHash
        ScriptVersion    = $ScriptVersion
        ScriptType       = $ScriptType
        HasParamsDefinition = [bool]$ParamsDefinition
    }
}

function Get-CMASScriptMetadataCache {
    <#
        .SYNOPSIS
            Gets all cached script metadata.

        .DESCRIPTION
            Returns all script metadata that has been registered via Register-CMASScriptMetadata
            or automatically cached via CIM lookups.

        .EXAMPLE
            Get-CMASScriptMetadataCache
    #>
    [CmdletBinding()]
    param()

    if (-not $script:CMASScriptCache) {
        Write-Verbose "No script metadata cached"
        return @()
    }

    $script:CMASScriptCache.GetEnumerator() | ForEach-Object {
        [PSCustomObject]@{
            ScriptGuid          = $_.Key
            ScriptName          = $_.Value.ScriptName
            ScriptHash          = $_.Value.ScriptHash
            ScriptVersion       = $_.Value.ScriptVersion
            ScriptType          = $_.Value.ScriptType
            HasParamsDefinition = [bool]$_.Value.ParamsDefinition
        }
    }
}

function Clear-CMASScriptMetadataCache {
    <#
        .SYNOPSIS
            Clears the script metadata cache.

        .EXAMPLE
            Clear-CMASScriptMetadataCache
    #>
    [CmdletBinding()]
    param()

    $script:CMASScriptCache = @{}
    Write-Verbose "Script metadata cache cleared"
}

function Export-CMASScriptMetadataCache {
    <#
        .SYNOPSIS
            Exports the script metadata cache to a JSON file.

        .PARAMETER Path
            The path to save the JSON file.

        .EXAMPLE
            Export-CMASScriptMetadataCache -Path "C:\temp\script-cache.json"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not $script:CMASScriptCache) {
        Write-Warning "No script metadata cached"
        return
    }

    $script:CMASScriptCache | ConvertTo-Json -Depth 5 | Set-Content -Path $Path
    Write-Verbose "Exported cache to $Path"
}

function Import-CMASScriptMetadataCache {
    <#
        .SYNOPSIS
            Imports script metadata cache from a JSON file.

        .PARAMETER Path
            The path to the JSON file.

        .PARAMETER Merge
            If specified, merges with existing cache instead of replacing.

        .EXAMPLE
            Import-CMASScriptMetadataCache -Path "C:\temp\script-cache.json"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [switch]$Merge
    )

    if (-not (Test-Path $Path)) {
        throw "File not found: $Path"
    }

    $imported = Get-Content -Path $Path -Raw | ConvertFrom-Json -AsHashtable

    if (-not $Merge -or -not $script:CMASScriptCache) {
        $script:CMASScriptCache = $imported
    }
    else {
        foreach ($key in $imported.Keys) {
            $script:CMASScriptCache[$key] = $imported[$key]
        }
    }

    Write-Verbose "Imported $($imported.Count) script(s) from cache file"
}

# Module-level cache variable
if (-not (Get-Variable -Name CMASScriptCache -Scope Script -ErrorAction SilentlyContinue)) {
    $script:CMASScriptCache = @{}
}
#endregion

<#
    Generated at 02/11/2026 19:35:10 by Josua Burkard
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

        [Parameter(Mandatory=$false, ParameterSetName='CollectionName')]
        [Parameter(Mandatory=$false, ParameterSetName='CollectionName_ScriptName')]
        [string]$CollectionName,

        [Parameter(Mandatory=$false, ParameterSetName='CollectionID')]
        [Parameter(Mandatory=$false, ParameterSetName='CollectionID_ScriptName')]
        [string]$CollectionID,

        [Parameter(Mandatory=$true, ParameterSetName='ScriptName')]
        [Parameter(Mandatory=$false, ParameterSetName='CollectionName_ScriptName')]
        [Parameter(Mandatory=$false, ParameterSetName='CollectionID_ScriptName')]
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
#endregion

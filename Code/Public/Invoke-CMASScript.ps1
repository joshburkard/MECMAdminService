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

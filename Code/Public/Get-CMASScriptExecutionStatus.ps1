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

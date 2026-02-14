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

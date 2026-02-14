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

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

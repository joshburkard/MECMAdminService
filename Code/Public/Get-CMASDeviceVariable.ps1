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

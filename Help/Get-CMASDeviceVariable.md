# Get-CMASDeviceVariable

## SYNOPSIS
Gets device variables for a Configuration Manager device via the Admin Service.

## SYNTAX

### ByDeviceName (Default)

```powershell
Get-CMASDeviceVariable [-DeviceName] <String> [-VariableName <String>] [<CommonParameters>]
```

### ByResourceID

```powershell
Get-CMASDeviceVariable [-ResourceID] <Int64> [-VariableName <String>] [<CommonParameters>]
```

## DESCRIPTION

This function retrieves custom variables that are assigned to a specific device in Configuration Manager using the Admin Service API. Device variables are name-value pairs that can be used in task sequences, scripts, and other Configuration Manager operations.

The function supports identifying the target device by either device name or ResourceID. You can optionally filter the results to specific variable names using wildcard patterns.

## PARAMETERS

### -DeviceName

The name of the device to retrieve variables from. Either DeviceName or ResourceID must be specified.

```yaml
Type: String
Parameter Sets: ByDeviceName
Aliases:

Required: False
Position: 0
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ResourceID

The ResourceID of the device to retrieve variables from. Either DeviceName or ResourceID must be specified.

```yaml
Type: Int64
Parameter Sets: ByResourceID
Aliases:

Required: False
Position: 0
Default value: 0
Accept pipeline input: False
Accept wildcard characters: False
```

### -VariableName
Optional. The name of a specific variable to retrieve. Supports wildcard patterns (*). If not specified, all variables for the device are returned.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: True
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### None
You cannot pipe objects to this function.

## OUTPUTS

### System.Management.Automation.PSObject
Returns custom objects with the following properties:
- **Name**: The variable name
- **Value**: The variable value
- **IsMasked**: Boolean indicating if the variable is masked (sensitive)
- **DeviceName**: The name of the device
- **ResourceID**: The ResourceID of the device

Returns nothing if the device has no variables or no variables match the filter criteria.

## NOTES

**Module**: MECMAdminService
**Requires**: An active connection to the SCCM Admin Service (Connect-CMAS)

The function queries the SMS_MachineSettings WMI class via the Admin Service REST API. Returns an empty result if the device has no variables configured.

Device variables are commonly used in:
- Operating System Deployment (OSD) task sequences
- Application deployment customization
- Script execution with device-specific values
- Configuration baselines

## EXAMPLES

### Example 1: Get all variables for a device by name
```powershell
Get-CMASDeviceVariable -DeviceName "WORKSTATION01"
```

Retrieves all device variables for device WORKSTATION01.

### Example 2: Get all variables for a device by ResourceID
```powershell
Get-CMASDeviceVariable -ResourceID 16777220
```

Retrieves all device variables for the device with ResourceID 16777220.

### Example 3: Get variables matching a pattern
```powershell
Get-CMASDeviceVariable -DeviceName "WORKSTATION01" -VariableName "OSD*"
```

Retrieves all device variables starting with "OSD" for device WORKSTATION01. This is useful for finding all OSD-related variables.

### Example 4: Get a specific variable
```powershell
Get-CMASDeviceVariable -DeviceName "SERVER01" -VariableName "AppPath"
```

Retrieves the specific device variable named "AppPath" for device SERVER01.

### Example 5: Get variables and display in a table
```powershell
Get-CMASDeviceVariable -DeviceName "WORKSTATION01" | Format-Table Name, Value, IsMasked -AutoSize
```

Retrieves all variables for WORKSTATION01 and displays them in a formatted table.

### Example 6: Get variables for multiple devices
```powershell
$devices = "WORKSTATION01", "WORKSTATION02", "WORKSTATION03"
$devices | ForEach-Object {
    [PSCustomObject]@{
        Device = $_
        Variables = @(Get-CMASDeviceVariable -DeviceName $_)
        Count = @(Get-CMASDeviceVariable -DeviceName $_).Count
    }
}
```

Retrieves variables for multiple devices and creates a summary showing the device name and variable count.

### Example 7: Check if a device has any variables
```powershell
$variables = Get-CMASDeviceVariable -DeviceName "WORKSTATION01"
if ($variables) {
    Write-Host "Device has $(@($variables).Count) variable(s)" -ForegroundColor Green
} else {
    Write-Host "Device has no variables configured" -ForegroundColor Yellow
}
```

Checks if a device has any variables configured and displays an appropriate message.

### Example 8: Export device variables to CSV
```powershell
Get-CMASDeviceVariable -DeviceName "WORKSTATION01" |
    Select-Object DeviceName, Name, Value, IsMasked |
    Export-Csv -Path "C:\Temp\DeviceVariables.csv" -NoTypeInformation
```

Retrieves all variables for a device and exports them to a CSV file for documentation or reporting purposes.

### Example 9: Get all unmasked variables
```powershell
Get-CMASDeviceVariable -DeviceName "WORKSTATION01" |
    Where-Object { -not $_.IsMasked }
```

Retrieves only non-masked (non-sensitive) variables for a device. Use this to avoid displaying sensitive information.

### Example 10: Get masked (sensitive) variables
```powershell
Get-CMASDeviceVariable -DeviceName "SERVER01" |
    Where-Object { $_.IsMasked }
```

Retrieves only masked (sensitive) variables. Note that even masked variables will show their values through the API (they're hashed in SCCM console).

## RELATED LINKS

[Connect-CMAS](Connect-CMAS.md)
[Get-CMASDevice](Get-CMASDevice.md)
[New-CMASDeviceVariable](New-CMASDeviceVariable.md)

# Remove-CMASDeviceVariable

## SYNOPSIS
Removes device variables from a Configuration Manager device via the Admin Service.

## SYNTAX

### ByDeviceName
```powershell
Remove-CMASDeviceVariable -DeviceName <String> -VariableName <String> [-Force] [-WhatIf] [-Confirm]
 [<CommonParameters>]
```

### ByResourceID
```powershell
Remove-CMASDeviceVariable -ResourceID <Int64> -VariableName <String> [-Force] [-WhatIf] [-Confirm]
 [<CommonParameters>]
```

## DESCRIPTION
This function removes custom variables that are assigned to a specific device in Configuration Manager using the Admin Service API. Device variables can be removed by exact name or using wildcard patterns to remove multiple variables at once.

The function supports identifying the target device by either device name or ResourceID. It also supports pipeline input from Get-CMASDevice or Get-CMASDeviceVariable for streamlined workflows.

When removing variables, the entire SMS_MachineSettings object is updated. If all variables are removed, an empty MachineVariables array is maintained to preserve the settings object.

The function includes built-in confirmation prompts (ConfirmImpact='High') to prevent accidental deletion of variables. Use the `-Force` parameter to bypass confirmation prompts.

## PARAMETERS

### -DeviceName
The name of the device to remove variables from. Either DeviceName or ResourceID must be specified.

```yaml
Type: String
Parameter Sets: ByDeviceName
Aliases:
Required: True (for ByDeviceName parameter set)
Position: 0
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ResourceID
The ResourceID of the device to remove variables from. Either DeviceName or ResourceID must be specified.

```yaml
Type: Int64
Parameter Sets: ByResourceID
Aliases:
Required: True (for ByResourceID parameter set)
Position: 0
Default value: 0
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -VariableName
The name of the variable(s) to remove. Supports wildcard patterns (*) for removing multiple variables. When using wildcards, all matching variables will be removed.

```yaml
Type: String
Parameter Sets: ByDeviceName, ByResourceID
Aliases: Name
Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: True
```

### -Force
If specified, suppresses confirmation prompts when removing variables. Use this parameter to remove variables without being prompted for confirmation.

```yaml
Type: SwitchParameter
Parameter Sets: ByDeviceName, ByResourceID
Aliases:
Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -WhatIf
Shows what would happen if the cmdlet runs. The cmdlet is not run. Use this to preview which variables would be removed.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: wi
Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Confirm
Prompts you for confirmation before running the cmdlet. This is the default behavior due to ConfirmImpact='High'.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: cf
Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## EXAMPLES

### Example 1: Remove a single variable with confirmation
```powershell
PS C:\> Remove-CMASDeviceVariable -DeviceName "WORKSTATION01" -VariableName "OSDComputerName"
```

Removes the device variable named "OSDComputerName" from device WORKSTATION01. Prompts for confirmation before removing.

### Example 2: Remove a variable without confirmation
```powershell
PS C:\> Remove-CMASDeviceVariable -DeviceName "WORKSTATION01" -VariableName "OSDComputerName" -Force
```

Removes the device variable named "OSDComputerName" from device WORKSTATION01 without prompting for confirmation.

### Example 3: Remove a variable by ResourceID
```powershell
PS C:\> Remove-CMASDeviceVariable -ResourceID 16777220 -VariableName "AppPath" -Force
```

Removes the device variable named "AppPath" from the device with ResourceID 16777220 without confirmation.

### Example 4: Remove multiple variables using wildcards
```powershell
PS C:\> Remove-CMASDeviceVariable -DeviceName "SERVER01" -VariableName "Temp*" -Force
```

Removes all device variables starting with "Temp" from device SERVER01 without confirmation. This could match "TempPath", "TempFile", "TempSetting", etc.

### Example 5: Preview removal with WhatIf
```powershell
PS C:\> Remove-CMASDeviceVariable -DeviceName "WORKSTATION01" -VariableName "TestVar" -WhatIf
```

Shows what would be removed without actually removing the variable. Useful for testing wildcard patterns before executing.

### Example 6: Remove variable via pipeline from Get-CMASDevice
```powershell
PS C:\> Get-CMASDevice -Name "WORKSTATION01" | Remove-CMASDeviceVariable -VariableName "OSDVar" -Force
```

Uses pipeline input to remove a device variable. The device object from Get-CMASDevice is piped to Remove-CMASDeviceVariable.

### Example 7: Remove multiple variables via pipeline from Get-CMASDeviceVariable
```powershell
PS C:\> Get-CMASDeviceVariable -DeviceName "SERVER01" -VariableName "OldVar*" | Remove-CMASDeviceVariable -Force
```

Removes all variables matching the pattern by piping from Get-CMASDeviceVariable. This allows you to preview variables first, then remove them.

### Example 8: Remove all test variables
```powershell
PS C:\> Remove-CMASDeviceVariable -DeviceName "TESTVM01" -VariableName "Test*" -Force
```

Removes all variables starting with "Test" from device TESTVM01. Useful for cleaning up test variables.

### Example 9: Remove variables and capture removed objects
```powershell
PS C:\> $removed = Remove-CMASDeviceVariable -DeviceName "WORKSTATION01" -VariableName "Old*" -Force
PS C:\> $removed | Format-Table Name, Value, ResourceID
```

Removes variables matching "Old*" and captures the removed variable objects in a variable for further processing or logging.

### Example 10: Conditional removal based on variable value
```powershell
PS C:\> $vars = Get-CMASDeviceVariable -DeviceName "WORKSTATION01"
PS C:\> $vars | Where-Object { $_.Value -eq "Obsolete" } | Remove-CMASDeviceVariable -Force
```

Gets all variables for a device, filters for those with value "Obsolete", and removes them using the pipeline.

## INPUTS

### System.Management.Automation.PSCustomObject
Accepts device objects from Get-CMASDevice with ResourceID property, or variable objects from Get-CMASDeviceVariable with Name/VariableName property.

## OUTPUTS

### System.Management.Automation.PSCustomObject
Returns the removed variable object(s) with the following properties:
- **Name**: The variable name
- **Value**: The variable value
- **IsMasked**: Boolean indicating if the variable was masked
- **ResourceID**: The ResourceID of the device
- **DeviceName**: The name of the device

## NOTES

**Author:** SCCM Admin Service Module

**Requirements:**
- An active connection to the SCCM Admin Service (established via Connect-CMAS)
- Appropriate permissions to modify device settings in Configuration Manager
- Target device must exist in Configuration Manager

**Important:**
- This function has ConfirmImpact='High', which means it will prompt for confirmation by default unless `-Confirm:$false` or `-Force` is used.
- When using wildcard patterns, all matching variables will be removed in a single operation.
- The function returns the removed variable objects to the pipeline for logging or further processing.
- If no variables match the specified name or pattern, a warning is displayed and nothing is removed.
- If the device has no variables at all, a warning is displayed.
- Removing variables does not delete the SMS_MachineSettings object; it updates it with the remaining variables.

**WhatIf Support:**
This function fully supports the `-WhatIf` parameter. Use it to preview which variables would be removed without making any changes.

**Related WMI Classes:**
- SMS_MachineSettings: Container for device-specific settings
- SMS_MachineVariable: Individual variable within MachineSettings

## RELATED LINKS

[Connect-CMAS](./Connect-CMAS.md)

[Get-CMASDevice](./Get-CMASDevice.md)

[Get-CMASDeviceVariable](./Get-CMASDeviceVariable.md)

[New-CMASDeviceVariable](./New-CMASDeviceVariable.md)

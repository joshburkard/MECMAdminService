# Set-CMASDeviceVariable

## SYNOPSIS
Modifies an existing device variable for a Configuration Manager device via the Admin Service.

## SYNTAX

### ByDeviceName
```powershell
Set-CMASDeviceVariable -DeviceName <String> -VariableName <String> -VariableValue <String> [-IsMasked] [-IsNotMasked] [-PassThru]
 [-WhatIf] [-Confirm] [<CommonParameters>]
```

### ByResourceID
```powershell
Set-CMASDeviceVariable -ResourceID <Int64> -VariableName <String> -VariableValue <String> [-IsMasked] [-IsNotMasked] [-PassThru]
 [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
This function modifies the properties of an existing custom variable that is assigned to a specific device in Configuration Manager using the Admin Service API. You can change the variable's value and/or its masked (sensitive) status.

Device variables are name-value pairs that can be used in task sequences, scripts, and other Configuration Manager operations. The function supports identifying the target device by either device name or ResourceID.

The function uses the Admin Service REST API to interact with the SMS_MachineSettings WMI class. The specified variable must already exist on the device. To create new variables, use New-CMASDeviceVariable.

Device variables are commonly used in:
- Operating System Deployment (OSD) task sequences
- Application deployment customization
- Script execution with device-specific values
- Configuration baselines

## PARAMETERS

### -DeviceName
The name of the device containing the variable to modify. Either DeviceName or ResourceID must be specified.

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
The ResourceID of the device containing the variable to modify. Either DeviceName or ResourceID must be specified.

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
The name of the variable to modify. The variable must already exist on the device.

```yaml
Type: String
Parameter Sets: ByDeviceName, ByResourceID
Aliases: Name
Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -VariableValue
The new value to assign to the variable. Can be any string value, including paths, configuration values, or empty strings.

```yaml
Type: String
Parameter Sets: ByDeviceName, ByResourceID
Aliases: Value
Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -IsMasked
If specified, marks the variable as masked (sensitive). Masked variables have their values hidden in the Configuration Manager console for security purposes. Use this for passwords, secrets, or other sensitive data.

Cannot be used together with -IsNotMasked.

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

### -IsNotMasked
If specified, marks the variable as not masked (visible). This allows you to unmask a previously masked variable.

Cannot be used together with -IsMasked.

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

### -PassThru
If specified, returns the modified variable object after the update.

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
Shows what would happen if the cmdlet runs. The cmdlet is not run.

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
Prompts you for confirmation before running the cmdlet.

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

## INPUTS

### System.Int64
You can pipe ResourceID to this cmdlet.

### System.String
You can pipe VariableName to this cmdlet.

## OUTPUTS

### System.Management.Automation.PSCustomObject
When -PassThru is specified, returns an object with the following properties:
- Name: The variable name
- Value: The variable value (or [MASKED] for masked variables)
- IsMasked: Boolean indicating if the variable is masked
- ResourceID: The device's ResourceID
- DeviceName: The device's name

## NOTES
**Requirements:**
- An active connection to the Admin Service (via Connect-CMAS)
- Appropriate RBAC permissions in Configuration Manager
- The specified device variable must already exist

**API Details:**
- Uses REST API: PUT wmi/SMS_MachineSettings(ResourceID)
- Requires the SMS_MachineSettings class to exist for the device
- Updates the entire MachineVariables array

**Related Functions:**
- Use New-CMASDeviceVariable to create new variables
- Use Get-CMASDeviceVariable to retrieve existing variables
- Use Remove-CMASDeviceVariable to delete variables

## EXAMPLES

### Example 1: Modify a device variable value
```powershell
Set-CMASDeviceVariable -DeviceName "WORKSTATION01" -VariableName "OSDComputerName" -VariableValue "WS01-NEW"
```

Updates the value of the device variable "OSDComputerName" to "WS01-NEW" for device WORKSTATION01.

### Example 2: Modify by ResourceID with PassThru
```powershell
Set-CMASDeviceVariable -ResourceID 16777220 -VariableName "AppPath" -VariableValue "D:\Apps\MyApp" -PassThru
```

Updates the device variable by ResourceID and returns the modified variable object.

### Example 3: Mark a variable as masked
```powershell
Set-CMASDeviceVariable -DeviceName "SERVER01" -VariableName "DBPassword" -VariableValue "NewP@ssw0rd" -IsMasked
```

Updates a device variable with a new password value and marks it as masked (sensitive).

### Example 4: Unmask a variable
```powershell
Set-CMASDeviceVariable -DeviceName "WORKSTATION01" -VariableName "TestVar" -VariableValue "Public" -IsNotMasked
```

Updates a variable and explicitly sets it as not masked (visible).

### Example 5: Update with WhatIf
```powershell
Set-CMASDeviceVariable -DeviceName "WORKSTATION01" -VariableName "InstallPath" -VariableValue "E:\Software" -WhatIf
```

Shows what would happen without actually modifying the variable.

### Example 6: Pipeline from Get-CMASDeviceVariable
```powershell
Get-CMASDeviceVariable -DeviceName "WORKSTATION01" -VariableName "TestVar" | Set-CMASDeviceVariable -VariableValue "NewValue"
```

Retrieves a variable and updates its value using the pipeline.

### Example 7: Set to empty value
```powershell
Set-CMASDeviceVariable -DeviceName "WORKSTATION01" -VariableName "TempPath" -VariableValue ""
```

Clears the value of a device variable by setting it to an empty string.

### Example 8: Batch update using pipeline
```powershell
Get-CMASDeviceVariable -DeviceName "WORKSTATION01" -VariableName "OSD*" |
    ForEach-Object { Set-CMASDeviceVariable -ResourceID $_.ResourceID -VariableName $_.Name -VariableValue "Updated" }
```

Updates all variables starting with "OSD" for a device.

## RELATED LINKS

[Connect-CMAS](Connect-CMAS.md)

[Get-CMASDevice](Get-CMASDevice.md)

[Get-CMASDeviceVariable](Get-CMASDeviceVariable.md)

[New-CMASDeviceVariable](New-CMASDeviceVariable.md)

[Remove-CMASDeviceVariable](Remove-CMASDeviceVariable.md)

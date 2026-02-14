# New-CMASDeviceVariable

## SYNOPSIS
Creates a new device variable for a Configuration Manager device via the Admin Service.

## SYNTAX

### ByDeviceName
```powershell
New-CMASDeviceVariable -DeviceName <String> -VariableName <String> -VariableValue <String> [-IsMasked] [-PassThru]
 [-WhatIf] [-Confirm] [<CommonParameters>]
```

### ByResourceID
```powershell
New-CMASDeviceVariable -ResourceID <Int64> -VariableName <String> -VariableValue <String> [-IsMasked] [-PassThru]
 [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
This function creates a custom variable that can be assigned to a specific device in Configuration Manager using the Admin Service API. Device variables are name-value pairs that can be used in task sequences, scripts, and other Configuration Manager operations.

Variables can be marked as masked (sensitive) to hide their values in the Configuration Manager console. The function supports identifying the target device by either device name or ResourceID.

Device variables are commonly used in:
- Operating System Deployment (OSD) task sequences
- Application deployment customization
- Script execution with device-specific values
- Configuration baselines

The function uses the Admin Service REST API to interact with the SMS_MachineSettings WMI class. Variable names must be unique per device. If a variable with the same name already exists, the function will fail.

## PARAMETERS

### -DeviceName
The name of the device to create the variable for. Either DeviceName or ResourceID must be specified.

```yaml
Type: String
Parameter Sets: ByDeviceName
Aliases:
Required: True (for ByDeviceName parameter set)
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ResourceID
The ResourceID of the device to create the variable for. Either DeviceName or ResourceID must be specified.

```yaml
Type: Int64
Parameter Sets: ByResourceID
Aliases:
Required: True (for ByResourceID parameter set)
Position: Named
Default value: 0
Accept pipeline input: False
Accept wildcard characters: False
```

### -VariableName
The name of the variable to create. Variable names should not contain spaces or special characters. The name must be unique for the device. Valid characters are letters, numbers, underscores, and hyphens.

```yaml
Type: String
Parameter Sets: ByDeviceName, ByResourceID
Aliases:
Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -VariableValue
The value to assign to the variable. Can be any string value, including paths, configuration values, or empty strings.

```yaml
Type: String
Parameter Sets: ByDeviceName, ByResourceID
Aliases:
Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -IsMasked
If specified, marks the variable as masked (sensitive). Masked variables have their values hidden in the Configuration Manager console for security purposes. Use this for passwords, secrets, or other sensitive data.

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
If specified, returns the created variable object with properties including Name, Value, IsMasked, ResourceID, and DeviceName.

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

## EXAMPLES

### Example 1: Create a basic device variable
```powershell
PS C:\> New-CMASDeviceVariable -DeviceName "WORKSTATION01" -VariableName "OSDComputerName" -VariableValue "WS01-NEW"
```

Creates a new device variable named "OSDComputerName" with value "WS01-NEW" for device WORKSTATION01. This variable can be used in OSD task sequences to set the computer name.

### Example 2: Create a device variable by ResourceID
```powershell
PS C:\> New-CMASDeviceVariable -ResourceID 16777220 -VariableName "AppPath" -VariableValue "C:\Apps\MyApp" -PassThru
```

Creates a new device variable by ResourceID and returns the created variable object with all properties.

### Example 3: Create a masked (sensitive) variable
```powershell
PS C:\> New-CMASDeviceVariable -DeviceName "SERVER01" -VariableName "DBPassword" -VariableValue "P@ssw0rd" -IsMasked
```

Creates a new masked (sensitive) device variable for storing a password. The value will be hidden in the Configuration Manager console.

### Example 4: Create a variable with a path value
```powershell
PS C:\> New-CMASDeviceVariable -DeviceName "WORKSTATION01" -VariableName "InstallPath" -VariableValue "D:\Software"
```

Creates a simple device variable for use in deployment task sequences to specify an installation path.

### Example 5: Create multiple variables for a device
```powershell
PS C:\> $deviceName = "WORKSTATION01"
PS C:\> New-CMASDeviceVariable -DeviceName $deviceName -VariableName "OSDComputerName" -VariableValue "WS01-NEW"
PS C:\> New-CMASDeviceVariable -DeviceName $deviceName -VariableName "OSDDomainName" -VariableValue "contoso.com"
PS C:\> New-CMASDeviceVariable -DeviceName $deviceName -VariableName "OSDDomainOUName" -VariableValue "OU=Workstations,DC=contoso,DC=com"
```

Creates multiple OSD-related variables for a single device in preparation for operating system deployment.

### Example 6: Create a variable with verbose output
```powershell
PS C:\> New-CMASDeviceVariable -DeviceName "WORKSTATION01" -VariableName "TestVar" -VariableValue "TestValue" -Verbose
```

Creates a device variable with verbose output showing the steps being performed.

### Example 7: Use WhatIf to preview variable creation
```powershell
PS C:\> New-CMASDeviceVariable -DeviceName "PRODUCTIONSERVER" -VariableName "CriticalVar" -VariableValue "ImportantValue" -WhatIf
```

Shows what would happen without actually creating the variable. Useful for testing commands before running them on production systems.

### Example 8: Create a variable and verify its properties
```powershell
PS C:\> $var = New-CMASDeviceVariable -DeviceName "WORKSTATION01" -VariableName "DeploymentType" -VariableValue "Standard" -PassThru
PS C:\> $var | Format-List
```

Creates a variable, returns it, and displays all its properties in a formatted list.

## INPUTS

### None
This function does not accept pipeline input.

## OUTPUTS

### System.Management.Automation.PSCustomObject
When using the -PassThru parameter, returns an object with the following properties:
- **Name**: The variable name
- **Value**: The variable value (masked if IsMasked is true)
- **IsMasked**: Boolean indicating if the variable is masked
- **ResourceID**: The ResourceID of the device
- **DeviceName**: The name of the device

## NOTES

**Author:** SCCM Admin Service Module

**Requirements:**
- An active connection to the SCCM Admin Service (established via Connect-CMAS)
- Appropriate permissions to modify device settings in Configuration Manager
- Target device must exist in Configuration Manager

**Important:**
- Variable names must be unique per device. Attempting to create a duplicate will result in an error.
- Variable names can only contain letters, numbers, underscores, and hyphens (no spaces).
- If MachineSettings do not exist for the device, they will be created automatically.
- Use `-IsMasked` for sensitive data like passwords to hide values in the console.
- Device variables are synchronized to the client and can be used in task sequences and scripts.

**Related WMI Classes:**
- SMS_MachineSettings: Container for device-specific settings
- SMS_MachineVariable: Individual variable within MachineSettings

## RELATED LINKS

[Connect-CMAS](./Connect-CMAS.md)

[Get-CMASDevice](./Get-CMASDevice.md)

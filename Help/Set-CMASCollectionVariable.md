# Set-CMASCollectionVariable

## SYNOPSIS
Modifies an existing collection variable for a Configuration Manager collection via the Admin Service.

## SYNTAX

### ByCollectionName
```powershell
Set-CMASCollectionVariable -CollectionName <String> -VariableName <String> -VariableValue <String> [-IsMasked] [-IsNotMasked] [-PassThru]
 [-WhatIf] [-Confirm] [<CommonParameters>]
```

### ByCollectionID
```powershell
Set-CMASCollectionVariable -CollectionID <String> -VariableName <String> -VariableValue <String> [-IsMasked] [-IsNotMasked] [-PassThru]
 [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
This function modifies the properties of an existing custom variable that is assigned to a specific collection in Configuration Manager using the Admin Service API. You can change the variable's value and/or its masked (sensitive) status.

Collection variables are name-value pairs that can be used in task sequences, scripts, and other Configuration Manager operations. The function supports identifying the target collection by either collection name or CollectionID.

The function uses the Admin Service REST API to interact with the SMS_CollectionSettings WMI class. The specified variable must already exist on the collection. To create new variables, use New-CMASCollectionVariable.

Collection variables are commonly used in:
- Operating System Deployment (OSD) task sequences
- Application deployment customization
- Script execution with collection-specific values
- Configuration baselines

## PARAMETERS

### -CollectionName
The name of the collection containing the variable to modify. Either CollectionName or CollectionID must be specified.

```yaml
Type: String
Parameter Sets: ByCollectionName
Aliases:
Required: True (for ByCollectionName parameter set)
Position: 0
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -CollectionID
The CollectionID of the collection containing the variable to modify. Either CollectionName or CollectionID must be specified.

```yaml
Type: String
Parameter Sets: ByCollectionID
Aliases:
Required: True (for ByCollectionID parameter set)
Position: 0
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -VariableName
The name of the variable to modify. The variable must already exist on the collection.

```yaml
Type: String
Parameter Sets: ByCollectionName, ByCollectionID
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
Parameter Sets: ByCollectionName, ByCollectionID
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
Parameter Sets: ByCollectionName, ByCollectionID
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
Parameter Sets: ByCollectionName, ByCollectionID
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
Parameter Sets: ByCollectionName, ByCollectionID
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

### System.String
You can pipe CollectionID and VariableName to this cmdlet.

## OUTPUTS

### System.Management.Automation.PSCustomObject
When -PassThru is specified, returns an object with the following properties:
- Name: The variable name
- Value: The variable value (or [MASKED] for masked variables)
- IsMasked: Boolean indicating if the variable is masked
- CollectionID: The collection's CollectionID
- CollectionName: The collection's name

## NOTES
**Requirements:**
- An active connection to the Admin Service (via Connect-CMAS)
- Appropriate RBAC permissions in Configuration Manager
- The specified collection variable must already exist

**API Details:**
- Uses REST API: PUT wmi/SMS_CollectionSettings('CollectionID')
- Requires the SMS_CollectionSettings class to exist for the collection
- Updates the entire CollectionVariables array

**Related Functions:**
- Use New-CMASCollectionVariable to create new variables
- Use Get-CMASCollectionVariable to retrieve existing variables
- Use Remove-CMASCollectionVariable to delete variables

## EXAMPLES

### Example 1: Modify a collection variable value
```powershell
Set-CMASCollectionVariable -CollectionName "Production Servers" -VariableName "OSDComputerOU" -VariableValue "OU=Servers,DC=contoso,DC=com"
```

Updates the value of the collection variable "OSDComputerOU" for collection "Production Servers".

### Example 2: Modify by CollectionID with PassThru
```powershell
Set-CMASCollectionVariable -CollectionID "SMS00001" -VariableName "AppPath" -VariableValue "C:\Apps\MyApp" -PassThru
```

Updates the collection variable by CollectionID and returns the modified variable object.

### Example 3: Mark a variable as masked
```powershell
Set-CMASCollectionVariable -CollectionName "Finance Workstations" -VariableName "DBPassword" -VariableValue "NewP@ssw0rd" -IsMasked
```

Updates a collection variable with a new password value and marks it as masked (sensitive).

### Example 4: Unmask a variable
```powershell
Set-CMASCollectionVariable -CollectionName "Test Collection" -VariableName "TestVar" -VariableValue "Public" -IsNotMasked
```

Updates a variable and explicitly sets it as not masked (visible).

### Example 5: Update with WhatIf
```powershell
Set-CMASCollectionVariable -CollectionName "Test Collection" -VariableName "InstallPath" -VariableValue "E:\Software" -WhatIf
```

Shows what would happen without actually modifying the variable.

### Example 6: Set to empty value
```powershell
Set-CMASCollectionVariable -CollectionName "Test Collection" -VariableName "TempPath" -VariableValue ""
```

Clears the value of a collection variable by setting it to an empty string.

## RELATED LINKS

[Connect-CMAS](./Connect-CMAS.md)

[Get-CMASCollection](./Get-CMASCollection.md)

[Get-CMASCollectionVariable](./Get-CMASCollectionVariable.md)

[New-CMASCollectionVariable](./New-CMASCollectionVariable.md)

[Remove-CMASCollectionVariable](./Remove-CMASCollectionVariable.md)

[Online Documentation](https://github.com/yourusername/SCCMAdminService)

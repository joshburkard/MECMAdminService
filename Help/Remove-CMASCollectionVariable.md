# Remove-CMASCollectionVariable

## SYNOPSIS
Removes collection variables from a Configuration Manager collection via the Admin Service.

## SYNTAX

### ByCollectionName
```powershell
Remove-CMASCollectionVariable -CollectionName <String> -VariableName <String> [-Force] [-WhatIf] [-Confirm]
 [<CommonParameters>]
```

### ByCollectionID
```powershell
Remove-CMASCollectionVariable -CollectionID <String> -VariableName <String> [-Force] [-WhatIf] [-Confirm]
 [<CommonParameters>]
```

## DESCRIPTION
This function removes custom variables that are assigned to a specific collection in Configuration Manager using the Admin Service API. Collection variables can be removed by exact name or using wildcard patterns to remove multiple variables at once.

The function supports identifying the target collection by either collection name or CollectionID. It also supports pipeline input from Get-CMASCollection or Get-CMASCollectionVariable for streamlined workflows.

When removing variables, the entire SMS_CollectionSettings object is updated. If all variables are removed, an empty CollectionVariables array is maintained to preserve the settings object.

The function includes built-in confirmation prompts (ConfirmImpact='High') to prevent accidental deletion of variables. Use the `-Force` parameter to bypass confirmation prompts.

## PARAMETERS

### -CollectionName
The name of the collection to remove variables from. Either CollectionName or CollectionID must be specified.

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
The CollectionID of the collection to remove variables from. Either CollectionName or CollectionID must be specified.

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
The name of the variable(s) to remove. Supports wildcard patterns (*) for removing multiple variables. When using wildcards, all matching variables will be removed.

```yaml
Type: String
Parameter Sets: ByCollectionName, ByCollectionID
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
Parameter Sets: ByCollectionName, ByCollectionID
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
PS C:\> Remove-CMASCollectionVariable -CollectionName "Test Collection" -VariableName "OSDComputerOU"
```

Removes the collection variable named "OSDComputerOU" from collection "Test Collection". Prompts for confirmation before removing.

### Example 2: Remove a variable without confirmation
```powershell
PS C:\> Remove-CMASCollectionVariable -CollectionName "Test Collection" -VariableName "OSDComputerOU" -Force
```

Removes the collection variable named "OSDComputerOU" from collection "Test Collection" without prompting for confirmation.

### Example 3: Remove a variable by CollectionID
```powershell
PS C:\> Remove-CMASCollectionVariable -CollectionID "SMS00001" -VariableName "AppPath" -Force
```

Removes the collection variable named "AppPath" from the collection with CollectionID SMS00001 without confirmation.

### Example 4: Remove multiple variables using wildcards
```powershell
PS C:\> Remove-CMASCollectionVariable -CollectionName "Production Servers" -VariableName "Temp*" -Force
```

Removes all collection variables starting with "Temp" from collection "Production Servers" without confirmation. This could match "TempPath", "TempFile", "TempSetting", etc.

### Example 5: Preview removal with WhatIf
```powershell
PS C:\> Remove-CMASCollectionVariable -CollectionName "Test Collection" -VariableName "TestVar" -WhatIf
```

Shows what would be removed without actually removing the variable. Useful for validating which variables match before executing the removal.

### Example 6: Remove variable from pipeline (Get-CMASCollection)
```powershell
PS C:\> Get-CMASCollection -Name "Test Collection" | Remove-CMASCollectionVariable -VariableName "OSDVar" -Force
```

Uses pipeline input from Get-CMASCollection to remove a collection variable. The CollectionID is automatically passed via the pipeline.

### Example 7: Remove variable from pipeline (Get-CMASCollectionVariable)
```powershell
PS C:\> Get-CMASCollectionVariable -CollectionName "Production Servers" -VariableName "OldVar*" | Remove-CMASCollectionVariable -Force
```

Retrieves variables matching "OldVar*" pattern and pipes them to Remove-CMASCollectionVariable. This allows you to first review variables before removing them in a two-step process.

### Example 8: Remove all variables matching pattern and capture output
```powershell
PS C:\> $removed = Remove-CMASCollectionVariable -CollectionName "Test Collection" -VariableName "Test*" -Force
PS C:\> $removed | Format-Table Name, Value, CollectionName
```

Removes all variables starting with "Test" and captures the removed variable objects in a variable for further processing or reporting.

## INPUTS

### System.String
You can pipe CollectionID and VariableName values to this cmdlet.

### Custom Objects
You can pipe collection objects from Get-CMASCollection or collection variable objects from Get-CMASCollectionVariable.

## OUTPUTS

### PSCustomObject
Returns custom objects representing the removed collection variables with the following properties:
- **Name**: The name of the removed variable
- **Value**: The value of the removed variable (empty for masked variables)
- **IsMasked**: Boolean indicating if the variable was masked (sensitive)
- **CollectionID**: The CollectionID of the collection
- **CollectionName**: The name of the collection

## NOTES

**Module:** MECMAdminService

**Author:** SD Worx

**Version:** 1.0

**Requirements:**
- Active connection to SCCM Admin Service (established via Connect-CMAS)
- Appropriate RBAC permissions to modify collection settings
- PowerShell 5.1 or later

**Important Considerations:**
- This function has ConfirmImpact='High', meaning it will prompt for confirmation by default
- Use `-Force` to suppress confirmation prompts (useful for automation)
- Wildcard patterns allow batch removal of multiple variables
- The entire SMS_CollectionSettings object is updated when variables are removed
- An empty CollectionVariables array remains even if all variables are removed
- Removed variable objects are returned to the pipeline for further processing

## RELATED LINKS

[Connect-CMAS](./Connect-CMAS.md)

[Get-CMASCollection](./Get-CMASCollection.md)

[Get-CMASCollectionVariable](./Get-CMASCollectionVariable.md)

[New-CMASCollectionVariable](./New-CMASCollectionVariable.md)

[Set-CMASCollectionVariable](./Set-CMASCollectionVariable.md)

[Online Documentation](https://github.com/yourusername/SCCMAdminService)

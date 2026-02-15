# New-CMASCollectionVariable

## SYNOPSIS
Creates a new collection variable for a Configuration Manager collection via the Admin Service.

## SYNTAX

### ByCollectionName
```powershell
New-CMASCollectionVariable -CollectionName <String> -VariableName <String> -VariableValue <String> [-IsMasked] [-PassThru]
 [-WhatIf] [-Confirm] [<CommonParameters>]
```

### ByCollectionID
```powershell
New-CMASCollectionVariable -CollectionID <String> -VariableName <String> -VariableValue <String> [-IsMasked] [-PassThru]
 [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
This function creates a custom variable that can be assigned to a specific collection in Configuration Manager using the Admin Service API. Collection variables are name-value pairs that can be used in task sequences, scripts, and other Configuration Manager operations for all members of the collection.

Variables can be marked as masked (sensitive) to hide their values in the Configuration Manager console. The function supports identifying the target collection by either collection name or CollectionID.

Collection variables are commonly used in:
- Operating System Deployment (OSD) task sequences
- Application deployment customization
- Script execution with collection-specific values
- Configuration baselines

The function uses the Admin Service REST API to interact with the SMS_CollectionSettings WMI class. Variable names must be unique per collection. If a variable with the same name already exists, the function will fail.

## PARAMETERS

### -CollectionName
The name of the collection to create the variable for. Either CollectionName or CollectionID must be specified.

```yaml
Type: String
Parameter Sets: ByCollectionName
Aliases:
Required: True (for ByCollectionName parameter set)
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -CollectionID
The CollectionID of the collection to create the variable for. Either CollectionName or CollectionID must be specified.

```yaml
Type: String
Parameter Sets: ByCollectionID
Aliases:
Required: True (for ByCollectionID parameter set)
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -VariableName
The name of the variable to create. Variable names should not contain spaces or special characters. The name must be unique for the collection. Valid characters are letters, numbers, underscores, and hyphens.

```yaml
Type: String
Parameter Sets: ByCollectionName, ByCollectionID
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
Parameter Sets: ByCollectionName, ByCollectionID
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
Parameter Sets: ByCollectionName, ByCollectionID
Aliases:
Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -PassThru
If specified, returns the created variable object with properties including Name, Value, IsMasked, CollectionID, and CollectionName.

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

## EXAMPLES

### Example 1: Create a basic collection variable
```powershell
PS C:\> New-CMASCollectionVariable -CollectionName "Production Servers" -VariableName "OSDComputerOU" -VariableValue "OU=Servers,DC=contoso,DC=com"
```

Creates a new collection variable named "OSDComputerOU" with the specified OU path for the "Production Servers" collection. This variable can be used in OSD task sequences to determine where computer accounts should be created.

### Example 2: Create a collection variable by CollectionID
```powershell
PS C:\> New-CMASCollectionVariable -CollectionID "SMS00001" -VariableName "AppPath" -VariableValue "C:\Apps\MyApp" -PassThru
```

Creates a new collection variable by CollectionID and returns the created variable object with all properties.

### Example 3: Create a masked (sensitive) variable
```powershell
PS C:\> New-CMASCollectionVariable -CollectionName "Finance Workstations" -VariableName "DBPassword" -VariableValue "P@ssw0rd" -IsMasked
```

Creates a new masked (sensitive) collection variable for storing a password. The value will be hidden in the Configuration Manager console.

### Example 4: Create a variable with a path value
```powershell
PS C:\> New-CMASCollectionVariable -CollectionName "Test Collection" -VariableName "InstallPath" -VariableValue "D:\Software"
```

Creates a simple collection variable for use in deployment task sequences to specify an installation path.

### Example 5: Create multiple variables for a collection
```powershell
PS C:\> $collectionName = "Production Servers"
PS C:\> New-CMASCollectionVariable -CollectionName $collectionName -VariableName "OSDComputerOU" -VariableValue "OU=Servers,DC=contoso,DC=com"
PS C:\> New-CMASCollectionVariable -CollectionName $collectionName -VariableName "OSDDomainName" -VariableValue "contoso.com"
PS C:\> New-CMASCollectionVariable -CollectionName $collectionName -VariableName "TimeZone" -VariableValue "Pacific Standard Time"
```

Creates multiple OSD-related variables for a single collection in preparation for operating system deployment.

### Example 6: Create a variable with verbose output
```powershell
PS C:\> New-CMASCollectionVariable -CollectionName "Test Collection" -VariableName "TestVar" -VariableValue "TestValue" -Verbose
```

Creates a collection variable with verbose output showing the steps being performed.

### Example 7: Use WhatIf to preview variable creation
```powershell
PS C:\> New-CMASCollectionVariable -CollectionName "Production Collection" -VariableName "CriticalVar" -VariableValue "ImportantValue" -WhatIf
```

Previews what would happen if the collection variable is created, without actually creating it. Useful for testing before making changes to production collections.

### Example 8: Create a variable with an empty value
```powershell
PS C:\> New-CMASCollectionVariable -CollectionName "Development Servers" -VariableName "OptionalSetting" -VariableValue ""
```

Creates a collection variable with an empty value. This can be useful for placeholder variables or optional settings.

### Example 9: Create and verify a collection variable
```powershell
PS C:\> New-CMASCollectionVariable -CollectionName "Test Collection" -VariableName "DeploymentPath" -VariableValue "\\server\share\apps" -PassThru | Format-List

Name          : DeploymentPath
Value         : \\server\share\apps
IsMasked      : False
CollectionID  : SMS00001
CollectionName: Test Collection
```

Creates a collection variable and displays all its properties in a formatted list.

### Example 10: Create variables for different collection types
```powershell
PS C:\> # User collection variable
PS C:\> New-CMASCollectionVariable -CollectionName "Finance Users" -VariableName "HomeDriveRoot" -VariableValue "\\fileserver\users"

PS C:\> # Device collection variable
PS C:\> New-CMASCollectionVariable -CollectionName "Finance Workstations" -VariableName "HomeDriveRoot" -VariableValue "\\fileserver\users"
```

Creates variables for both user and device collections, demonstrating that collection variables work with any collection type.

## INPUTS

### None
This cmdlet does not accept pipeline input.

## OUTPUTS

### PSCustomObject
When -PassThru is specified, returns a custom object containing the created variable with the following properties:
- Name: The variable name
- Value: The variable value
- IsMasked: Whether the variable is masked (sensitive)
- CollectionID: The collection ID
- CollectionName: The collection name

### None
When -PassThru is not specified, this cmdlet does not generate output.

## NOTES
- Requires an active connection to the SCCM Admin Service (use Connect-CMAS)
- Requires appropriate Configuration Manager permissions to modify collection settings
- Collection variables apply to all members of the collection
- Variable names must be unique within each collection
- Variable names can only contain letters, numbers, underscores, and hyphens
- Masked variables cannot have their values retrieved via the Admin Service API
- Changes to collection variables are reflected immediately in Configuration Manager
- This function supports ShouldProcess (-WhatIf and -Confirm parameters)

## RELATED LINKS

- [Connect-CMAS](./Connect-CMAS.md)
- [Get-CMASCollection](./Get-CMASCollection.md)
- [Get-CMASCollectionVariable](./Get-CMASCollectionVariable.md)
- [Set-CMASCollectionVariable](./Set-CMASCollectionVariable.md)
- [Remove-CMASCollectionVariable](./Remove-CMASCollectionVariable.md)

# Get-CMASCollectionVariable

## SYNOPSIS
Gets collection variables for a Configuration Manager collection via the Admin Service.

## SYNTAX

### ByCollectionName (Default)

```powershell
Get-CMASCollectionVariable [-CollectionName] <String> [-VariableName <String>] [<CommonParameters>]
```

### ByCollectionID

```powershell
Get-CMASCollectionVariable [-CollectionID] <String> [-VariableName <String>] [<CommonParameters>]
```

## DESCRIPTION

This function retrieves custom variables that are assigned to a specific collection in Configuration Manager using the Admin Service API. Collection variables are name-value pairs that can be used in task sequences, scripts, and other Configuration Manager operations.

The function supports identifying the target collection by either collection name or CollectionID. You can optionally filter the results to specific variable names using wildcard patterns.

## PARAMETERS

### -CollectionName

The name of the collection to retrieve variables from. Either CollectionName or CollectionID must be specified.

```yaml
Type: String
Parameter Sets: ByCollectionName
Aliases:

Required: False
Position: 0
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -CollectionID

The CollectionID of the collection to retrieve variables from. Either CollectionName or CollectionID must be specified.

```yaml
Type: String
Parameter Sets: ByCollectionID
Aliases:

Required: False
Position: 0
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -VariableName
Optional. The name of a specific variable to retrieve. Supports wildcard patterns (*). If not specified, all variables for the collection are returned.

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
- **CollectionName**: The name of the collection
- **CollectionID**: The CollectionID of the collection

Returns nothing if the collection has no variables or no variables match the filter criteria.

## NOTES

**Module**: MECMAdminService
**Requires**: An active connection to the SCCM Admin Service (Connect-CMAS)

The function queries the SMS_CollectionSettings WMI class via the Admin Service REST API. Returns an empty result if the collection has no variables configured.

Collection variables are commonly used in:
- Operating System Deployment (OSD) task sequences
- Application deployment customization
- Script execution with collection-specific values
- Configuration baselines

## EXAMPLES

### Example 1: Get all variables for a collection by name
```powershell
Get-CMASCollectionVariable -CollectionName "Production Servers"
```

Retrieves all collection variables for collection "Production Servers".

### Example 2: Get all variables for a collection by CollectionID
```powershell
Get-CMASCollectionVariable -CollectionID "SMS00001"
```

Retrieves all collection variables for the collection with CollectionID SMS00001.

### Example 3: Get variables matching a pattern
```powershell
Get-CMASCollectionVariable -CollectionName "Production Servers" -VariableName "OSD*"
```

Retrieves all collection variables starting with "OSD" for collection "Production Servers". This is useful for finding all OSD-related variables.

### Example 4: Get a specific variable
```powershell
Get-CMASCollectionVariable -CollectionName "Test Servers" -VariableName "AppPath"
```

Retrieves the specific collection variable named "AppPath" for collection "Test Servers".

### Example 5: Get variables and display in a table
```powershell
Get-CMASCollectionVariable -CollectionName "Production Servers" | Format-Table Name, Value, IsMasked -AutoSize
```

Retrieves all variables for "Production Servers" and displays them in a formatted table.

### Example 6: Get variables for multiple collections
```powershell
$collections = "Dev Collection", "Test Collection", "Production Servers"
$collections | ForEach-Object {
    [PSCustomObject]@{
        Collection = $_
        Variables = @(Get-CMASCollectionVariable -CollectionName $_)
        Count = @(Get-CMASCollectionVariable -CollectionName $_).Count
    }
}
```

Retrieves variables for multiple collections and creates a summary showing the collection name and variable count.

### Example 7: Check if a collection has any variables
```powershell
$variables = Get-CMASCollectionVariable -CollectionName "Production Servers"
if ($variables) {
    Write-Host "Collection has $(@($variables).Count) variable(s)" -ForegroundColor Green
} else {
    Write-Host "Collection has no variables configured" -ForegroundColor Yellow
}
```

Checks if a collection has any variables configured and displays an appropriate message.

### Example 8: Export collection variables to CSV
```powershell
Get-CMASCollectionVariable -CollectionName "Production Servers" |
    Select-Object CollectionName, Name, Value, IsMasked |
    Export-Csv -Path "C:\Temp\CollectionVariables.csv" -NoTypeInformation
```

Retrieves all variables for a collection and exports them to a CSV file for documentation or reporting purposes.

### Example 9: Get all unmasked variables
```powershell
Get-CMASCollectionVariable -CollectionName "Production Servers" |
    Where-Object { -not $_.IsMasked }
```

Retrieves only non-masked (non-sensitive) variables for a collection. Use this to avoid displaying sensitive information.

### Example 10: Get masked (sensitive) variables
```powershell
Get-CMASCollectionVariable -CollectionID "SMS00001" |
    Where-Object { $_.IsMasked }
```

Retrieves only masked (sensitive) variables. Note that even masked variables will show their values through the API (they're hashed in SCCM console).

### Example 11: Compare variables between collections
```powershell
$devVars = Get-CMASCollectionVariable -CollectionName "Dev Collection"
$prodVars = Get-CMASCollectionVariable -CollectionName "Production Servers"

Compare-Object -ReferenceObject $devVars -DifferenceObject $prodVars -Property Name
```

Compares variable names between two collections to identify differences.

### Example 12: Find collections with a specific variable
```powershell
$targetVar = "AppPath"
$collections = Get-CMASCollection
$collections | Where-Object {
    $vars = Get-CMASCollectionVariable -CollectionID $_.CollectionID -VariableName $targetVar
    $null -ne $vars
} | Select-Object Name, CollectionID
```

Finds all collections that have a specific variable defined.

## RELATED LINKS

[Connect-CMAS](Connect-CMAS.md)
[Get-CMASCollection](Get-CMASCollection.md)

# Get-CMASCollectionExcludeMembershipRule

## SYNOPSIS
Retrieves exclude membership rules from a Configuration Manager collection.

## SYNTAX

### ByName (Default)
```powershell
Get-CMASCollectionExcludeMembershipRule -CollectionName <String> [-ExcludeCollectionName <String>] [-ExcludeCollectionId <String>] [<CommonParameters>]
```

### ById
```powershell
Get-CMASCollectionExcludeMembershipRule -CollectionId <String> [-ExcludeCollectionName <String>] [-ExcludeCollectionId <String>] [<CommonParameters>]
```

### ByValue
```powershell
Get-CMASCollectionExcludeMembershipRule -InputObject <Object> [-ExcludeCollectionName <String>] [-ExcludeCollectionId <String>] [<CommonParameters>]
```

### ByNameAndExcludeName
```powershell
Get-CMASCollectionExcludeMembershipRule -CollectionName <String> -ExcludeCollectionName <String> [<CommonParameters>]
```

### ByNameAndExcludeId
```powershell
Get-CMASCollectionExcludeMembershipRule -CollectionName <String> -ExcludeCollectionId <String> [<CommonParameters>]
```

### ByIdAndExcludeName
```powershell
Get-CMASCollectionExcludeMembershipRule -CollectionId <String> -ExcludeCollectionName <String> [<CommonParameters>]
```

### ByIdAndExcludeId
```powershell
Get-CMASCollectionExcludeMembershipRule -CollectionId <String> -ExcludeCollectionId <String> [<CommonParameters>]
```

### ByValueAndExcludeName
```powershell
Get-CMASCollectionExcludeMembershipRule -InputObject <Object> -ExcludeCollectionName <String> [<CommonParameters>]
```

### ByValueAndExcludeId
```powershell
Get-CMASCollectionExcludeMembershipRule -InputObject <Object> -ExcludeCollectionId <String> [<CommonParameters>]
```

## DESCRIPTION
This function retrieves exclude membership rules for Configuration Manager collections via the Admin Service API.
You can filter by collection using CollectionName, CollectionId, or by providing a collection object.
Additionally, you can filter the exclude rules by ExcludeCollectionName or ExcludeCollectionId.

Exclude membership rules specify that all members of a particular collection should be excluded from the target collection. This is useful for creating collections that include most devices/users but explicitly exclude certain groups.

## PARAMETERS

### -CollectionName
The name of the collection to retrieve exclude membership rules from.

```yaml
Type: String
Parameter Sets: ByName, ByNameAndExcludeName, ByNameAndExcludeId
Aliases: Name
Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -CollectionId
The ID of the collection to retrieve exclude membership rules from.

```yaml
Type: String
Parameter Sets: ById, ByIdAndExcludeName, ByIdAndExcludeId
Aliases: Id
Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -InputObject
A collection object (from Get-CMASCollection) to retrieve exclude membership rules from.
This parameter accepts pipeline input.

```yaml
Type: Object
Parameter Sets: ByValue, ByValueAndExcludeName, ByValueAndExcludeId
Aliases: Collection
Required: True
Position: Named
Default value: None
Accept pipeline input: True (ByValue)
Accept wildcard characters: False
```

### -ExcludeCollectionName
Optional. Filter exclude rules to only include rules for excluded collections with this name.
Supports wildcards (* and ?).

```yaml
Type: String
Parameter Sets: ByName, ById, ByValue, ByNameAndExcludeName, ByIdAndExcludeName, ByValueAndExcludeName
Aliases: None
Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: True
```

### -ExcludeCollectionId
Optional. Filter exclude rules to only include rules for the excluded collection with this ID.

```yaml
Type: String
Parameter Sets: ByName, ById, ByValue, ByNameAndExcludeId, ByIdAndExcludeId, ByValueAndExcludeId
Aliases: None
Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### System.Object
You can pipe a collection object from Get-CMASCollection to this cmdlet.

## OUTPUTS

### System.Object
Returns collection exclude membership rule objects with the following properties:
- CollectionID: The ID of the collection containing the rule
- ExcludeCollectionID: The ID of the collection being excluded
- RuleName: The name of the excluded collection
- And other properties depending on the rule configuration

## NOTES
- This function is part of the SCCM Admin Service module
- Requires an active connection established via Connect-CMAS
- **IMPORTANT**: The Admin Service does not expose SMS_CollectionRuleExclude as a separate WMI class. This function retrieves the full collection object and extracts exclude membership rules from the CollectionRules property embedded in the SMS_Collection object. This implementation may be less efficient than the native ConfigurationManager cmdlet for collections with many rules.
- The function filters the CollectionRules property to return only rules where `@odata.type` equals '#AdminService.SMS_CollectionRuleExclude'
- **NOTE**: This function returns EXCLUDE MEMBERSHIP RULES, not excluded collection members
  - Exclude membership rules specify which collections should have their members excluded
  - Collections can have query rules, include rules, exclude rules, or direct membership rules
  - This cmdlet only returns exclude membership rules

## EXAMPLES

### Example 1: Get all exclude membership rules from a collection by name
```powershell
Get-CMASCollectionExcludeMembershipRule -CollectionName "All Systems"
```
Retrieves all exclude membership rules from the "All Systems" collection.

### Example 2: Get exclude membership rules from a collection by ID
```powershell
Get-CMASCollectionExcludeMembershipRule -CollectionId "SMS00001"
```
Retrieves all exclude membership rules from the collection with ID SMS00001.

### Example 3: Filter by excluded collection name
```powershell
Get-CMASCollectionExcludeMembershipRule -CollectionName "My Collection" -ExcludeCollectionName "Test Servers"
```
Retrieves exclude membership rules from "My Collection" for excluded collection named "Test Servers".

### Example 4: Filter by excluded collection ID
```powershell
Get-CMASCollectionExcludeMembershipRule -CollectionId "SMS00001" -ExcludeCollectionId "SMS00002"
```
Retrieves exclude membership rule from collection SMS00001 that excludes collection SMS00002.

### Example 5: Use pipeline with Get-CMASCollection
```powershell
Get-CMASCollection -Name "My Collection" | Get-CMASCollectionExcludeMembershipRule
```
Retrieves all exclude membership rules from the piped collection object.

### Example 6: Use wildcards to find exclude rules
```powershell
Get-CMASCollection -Name "My Collection" | Get-CMASCollectionExcludeMembershipRule -ExcludeCollectionName "TEST-*"
```
Retrieves exclude membership rules for excluded collections matching "TEST-*" wildcard pattern.

### Example 7: Get exclude rules for multiple collections
```powershell
"Collection A", "Collection B", "Collection C" | ForEach-Object {
    Get-CMASCollectionExcludeMembershipRule -CollectionName $_
}
```
Retrieves exclude membership rules from multiple collections.

### Example 8: Find all collections that exclude a specific collection
```powershell
Get-CMASCollection | ForEach-Object {
    $rules = $_ | Get-CMASCollectionExcludeMembershipRule -ExcludeCollectionId "SMS00002"
    if ($rules) {
        [PSCustomObject]@{
            CollectionName = $_.Name
            CollectionID = $_.CollectionID
            ExcludeRules = $rules
        }
    }
}
```
Finds all collections that have an exclude rule for collection SMS00002.

## RELATED LINKS

[Connect-CMAS](Connect-CMAS.md)

[Get-CMASCollection](Get-CMASCollection.md)

[Get-CMASCollectionDirectMembershipRule](Get-CMASCollectionDirectMembershipRule.md)

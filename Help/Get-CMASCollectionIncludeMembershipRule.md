# Get-CMASCollectionIncludeMembershipRule

## SYNOPSIS
Retrieves include membership rules from a Configuration Manager collection.

## SYNTAX

### ByName (Default)
```powershell
Get-CMASCollectionIncludeMembershipRule -CollectionName <String> [-IncludeCollectionName <String>] [-IncludeCollectionId <String>] [<CommonParameters>]
```

### ById
```powershell
Get-CMASCollectionIncludeMembershipRule -CollectionId <String> [-IncludeCollectionName <String>] [-IncludeCollectionId <String>] [<CommonParameters>]
```

### ByValue
```powershell
Get-CMASCollectionIncludeMembershipRule -InputObject <Object> [-IncludeCollectionName <String>] [-IncludeCollectionId <String>] [<CommonParameters>]
```

### ByNameAndIncludeName
```powershell
Get-CMASCollectionIncludeMembershipRule -CollectionName <String> -IncludeCollectionName <String> [<CommonParameters>]
```

### ByNameAndIncludeId
```powershell
Get-CMASCollectionIncludeMembershipRule -CollectionName <String> -IncludeCollectionId <String> [<CommonParameters>]
```

### ByIdAndIncludeName
```powershell
Get-CMASCollectionIncludeMembershipRule -CollectionId <String> -IncludeCollectionName <String> [<CommonParameters>]
```

### ByIdAndIncludeId
```powershell
Get-CMASCollectionIncludeMembershipRule -CollectionId <String> -IncludeCollectionId <String> [<CommonParameters>]
```

### ByValueAndIncludeName
```powershell
Get-CMASCollectionIncludeMembershipRule -InputObject <Object> -IncludeCollectionName <String> [<CommonParameters>]
```

### ByValueAndIncludeId
```powershell
Get-CMASCollectionIncludeMembershipRule -InputObject <Object> -IncludeCollectionId <String> [<CommonParameters>]
```

## DESCRIPTION
This function retrieves include membership rules for Configuration Manager collections via the Admin Service API.
You can filter by collection using CollectionName, CollectionId, or by providing a collection object.
Additionally, you can filter the include rules by IncludeCollectionName or IncludeCollectionId.

Include membership rules specify that all members of a particular collection should be included in the target collection. This is useful for creating collections that aggregate members from multiple source collections.

## PARAMETERS

### -CollectionName
The name of the collection to retrieve include membership rules from.

```yaml
Type: String
Parameter Sets: ByName, ByNameAndIncludeName, ByNameAndIncludeId
Aliases: Name
Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -CollectionId
The ID of the collection to retrieve include membership rules from.

```yaml
Type: String
Parameter Sets: ById, ByIdAndIncludeName, ByIdAndIncludeId
Aliases: Id
Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -InputObject
A collection object (from Get-CMASCollection) to retrieve include membership rules from.
This parameter accepts pipeline input.

```yaml
Type: Object
Parameter Sets: ByValue, ByValueAndIncludeName, ByValueAndIncludeId
Aliases: Collection
Required: True
Position: Named
Default value: None
Accept pipeline input: True (ByValue)
Accept wildcard characters: False
```

### -IncludeCollectionName
Optional. Filter include rules to only include rules for included collections with this name.
Supports wildcards (* and ?).

```yaml
Type: String
Parameter Sets: ByName, ById, ByValue, ByNameAndIncludeName, ByIdAndIncludeName, ByValueAndIncludeName
Aliases: None
Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: True
```

### -IncludeCollectionId
Optional. Filter include rules to only include rules for the included collection with this ID.

```yaml
Type: String
Parameter Sets: ByName, ById, ByValue, ByNameAndIncludeId, ByIdAndIncludeId, ByValueAndIncludeId
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
Returns collection include membership rule objects with the following properties:
- CollectionID: The ID of the collection containing the rule
- IncludeCollectionID: The ID of the collection being included
- RuleName: The name of the included collection
- And other properties depending on the rule configuration

## NOTES
- This function is part of the SCCM Admin Service module
- Requires an active connection established via Connect-CMAS
- **IMPORTANT**: The Admin Service does not expose SMS_CollectionRuleInclude as a separate WMI class. This function retrieves the full collection object and extracts include membership rules from the CollectionRules property embedded in the SMS_Collection object. This implementation may be less efficient than the native ConfigurationManager cmdlet for collections with many rules.
- The function filters the CollectionRules property to return only rules where `@odata.type` equals '#AdminService.SMS_CollectionRuleIncludeCollection'
- **NOTE**: This function returns INCLUDE MEMBERSHIP RULES, not included collection members
  - Include membership rules specify which collections should have their members included
  - Collections can have query rules, include rules, exclude rules, or direct membership rules
  - This cmdlet only returns include membership rules

## EXAMPLES

### Example 1: Get all include membership rules from a collection by name
```powershell
Get-CMASCollectionIncludeMembershipRule -CollectionName "All Systems"
```
Retrieves all include membership rules from the "All Systems" collection.

### Example 2: Get include membership rules from a collection by ID
```powershell
Get-CMASCollectionIncludeMembershipRule -CollectionId "SMS00001"
```
Retrieves all include membership rules from the collection with ID SMS00001.

### Example 3: Filter by included collection name
```powershell
Get-CMASCollectionIncludeMembershipRule -CollectionName "My Collection" -IncludeCollectionName "Test Servers"
```
Retrieves include membership rules from "My Collection" for included collection named "Test Servers".

### Example 4: Filter by included collection ID
```powershell
Get-CMASCollectionIncludeMembershipRule -CollectionId "SMS00001" -IncludeCollectionId "SMS00002"
```
Retrieves include membership rule from collection SMS00001 that includes collection SMS00002.

### Example 5: Use pipeline with Get-CMASCollection
```powershell
Get-CMASCollection -Name "My Collection" | Get-CMASCollectionIncludeMembershipRule
```
Retrieves all include membership rules from the piped collection object.

### Example 6: Use wildcards to find include rules
```powershell
Get-CMASCollection -Name "My Collection" | Get-CMASCollectionIncludeMembershipRule -IncludeCollectionName "TEST-*"
```
Retrieves include membership rules for included collections matching "TEST-*" wildcard pattern.

### Example 7: Get include rules for multiple collections
```powershell
"Collection A", "Collection B", "Collection C" | ForEach-Object {
    Get-CMASCollectionIncludeMembershipRule -CollectionName $_
}
```
Retrieves include membership rules from multiple collections.

### Example 8: Find all collections that include a specific collection
```powershell
Get-CMASCollection | ForEach-Object {
    $rules = $_ | Get-CMASCollectionIncludeMembershipRule -IncludeCollectionId "SMS00002"
    if ($rules) {
        [PSCustomObject]@{
            CollectionName = $_.Name
            CollectionID = $_.CollectionID
            IncludeRules = $rules
        }
    }
}
```
Finds all collections that have an include rule for collection SMS00002.

### Example 9: Compare include and exclude rules for a collection
```powershell
$collection = Get-CMASCollection -Name "My Collection"
$includeRules = $collection | Get-CMASCollectionIncludeMembershipRule
$excludeRules = $collection | Get-CMASCollectionExcludeMembershipRule

Write-Host "Include Rules: $(@($includeRules).Count)"
Write-Host "Exclude Rules: $(@($excludeRules).Count)"
```
Displays counts of include and exclude membership rules for a collection.

### Example 10: Get all collections with include rules
```powershell
Get-CMASCollection | Where-Object {
    $rules = $_ | Get-CMASCollectionIncludeMembershipRule
    $null -ne $rules -and @($rules).Count -gt 0
} | Select-Object Name, CollectionID
```
Lists all collections that have at least one include membership rule.

## RELATED LINKS

[Connect-CMAS](Connect-CMAS.md)

[Get-CMASCollection](Get-CMASCollection.md)

[Get-CMASCollectionExcludeMembershipRule](Get-CMASCollectionExcludeMembershipRule.md)

[Get-CMASCollectionDirectMembershipRule](Get-CMASCollectionDirectMembershipRule.md)

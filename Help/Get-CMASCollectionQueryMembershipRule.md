# Get-CMASCollectionQueryMembershipRule

## SYNOPSIS
Retrieves query membership rules from a Configuration Manager collection.

## SYNTAX

### ByName (Default)
```powershell
Get-CMASCollectionQueryMembershipRule -CollectionName <String> [-RuleName <String>] [<CommonParameters>]
```

### ById
```powershell
Get-CMASCollectionQueryMembershipRule -CollectionId <String> [-RuleName <String>] [<CommonParameters>]
```

### ByValue
```powershell
Get-CMASCollectionQueryMembershipRule -InputObject <Object> [-RuleName <String>] [<CommonParameters>]
```

## DESCRIPTION
This function retrieves query membership rules for Configuration Manager collections via the Admin Service API.
You can filter by collection using CollectionName, CollectionId, or by providing a collection object.
Additionally, you can filter the query rules by RuleName.

Query membership rules define WQL queries that dynamically populate collections based on criteria. These rules automatically update collection membership as devices or users meet or no longer meet the query criteria.

## PARAMETERS

### -CollectionName
The name of the collection to retrieve query membership rules from.

```yaml
Type: String
Parameter Sets: ByName
Aliases: Name
Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -CollectionId
The ID of the collection to retrieve query membership rules from.

```yaml
Type: String
Parameter Sets: ById
Aliases: Id
Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -InputObject
A collection object (from Get-CMASCollection) to retrieve query membership rules from.
This parameter accepts pipeline input.

```yaml
Type: Object
Parameter Sets: ByValue
Aliases: Collection
Required: True
Position: Named
Default value: None
Accept pipeline input: True (ByValue)
Accept wildcard characters: False
```

### -RuleName
Optional. Filter query rules to only include rules with this name.
Supports wildcards (* and ?).

```yaml
Type: String
Parameter Sets: All
Aliases: None
Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: True
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### System.Object
You can pipe a collection object from Get-CMASCollection to this cmdlet.

## OUTPUTS

### System.Object
Returns collection query membership rule objects with the following properties:
- CollectionID: The ID of the collection containing the rule
- RuleName: The name of the query rule
- QueryExpression: The WQL query that defines the membership criteria
- QueryID: The unique identifier for the query
- And other properties depending on the rule configuration

## NOTES
- This function is part of the SCCM Admin Service module
- Requires an active connection established via Connect-CMAS
- **IMPORTANT**: The Admin Service does not expose SMS_CollectionRuleQuery as a separate WMI class. This function retrieves the full collection object and extracts query membership rules from the CollectionRules property embedded in the SMS_Collection object. This implementation may be less efficient than the native ConfigurationManager cmdlet for collections with many rules.
- The function filters the CollectionRules property to return only rules where `@odata.type` equals '#AdminService.SMS_CollectionRuleQuery'
- **NOTE**: This function returns QUERY MEMBERSHIP RULES, not query results or collection members
  - Query membership rules define WQL queries that dynamically populate collections
  - Collections can have query rules, include rules, exclude rules, or direct membership rules
  - This cmdlet only returns query membership rules
  - The QueryExpression property contains the WQL query that determines collection membership

## EXAMPLES

### Example 1: Get all query membership rules from a collection by name
```powershell
Get-CMASCollectionQueryMembershipRule -CollectionName "All Systems"
```
Retrieves all query membership rules from the "All Systems" collection.

### Example 2: Get query membership rules from a collection by ID
```powershell
Get-CMASCollectionQueryMembershipRule -CollectionId "SMS00001"
```
Retrieves all query membership rules from the collection with ID SMS00001.

### Example 3: Filter by query rule name
```powershell
Get-CMASCollectionQueryMembershipRule -CollectionName "All Workstations" -RuleName "All Desktop Systems"
```
Retrieves the query membership rule named "All Desktop Systems" from the "All Workstations" collection.

### Example 4: Use wildcards to find query rules
```powershell
Get-CMASCollectionQueryMembershipRule -CollectionId "SMS00001" -RuleName "*Windows*"
```
Retrieves query membership rules matching "*Windows*" wildcard pattern from collection SMS00001.

### Example 5: Use pipeline with Get-CMASCollection
```powershell
Get-CMASCollection -Name "My Collection" | Get-CMASCollectionQueryMembershipRule
```
Retrieves all query membership rules from the piped collection object.

### Example 6: Get query rules for multiple collections
```powershell
"All Systems", "All Servers", "All Workstations" | ForEach-Object {
    Get-CMASCollectionQueryMembershipRule -CollectionName $_
}
```
Retrieves query membership rules from multiple collections.

### Example 7: Examine query expressions
```powershell
Get-CMASCollectionQueryMembershipRule -CollectionName "All Systems" |
    Select-Object RuleName, QueryExpression |
    Format-List
```
Displays the WQL query expressions for all query rules in the "All Systems" collection.

### Example 8: Find collections using specific query criteria
```powershell
Get-CMASCollection | ForEach-Object {
    $rules = $_ | Get-CMASCollectionQueryMembershipRule
    if ($rules) {
        foreach ($rule in $rules) {
            if ($rule.QueryExpression -match "OperatingSystem") {
                [PSCustomObject]@{
                    CollectionName = $_.Name
                    CollectionID = $_.CollectionID
                    RuleName = $rule.RuleName
                    Query = $rule.QueryExpression
                }
            }
        }
    }
}
```
Finds all collections with query rules that reference OperatingSystem in their WQL query.

### Example 9: Count query rules per collection
```powershell
Get-CMASCollection | ForEach-Object {
    $rules = $_ | Get-CMASCollectionQueryMembershipRule
    [PSCustomObject]@{
        CollectionName = $_.Name
        CollectionID = $_.CollectionID
        QueryRuleCount = @($rules).Count
    }
} | Where-Object { $_.QueryRuleCount -gt 0 } | Sort-Object QueryRuleCount -Descending
```
Creates a report showing collections sorted by the number of query rules they contain.

### Example 10: Compare different rule types for a collection
```powershell
$collection = Get-CMASCollection -Name "My Collection"

$queryRules = $collection | Get-CMASCollectionQueryMembershipRule
$includeRules = $collection | Get-CMASCollectionIncludeMembershipRule
$excludeRules = $collection | Get-CMASCollectionExcludeMembershipRule
$directRules = $collection | Get-CMASCollectionDirectMembershipRule

Write-Host "Collection: $($collection.Name)"
Write-Host "  Query Rules: $(@($queryRules).Count)"
Write-Host "  Include Rules: $(@($includeRules).Count)"
Write-Host "  Exclude Rules: $(@($excludeRules).Count)"
Write-Host "  Direct Rules: $(@($directRules).Count)"
```
Displays a summary of all membership rule types for a collection.

## RELATED LINKS

[Connect-CMAS](Connect-CMAS.md)

[Get-CMASCollection](Get-CMASCollection.md)

[Get-CMASCollectionIncludeMembershipRule](Get-CMASCollectionIncludeMembershipRule.md)

[Get-CMASCollectionExcludeMembershipRule](Get-CMASCollectionExcludeMembershipRule.md)

[Get-CMASCollectionDirectMembershipRule](Get-CMASCollectionDirectMembershipRule.md)

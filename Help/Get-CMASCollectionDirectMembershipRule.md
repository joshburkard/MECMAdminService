# Get-CMASCollectionDirectMembershipRule

## SYNOPSIS
Retrieves direct membership rules from a Configuration Manager collection.

## SYNTAX

### ByName (Default)
```powershell
Get-CMASCollectionDirectMembershipRule -CollectionName <String> [-ResourceName <String>] [-ResourceId <Int64>] [<CommonParameters>]
```

### ById
```powershell
Get-CMASCollectionDirectMembershipRule -CollectionId <String> [-ResourceName <String>] [-ResourceId <Int64>] [<CommonParameters>]
```

### ByValue
```powershell
Get-CMASCollectionDirectMembershipRule -InputObject <Object> [-ResourceName <String>] [-ResourceId <Int64>] [<CommonParameters>]
```

### ByNameAndName
```powershell
Get-CMASCollectionDirectMembershipRule -CollectionName <String> -ResourceName <String> [<CommonParameters>]
```

### ByNameAndId
```powershell
Get-CMASCollectionDirectMembershipRule -CollectionName <String> -ResourceId <Int64> [<CommonParameters>]
```

### ByIdAndName
```powershell
Get-CMASCollectionDirectMembershipRule -CollectionId <String> -ResourceName <String> [<CommonParameters>]
```

### ByIdAndId
```powershell
Get-CMASCollectionDirectMembershipRule -CollectionId <String> -ResourceId <Int64> [<CommonParameters>]
```

### ByValueAndName
```powershell
Get-CMASCollectionDirectMembershipRule -InputObject <Object> -ResourceName <String> [<CommonParameters>]
```

### ByValueAndId
```powershell
Get-CMASCollectionDirectMembershipRule -InputObject <Object> -ResourceId <Int64> [<CommonParameters>]
```

## DESCRIPTION
This function retrieves direct membership rules for Configuration Manager collections via the Admin Service API.
You can filter by collection using CollectionName, CollectionId, or by providing a collection object.
Additionally, you can filter the membership rules by ResourceName or ResourceId.

Direct membership rules explicitly add individual devices or users to a collection, as opposed to query-based or include/exclude rules.

## PARAMETERS

### -CollectionName
The name of the collection to retrieve direct membership rules from.

```yaml
Type: String
Parameter Sets: ByName, ByNameAndName, ByNameAndId
Aliases: Name
Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -CollectionId
The ID of the collection to retrieve direct membership rules from.

```yaml
Type: String
Parameter Sets: ById, ByIdAndName, ByIdAndId
Aliases: Id
Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -InputObject
A collection object (from Get-CMASCollection) to retrieve direct membership rules from.
This parameter accepts pipeline input.

```yaml
Type: Object
Parameter Sets: ByValue, ByValueAndName, ByValueAndId
Aliases: Collection
Required: True
Position: Named
Default value: None
Accept pipeline input: True (ByValue)
Accept wildcard characters: False
```

### -ResourceName
Optional. Filter membership rules to only include rules for resources with this name.
Supports wildcards (* and ?).

```yaml
Type: String
Parameter Sets: ByName, ById, ByValue, ByNameAndName, ByIdAndName, ByValueAndName
Aliases: None
Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: True
```

### -ResourceId
Optional. Filter membership rules to only include rules for the resource with this ID.

```yaml
Type: Int64
Parameter Sets: ByName, ById, ByValue, ByNameAndId, ByIdAndId, ByValueAndId
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
Returns collection direct membership rule objects with the following properties:
- CollectionID: The ID of the collection
- ResourceID: The resource ID of the member
- RuleName: The name of the resource (typically the device or user name)
- ResourceClassName: The WMI class name of the resource
- And other properties depending on the rule configuration

## NOTES
- This function is part of the SCCM Admin Service module
- Requires an active connection established via Connect-CMAS
- **IMPORTANT**: The Admin Service does not expose SMS_CollectionRuleDirect as a separate WMI class. This function retrieves the full collection object and extracts direct membership rules from the CollectionRules property embedded in the SMS_Collection object. This implementation may be less efficient than the native ConfigurationManager cmdlet for collections with many rules.
- The function filters the CollectionRules property to return only rules where `@odata.type` equals '#AdminService.SMS_CollectionRuleDirect'
- **NOTE**: This function returns DIRECT MEMBERSHIP RULES, not collection members
  - Direct membership rules explicitly add specific devices/users to a collection
  - A collection with 1000 members might have 0 direct membership rules if it uses query-based rules instead
  - Collections can have query rules, include rules, exclude rules, or direct membership rules
  - This cmdlet only returns direct membership rules

## EXAMPLES

### Example 1: Get all direct membership rules from a collection by name
```powershell
Get-CMASCollectionDirectMembershipRule -CollectionName "All Systems"
```
Retrieves all direct membership rules from the "All Systems" collection.

### Example 2: Get direct membership rules from a collection by ID
```powershell
Get-CMASCollectionDirectMembershipRule -CollectionId "SMS00001"
```
Retrieves all direct membership rules from the collection with ID SMS00001.

### Example 3: Filter by resource name
```powershell
Get-CMASCollectionDirectMembershipRule -CollectionName "My Collection" -ResourceName "Server01"
```
Retrieves direct membership rules from "My Collection" for a resource named "Server01".

### Example 4: Filter by resource ID
```powershell
Get-CMASCollectionDirectMembershipRule -CollectionName "My Collection" -ResourceId 16777220
```
Retrieves the direct membership rule for resource ID 16777220 in "My Collection".

### Example 5: Use pipeline input
```powershell
Get-CMASCollection -Name "My Collection" | Get-CMASCollectionDirectMembershipRule
```
Retrieves all direct membership rules from the piped collection object.

### Example 6: Use wildcards in resource name
```powershell
Get-CMASCollection -Name "My Collection" | Get-CMASCollectionDirectMembershipRule -ResourceName "TEST-*"
```
Retrieves direct membership rules for resources matching the "TEST-*" wildcard pattern.

### Example 7: Get rules for multiple collections
```powershell
"Collection A", "Collection B", "Collection C" | ForEach-Object {
    Get-CMASCollectionDirectMembershipRule -CollectionName $_
}
```
Retrieves direct membership rules from multiple collections.

## RELATED LINKS

[Connect-CMAS](Connect-CMAS.md)

[Get-CMASCollection](Get-CMASCollection.md)

[Get-CMASDevice](Get-CMASDevice.md)

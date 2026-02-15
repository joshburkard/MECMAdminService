# Get-CMASCollectionMember

## SYNOPSIS
Retrieves members of a Configuration Manager collection via the Admin Service.

## SYNTAX

### ByCollectionName (Default)
```powershell
Get-CMASCollectionMember [-CollectionName] <String> [-ResourceName <String>] [-ResourceId <Int64>] [<CommonParameters>]
```

### ByCollectionId
```powershell
Get-CMASCollectionMember [-CollectionId] <String> [-ResourceName <String>] [-ResourceId <Int64>] [<CommonParameters>]
```

### ByInputObject
```powershell
Get-CMASCollectionMember -InputObject <Object> [-ResourceName <String>] [-ResourceId <Int64>] [<CommonParameters>]
```

## DESCRIPTION
This function retrieves collection members using the Admin Service SMS_FullCollectionMembership WMI class. You can specify the target collection by name, CollectionID, or by piping a collection object from Get-CMASCollection. Optional filters allow narrowing results by resource name or resource ID.

Wildcard filters for ResourceName are applied client-side after retrieval.

## PARAMETERS

### -CollectionName
The name of the collection to retrieve members from.

```yaml
Type: String
Parameter Sets: ByCollectionName
Aliases: Name
Required: False
Position: 0
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -CollectionId
The ID of the collection to retrieve members from.

```yaml
Type: String
Parameter Sets: ByCollectionId
Aliases: Id
Required: False
Position: 0
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -InputObject
A collection object (from Get-CMASCollection) to retrieve members from. This parameter accepts pipeline input.

```yaml
Type: Object
Parameter Sets: ByInputObject
Aliases: Collection
Required: True
Position: Named
Default value: None
Accept pipeline input: True (ByInputObject)
Accept wildcard characters: False
```

### -ResourceName
Optional. Filter members to only include resources with this name. Supports wildcard patterns (* and ?).

```yaml
Type: String
Parameter Sets: (All)
Aliases: None
Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: True
```

### -ResourceId
Optional. Filter members to only include the resource with this ID.

```yaml
Type: Int64
Parameter Sets: (All)
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
Returns collection member objects with properties from SMS_FullCollectionMembership, such as:
- CollectionID
- ResourceID
- Name
- ResourceType
- CollectionName (added by this cmdlet)

## NOTES
- This function is part of the SCCM Admin Service module
- Requires an active connection established via Connect-CMAS
- Wildcard filtering for ResourceName is applied client-side

## EXAMPLES

### Example 1: Get all members for a collection by name
```powershell
Get-CMASCollectionMember -CollectionName "All Systems"
```

### Example 2: Get all members for a collection by ID
```powershell
Get-CMASCollectionMember -CollectionId "SMS00001"
```

### Example 3: Filter members by resource name with wildcard
```powershell
Get-CMASCollectionMember -CollectionName "Test-Collection-Query" -ResourceName "TEST-*"
```

### Example 4: Filter members by resource ID
```powershell
Get-CMASCollectionMember -CollectionId "SMS00001" -ResourceId 16777220
```

### Example 5: Use pipeline input
```powershell
Get-CMASCollection -Name "All Systems" | Get-CMASCollectionMember
```

### Example 6: Export members to CSV
```powershell
Get-CMASCollectionMember -CollectionName "All Systems" |
    Select-Object CollectionName, Name, ResourceID |
    Export-Csv -Path "C:\Temp\CollectionMembers.csv" -NoTypeInformation
```

## RELATED LINKS

[Connect-CMAS](Connect-CMAS.md)

[Get-CMASCollection](Get-CMASCollection.md)

[Get-CMASDevice](Get-CMASDevice.md)

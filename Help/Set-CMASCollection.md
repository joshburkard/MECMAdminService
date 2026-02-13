# Set-CMASCollection

## SYNOPSIS
Modifies properties of a Configuration Manager collection via the Admin Service.

## SYNTAX

### ByName
```powershell
Set-CMASCollection -CollectionName <String> [-NewName <String>] [-Comment <String>] [-RefreshType <String>]
 [-RefreshSchedule <Hashtable>] [-LimitingCollectionId <String>] [-LimitingCollectionName <String>]
 [-PassThru] [-WhatIf] [-Confirm] [<CommonParameters>]
```

### ById
```powershell
Set-CMASCollection -CollectionId <String> [-NewName <String>] [-Comment <String>] [-RefreshType <String>]
 [-RefreshSchedule <Hashtable>] [-LimitingCollectionId <String>] [-LimitingCollectionName <String>]
 [-PassThru] [-WhatIf] [-Confirm] [<CommonParameters>]
```

### ByValue
```powershell
Set-CMASCollection -InputObject <Object> [-NewName <String>] [-Comment <String>] [-RefreshType <String>]
 [-RefreshSchedule <Hashtable>] [-LimitingCollectionId <String>] [-LimitingCollectionName <String>]
 [-PassThru] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
This function updates an existing device or user collection in Configuration Manager using the Admin Service API. You can modify collection properties such as name, comment, refresh type, and refresh schedule.

The function supports updating various collection properties:
- **Name**: Change the collection name
- **Comment**: Add or modify the collection description
- **RefreshType**: Change between Manual, Periodic, Continuous, or Both
- **RefreshSchedule**: Update the schedule for periodic updates
- **LimitingCollectionId/Name**: Change the limiting collection (use with caution)

The function uses the Admin Service REST API to PATCH the SMS_Collection WMI class instance.

## PARAMETERS

### -CollectionName
The current name of the collection to modify.

```yaml
Type: String
Parameter Sets: ByName, ById, ByValue
Aliases: Name
Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -CollectionId
The ID of the collection to modify.

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
A collection object (from Get-CMASCollection) to modify. This parameter accepts pipeline input.

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

### -NewName
The new name for the collection. Must be unique within Configuration Manager.

```yaml
Type: String
Parameter Sets: (All)
Aliases:
Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Comment
The new comment or description for the collection. Pass empty string to clear the comment.

```yaml
Type: String
Parameter Sets: (All)
Aliases:
Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -RefreshType
The new refresh type for the collection:
- Manual (1): Manual updates only
- Periodic (2): Scheduled updates
- Continuous (4): Incremental updates (continuous evaluation)
- Both (6): Periodic and Continuous (2 + 4)

```yaml
Type: String
Parameter Sets: (All)
Aliases:
Accepted values: Manual, Periodic, Continuous, Both, 1, 2, 4, 6
Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -RefreshSchedule
The new schedule for periodic updates (used when RefreshType includes Periodic). Must be a valid SMS_ST_RecurInterval schedule hashtable.

Example: For daily updates starting Feb 14, 2025 - @{DaySpan=1; StartTime="2025-02-14T00:00:00Z"}

**NOTE:** RefreshSchedule updates are currently NOT supported via Admin Service REST API. Setting this parameter may result in a 500 Internal Server Error. Use the ConfigurationManager PowerShell module for schedule management.

```yaml
Type: Hashtable
Parameter Sets: (All)
Aliases:
Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -LimitingCollectionId
The CollectionID of the new limiting collection. Use with caution as this can affect membership.

```yaml
Type: String
Parameter Sets: ByName, ById, ByValue
Aliases:
Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -LimitingCollectionName
The name of the new limiting collection. The function will look up the CollectionID automatically.

```yaml
Type: String
Parameter Sets: ByName, ById, ByValue
Aliases:
Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -PassThru
Returns the updated collection object.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
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

### System.Object
You can pipe a collection object from Get-CMASCollection to this cmdlet.

## OUTPUTS

### System.Object
When using the -PassThru parameter, returns the updated collection object with all properties including:
- Name
- CollectionID
- CollectionType
- LimitToCollectionID
- RefreshType
- Comment
- RefreshSchedule

## NOTES

**Author:** SCCM Admin Service Module

**Requirements:**
- An active connection to the SCCM Admin Service (established via Connect-CMAS)
- Appropriate permissions to modify collections in Configuration Manager

**Refresh Types:**
- 1 = Manual only
- 2 = Scheduled (Periodic) only
- 4 = Incremental (Continuous) only
- 6 = Scheduled and Incremental (Both)

**Important:**
- At least one property to update must be specified (NewName, Comment, RefreshType, RefreshSchedule, or LimitingCollection)
- Collection names must be unique across all collections in Configuration Manager
- Changing the limiting collection can cause members to be removed if they don't match the new limiting collection
- When changing RefreshType to/from Periodic, ensure RefreshSchedule is set appropriately

The function uses ShouldProcess for confirmation, supporting -WhatIf and -Confirm parameters. This is useful for testing changes before applying them.

## EXAMPLES

### Example 1: Update collection name
```powershell
PS C:\> Set-CMASCollection -CollectionName "Old Name" -NewName "New Name"
```

Renames a collection from "Old Name" to "New Name".

### Example 2: Update collection comment with PassThru
```powershell
PS C:\> Set-CMASCollection -CollectionId "SMS00100" -Comment "Updated description" -PassThru
```

Updates the collection comment and returns the updated collection object.

### Example 3: Update refresh type and comment
```powershell
PS C:\> Set-CMASCollection -CollectionName "My Collection" -RefreshType Continuous -Comment "Auto-updating collection"
```

Changes the refresh type to continuous and updates the comment.

### Example 4: Update with a custom schedule
```powershell
PS C:\> $schedule = @{DaySpan=1; StartTime="20250213000000.000000+***"}
PS C:\> Set-CMASCollection -CollectionName "Daily Collection" -RefreshType Periodic -RefreshSchedule $schedule
```

Updates the collection to use a daily periodic refresh schedule.

### Example 5: Update collections via pipeline
```powershell
PS C:\> Get-CMASCollection -Name "Test*" | Set-CMASCollection -Comment "Test collection" -RefreshType Manual
```

Updates all collections starting with "Test" to have a comment and manual refresh type.

### Example 6: Update multiple properties at once
```powershell
PS C:\> Set-CMASCollection -CollectionName "My Collection" -NewName "Renamed Collection" -RefreshType Both -PassThru
```

Updates both the name and refresh type in a single operation, returning the updated collection.

### Example 7: Use WhatIf to preview changes
```powershell
PS C:\> Set-CMASCollection -CollectionName "Collection A" -LimitingCollectionName "All Systems" -WhatIf
```

Shows what would happen if the limiting collection were changed, without actually changing it.

### Example 8: Clear collection comment
```powershell
PS C:\> Set-CMASCollection -CollectionId "SMS00100" -Comment ""
```

Clears the comment from the collection by setting it to an empty string.

### Example 9: Update limiting collection by ID
```powershell
PS C:\> Set-CMASCollection -CollectionName "Restricted Collection" -LimitingCollectionId "SMS00001"
```

Changes the limiting collection to "All Systems" (SMS00001).

### Example 10: Update by collection object
```powershell
PS C:\> $collection = Get-CMASCollection -Name "My Collection"
PS C:\> $collection | Set-CMASCollection -Comment "Updated via object" -RefreshType Continuous
```

Retrieves a collection object and updates it via pipeline input.

## RELATED LINKS

[Connect-CMAS](Connect-CMAS.md)

[Get-CMASCollection](Get-CMASCollection.md)

[New-CMASCollection](New-CMASCollection.md)

[Remove-CMASCollection](Remove-CMASCollection.md)

[Add-CMASCollectionMembershipRule](Add-CMASCollectionMembershipRule.md)

[Remove-CMASCollectionMembershipRule](Remove-CMASCollectionMembershipRule.md)

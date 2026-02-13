# New-CMASCollection

## SYNOPSIS
Creates a new Configuration Manager collection via the Admin Service.

## SYNTAX

### ByLimitingId
```powershell
New-CMASCollection -Name <String> [-CollectionType <String>] -LimitingCollectionId <String> [-Comment <String>]
 [-RefreshType <String>] [-RefreshSchedule <Hashtable>] [-PassThru] [-WhatIf] [-Confirm] [<CommonParameters>]
```

### ByLimitingName
```powershell
New-CMASCollection -Name <String> [-CollectionType <String>] -LimitingCollectionName <String> [-Comment <String>]
 [-RefreshType <String>] [-RefreshSchedule <Hashtable>] [-PassThru] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
This function creates a new device or user collection in Configuration Manager using the Admin Service API. You can specify collection properties such as name, type, limiting collection, refresh schedule, and comments.

The function supports creating both device and user collections with various refresh types:
- **Manual**: Collection membership is only updated manually
- **Periodic**: Collection membership is updated on a schedule
- **Continuous**: Collection membership is continuously evaluated (incremental updates)
- **Both**: Combination of Periodic and Continuous refresh

The function uses the Admin Service REST API to POST to the SMS_Collection WMI class. Collection names must be unique across all collections in Configuration Manager.

## PARAMETERS

### -Name
The name of the new collection to create. Must be unique within Configuration Manager.

```yaml
Type: String
Parameter Sets: ByLimitingId, ByLimitingName
Aliases:
Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -CollectionType
The type of collection to create: Device or User.
- Device (2): Creates a device collection (default)
- User (1): Creates a user collection

```yaml
Type: String
Parameter Sets: ByLimitingId, ByLimitingName
Aliases:
Accepted values: Device, User, 1, 2
Required: False
Position: Named
Default value: Device
Accept pipeline input: False
Accept wildcard characters: False
```

### -LimitingCollectionId
The CollectionID of the limiting collection. The new collection can only contain members of this limiting collection. For device collections, typically "SMS00001" (All Systems).

```yaml
Type: String
Parameter Sets: ByLimitingId
Aliases:
Required: True (for ByLimitingId parameter set)
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -LimitingCollectionName
The name of the limiting collection. If specified, the function will look up the CollectionID automatically. Either LimitingCollectionId or LimitingCollectionName must be provided.

```yaml
Type: String
Parameter Sets: ByLimitingName
Aliases:
Required: True (for ByLimitingName parameter set)
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Comment
Optional comment or description for the collection.

```yaml
Type: String
Parameter Sets: ByLimitingId, ByLimitingName
Aliases:
Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -RefreshType
The refresh type for the collection:
- Manual (1): Manual updates only
- Periodic (2): Scheduled updates
- Continuous (4): Incremental updates (continuous evaluation)
- Both (6): Periodic and Continuous (2 + 4)

Default is Manual.

```yaml
Type: String
Parameter Sets: ByLimitingId, ByLimitingName
Aliases:
Accepted values: Manual, Periodic, Continuous, Both, 1, 2, 4, 6
Required: False
Position: Named
Default value: Manual
Accept pipeline input: False
Accept wildcard characters: False
```

### -RefreshSchedule
Optional. The schedule for periodic updates (used when RefreshType includes Periodic). Must be a valid SMS_ST_RecurInterval schedule hashtable.

Example: For daily updates - @{DaySpan=1; StartTime="20250213000000.000000+***"}

```yaml
Type: Hashtable
Parameter Sets: ByLimitingId, ByLimitingName
Aliases:
Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -PassThru
Returns the created collection object.

```yaml
Type: SwitchParameter
Parameter Sets: ByLimitingId, ByLimitingName
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

### None
This function does not accept pipeline input.

## OUTPUTS

### System.Object
When using the -PassThru parameter, returns the created collection object with properties including:
- Name
- CollectionID
- CollectionType
- LimitToCollectionID
- RefreshType
- Comment

## NOTES

**Author:** SCCM Admin Service Module

**Requirements:**
- An active connection to the SCCM Admin Service (established via Connect-CMAS)
- Appropriate permissions to create collections in Configuration Manager

**Collection Types:**
- 0 = Other
- 1 = User
- 2 = Device (default)

**Refresh Types:**
- 1 = Manual only
- 2 = Scheduled (Periodic) only
- 4 = Incremental (Continuous) only
- 6 = Scheduled and Incremental (Both)

**Important:**
- Collection names must be unique across all collections in Configuration Manager
- The new collection can only contain members that are also in the limiting collection
- For device collections, "SMS00001" (All Systems) is typically used as the limiting collection
- For user collections, "SMS00002" (All Users) is typically used as the limiting collection

## EXAMPLES

### Example 1: Create a basic device collection
```powershell
PS C:\> New-CMASCollection -Name "My Device Collection" -LimitingCollectionName "All Systems"
```

Creates a new device collection with manual refresh, limited to All Systems.

### Example 2: Create a collection with periodic refresh
```powershell
PS C:\> New-CMASCollection -Name "Test Servers" -LimitingCollectionId "SMS00001" -RefreshType Periodic -Comment "Test environment servers"
```

Creates a device collection with periodic refresh and a comment.

### Example 3: Create a user collection
```powershell
PS C:\> New-CMASCollection -Name "My Users" -CollectionType User -LimitingCollectionName "All Users" -RefreshType Continuous
```

Creates a user collection with continuous (incremental) updates.

### Example 4: Create a collection and return the object
```powershell
PS C:\> $newCollection = New-CMASCollection -Name "Production Servers" -LimitingCollectionId "SMS00001" -RefreshType Both -PassThru
PS C:\> $newCollection.CollectionID
```

Creates a device collection with both periodic and continuous refresh, returning the collection object.

### Example 5: Create a collection with a custom schedule
```powershell
PS C:\> $schedule = @{
    DaySpan = 1
    StartTime = (Get-Date).AddHours(1).ToString("yyyyMMddHHmmss.000000+***")
}
PS C:\> New-CMASCollection -Name "Scheduled Collection" -LimitingCollectionName "All Systems" -RefreshType Periodic -RefreshSchedule $schedule
```

Creates a collection with a custom daily refresh schedule starting in one hour.

### Example 6: Use WhatIf to preview collection creation
```powershell
PS C:\> New-CMASCollection -Name "Test Collection" -LimitingCollectionId "SMS00001" -WhatIf
```

Shows what would happen if the collection were created, without actually creating it.

### Example 7: Create multiple collections with different properties
```powershell
PS C:\> $collections = @(
    @{Name="Workstations - Finance"; Type="Device"; RefreshType="Continuous"}
    @{Name="Workstations - HR"; Type="Device"; RefreshType="Continuous"}
    @{Name="Workstations - IT"; Type="Device"; RefreshType="Both"}
)
PS C:\> foreach ($col in $collections) {
    New-CMASCollection -Name $col.Name -CollectionType $col.Type -LimitingCollectionName "All Systems" -RefreshType $col.RefreshType
}
```

Creates multiple device collections with different refresh types in a loop.

### Example 8: Create a collection with verbose output
```powershell
PS C:\> New-CMASCollection -Name "Debug Collection" -LimitingCollectionId "SMS00001" -Verbose
```

Creates a collection with verbose output showing each step of the process.

## RELATED LINKS

[Connect-CMAS](Connect-CMAS.md)

[Get-CMASCollection](Get-CMASCollection.md)

[Add-CMASCollectionMembershipRule](Add-CMASCollectionMembershipRule.md)

[Remove-CMASCollectionMembershipRule](Remove-CMASCollectionMembershipRule.md)

[Get-CMASCollectionDirectMembershipRule](Get-CMASCollectionDirectMembershipRule.md)

[Get-CMASCollectionQueryMembershipRule](Get-CMASCollectionQueryMembershipRule.md)

[Get-CMASCollectionIncludeMembershipRule](Get-CMASCollectionIncludeMembershipRule.md)

[Get-CMASCollectionExcludeMembershipRule](Get-CMASCollectionExcludeMembershipRule.md)

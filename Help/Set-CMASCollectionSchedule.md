# Set-CMASCollectionSchedule

## SYNOPSIS
Sets the refresh schedule for a collection using CIM cmdlets.

## SYNTAX

### ByName
```powershell
Set-CMASCollectionSchedule -CollectionName <String> -RecurInterval <String> -RecurCount <Int32>
 [-StartTime <DateTime>] [-SiteServer <String>] [-SiteCode <String>] [-Credential <PSCredential>]
 [-WhatIf] [-Confirm] [<CommonParameters>]
```

### ById
```powershell
Set-CMASCollectionSchedule -CollectionId <String> -RecurInterval <String> -RecurCount <Int32>
 [-StartTime <DateTime>] [-SiteServer <String>] [-SiteCode <String>] [-Credential <PSCredential>]
 [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
This function uses CIM (WMI) directly to set the refresh schedule for a Configuration Manager collection. This is a workaround for the Admin Service API limitation that doesn't support RefreshSchedule operations.

**REQUIREMENTS**:
- WinRM must be enabled on the SMS Provider server
- You must have permissions to access the SMS Provider via CIM/WMI
- Works in PowerShell 5.1 and PowerShell 7.x

This function creates a schedule token using the same approach as the ConfigurationManager module, but works directly with CIM cmdlets so it's compatible with PowerShell 7.x.

The function automatically sets the collection's RefreshType to 2 (Periodic) when a schedule is configured.

## PARAMETERS

### -CollectionName
The name of the collection to update.

```yaml
Type: String
Parameter Sets: ByName
Aliases:
Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -CollectionId
The ID of the collection to update.

```yaml
Type: String
Parameter Sets: ById
Aliases:
Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -RecurInterval
The interval for recurring schedules. Valid values: Minutes, Hours, Days

```yaml
Type: String
Parameter Sets: (All)
Aliases:
Accepted values: Minutes, Hours, Days
Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -RecurCount
The number of intervals between recurrences (e.g., 1 for daily, 7 for weekly, 4 for every 4 hours).

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:
Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -StartTime
Optional. The start date/time for the schedule. Defaults to current time.

```yaml
Type: DateTime
Parameter Sets: (All)
Aliases:
Required: False
Position: Named
Default value: Current date/time
Accept pipeline input: False
Accept wildcard characters: False
```

### -SiteServer
Optional. The SMS Provider server name. Uses the connected server from Connect-CMAS if not specified.

```yaml
Type: String
Parameter Sets: (All)
Aliases:
Required: False
Position: Named
Default value: From Connect-CMAS
Accept pipeline input: False
Accept wildcard characters: False
```

### -SiteCode
Optional. The site code. Uses the connected site from Connect-CMAS if not specified.

```yaml
Type: String
Parameter Sets: (All)
Aliases:
Required: False
Position: Named
Default value: From Connect-CMAS
Accept pipeline input: False
Accept wildcard characters: False
```

### -Credential
Optional. Credentials for CIM connection. Uses current credentials if not specified.

```yaml
Type: PSCredential
Parameter Sets: (All)
Aliases:
Required: False
Position: Named
Default value: From Connect-CMAS
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

### Example 1: Set daily schedule
```powershell
PS C:\> Set-CMASCollectionSchedule -CollectionName "My Collection" -RecurInterval Days -RecurCount 1
```

Sets the collection to refresh daily starting now.

### Example 2: Set weekly schedule with custom start time
```powershell
PS C:\> Set-CMASCollectionSchedule -CollectionId "SMS00100" -RecurInterval Days -RecurCount 7 -StartTime (Get-Date "2026-02-15 02:00")
```

Sets the collection to refresh weekly starting at 2 AM on Feb 15.

### Example 3: Set hourly schedule
```powershell
PS C:\> Set-CMASCollectionSchedule -CollectionName "Servers" -RecurInterval Hours -RecurCount 4 -Credential $Cred
```

Sets the collection to refresh every 4 hours using specific credentials.

### Example 4: Set minute schedule
```powershell
PS C:\> Set-CMASCollectionSchedule -CollectionName "Test Collection" -RecurInterval Minutes -RecurCount 30
```

Sets the collection to refresh every 30 minutes.

### Example 5: Use explicit site parameters
```powershell
PS C:\> Set-CMASCollectionSchedule -CollectionName "Production Servers" -RecurInterval Days -RecurCount 1 -SiteServer "sccm01.domain.com" -SiteCode "PS1"
```

Sets a daily schedule using explicit site server and site code parameters instead of relying on Connect-CMAS connection.

### Example 6: WhatIf dry run
```powershell
PS C:\> Set-CMASCollectionSchedule -CollectionName "Critical Systems" -RecurInterval Days -RecurCount 1 -WhatIf
```

Shows what would happen without actually making changes.

## NOTES
This function requires WinRM/CIM access to the SMS Provider server. If WinRM is not available, use the SCCM Console or ConfigurationManager PowerShell module instead.

The function automatically sets the collection's RefreshType to 2 (Periodic) when configuring a schedule.

This CIM-based approach is necessary because the Admin Service REST API does not support RefreshSchedule create/update operations. Unlike the old WMI cmdlets (Get-WmiObject), CIM cmdlets work in both PowerShell 5.1 and PowerShell 7.x.

## RELATED LINKS

[Set-CMASCollection](Set-CMASCollection.md)

[Connect-CMAS](Connect-CMAS.md)

[Get-CMASCollection](Get-CMASCollection.md)

[New-CMASCollection](New-CMASCollection.md)

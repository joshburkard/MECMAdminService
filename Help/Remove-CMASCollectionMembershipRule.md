# Remove-CMASCollectionMembershipRule

## SYNOPSIS
Removes a membership rule from a Configuration Manager collection.

## SYNTAX

### ByNameDirect
```powershell
Remove-CMASCollectionMembershipRule -CollectionName <String> -RuleType <String> [-ResourceId <Int64[]>]
 [-ResourceName <String>] [-Force] [-PassThru] [-WhatIf] [-Confirm] [<CommonParameters>]
```

### ByIdDirect
```powershell
Remove-CMASCollectionMembershipRule -CollectionId <String> -RuleType <String> [-ResourceId <Int64[]>]
 [-ResourceName <String>] [-Force] [-PassThru] [-WhatIf] [-Confirm] [<CommonParameters>]
```

### ByValueDirect
```powershell
Remove-CMASCollectionMembershipRule -InputObject <Object> -RuleType <String> [-ResourceId <Int64[]>]
 [-ResourceName <String>] [-Force] [-PassThru] [-WhatIf] [-Confirm] [<CommonParameters>]
```

### ByNameQuery
```powershell
Remove-CMASCollectionMembershipRule -CollectionName <String> -RuleType <String> [-RuleName <String>]
 [-Force] [-PassThru] [-WhatIf] [-Confirm] [<CommonParameters>]
```

### ByIdQuery
```powershell
Remove-CMASCollectionMembershipRule -CollectionId <String> -RuleType <String> [-RuleName <String>]
 [-Force] [-PassThru] [-WhatIf] [-Confirm] [<CommonParameters>]
```

### ByValueQuery
```powershell
Remove-CMASCollectionMembershipRule -InputObject <Object> -RuleType <String> [-RuleName <String>]
 [-Force] [-PassThru] [-WhatIf] [-Confirm] [<CommonParameters>]
```

### ByNameInclude
```powershell
Remove-CMASCollectionMembershipRule -CollectionName <String> -RuleType <String> [-IncludeCollectionId <String>]
 [-IncludeCollectionName <String>] [-Force] [-PassThru] [-WhatIf] [-Confirm] [<CommonParameters>]
```

### ByIdInclude
```powershell
Remove-CMASCollectionMembershipRule -CollectionId <String> -RuleType <String> [-IncludeCollectionId <String>]
 [-IncludeCollectionName <String>] [-Force] [-PassThru] [-WhatIf] [-Confirm] [<CommonParameters>]
```

### ByValueInclude
```powershell
Remove-CMASCollectionMembershipRule -InputObject <Object> -RuleType <String> [-IncludeCollectionId <String>]
 [-IncludeCollectionName <String>] [-Force] [-PassThru] [-WhatIf] [-Confirm] [<CommonParameters>]
```

### ByNameExclude
```powershell
Remove-CMASCollectionMembershipRule -CollectionName <String> -RuleType <String> [-ExcludeCollectionId <String>]
 [-ExcludeCollectionName <String>] [-Force] [-PassThru] [-WhatIf] [-Confirm] [<CommonParameters>]
```

### ByIdExclude
```powershell
Remove-CMASCollectionMembershipRule -CollectionId <String> -RuleType <String> [-ExcludeCollectionId <String>]
 [-ExcludeCollectionName <String>] [-Force] [-PassThru] [-WhatIf] [-Confirm] [<CommonParameters>]
```

### ByValueExclude
```powershell
Remove-CMASCollectionMembershipRule -InputObject <Object> -RuleType <String> [-ExcludeCollectionId <String>]
 [-ExcludeCollectionName <String>] [-Force] [-PassThru] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
This function removes membership rules from Configuration Manager collections via the Admin Service API.
Supports removing Direct, Query, Include, and Exclude membership rules.

- **Direct rules**: Remove specific devices/users by ResourceID or ResourceName
- **Query rules**: Remove dynamic membership based on rule name
- **Include rules**: Remove include rules by collection name or ID
- **Exclude rules**: Remove exclude rules by collection name or ID

The function uses the DeleteMembershipRule WMI method to remove each rule. It first retrieves the rule objects using the appropriate Get-CMASCollection*MembershipRule function, then calls the delete method for each matching rule.

Wildcard support allows removing multiple rules in a single operation. When using wildcards without the `-Force` parameter, confirmation will be requested for each rule.

## PARAMETERS

### -CollectionName
The name of the collection to remove the membership rule from.

```yaml
Type: String
Parameter Sets: ByNameDirect, ByNameQuery, ByNameInclude, ByNameExclude
Aliases: Name
Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -CollectionId
The ID of the collection to remove the membership rule from.

```yaml
Type: String
Parameter Sets: ByIdDirect, ByIdQuery, ByIdInclude, ByIdExclude
Aliases: Id
Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -InputObject
A collection object (from Get-CMASCollection) to remove the membership rule from.
This parameter accepts pipeline input.

```yaml
Type: Object
Parameter Sets: ByValueDirect, ByValueQuery, ByValueInclude, ByValueExclude
Aliases: Collection
Required: True
Position: Named
Default value: None
Accept pipeline input: True (ByValue)
Accept wildcard characters: False
```

### -RuleType
The type of membership rule to remove. Valid values are:
- **Direct**: Remove specific devices/users by ResourceID or ResourceName
- **Query**: Remove dynamic membership based on rule name
- **Include**: Remove include rules by collection name or ID
- **Exclude**: Remove exclude rules by collection name or ID

```yaml
Type: String
Parameter Sets: (All)
Aliases: None
Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ResourceId
The ResourceID of the device/user to remove (for Direct rules).
Can be an array to remove multiple resources.

```yaml
Type: Int64[]
Parameter Sets: ByNameDirect, ByIdDirect, ByValueDirect
Aliases: None
Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ResourceName
The name of the device/user to remove (for Direct rules).
Supports wildcards (e.g., "TEST-*") to remove multiple matching rules.

```yaml
Type: String
Parameter Sets: ByNameDirect, ByIdDirect, ByValueDirect
Aliases: None
Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: True
```

### -RuleName
The name of the query membership rule to remove (for Query rules).
Supports wildcards (e.g., "*Test*") to remove multiple matching rules.

```yaml
Type: String
Parameter Sets: ByNameQuery, ByIdQuery, ByValueQuery
Aliases: None
Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: True
```

### -IncludeCollectionId
The CollectionID to remove from include rules (for Include rules).

```yaml
Type: String
Parameter Sets: ByNameInclude, ByIdInclude, ByValueInclude
Aliases: None
Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -IncludeCollectionName
The name of the collection to remove from include rules (for Include rules).
Supports wildcards (e.g., "Test-*") to remove multiple matching rules.

```yaml
Type: String
Parameter Sets: ByNameInclude, ByIdInclude, ByValueInclude
Aliases: None
Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: True
```

### -ExcludeCollectionId
The CollectionID to remove from exclude rules (for Exclude rules).

```yaml
Type: String
Parameter Sets: ByNameExclude, ByIdExclude, ByValueExclude
Aliases: None
Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ExcludeCollectionName
The name of the collection to remove from exclude rules (for Exclude rules).
Supports wildcards (e.g., "Test-*") to remove multiple matching rules.

```yaml
Type: String
Parameter Sets: ByNameExclude, ByIdExclude, ByValueExclude
Aliases: None
Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: True
```

### -Force
Skip confirmation prompts. Useful when removing multiple rules with wildcards.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: None
Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -PassThru
Returns the updated collection object after removing the rule(s).

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: None
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
When using the `-PassThru` parameter, returns the updated collection object.

## EXAMPLES

### Example 1: Remove a direct membership rule by ResourceID
```powershell
Remove-CMASCollectionMembershipRule -CollectionName "All Systems" -RuleType Direct -ResourceId 16777220
```

Removes the direct membership rule for resource ID 16777220 from the "All Systems" collection.

### Example 2: Remove a direct membership rule by ResourceName
```powershell
Remove-CMASCollectionMembershipRule -CollectionId "SMS00001" -RuleType Direct -ResourceName "SERVER01" -Force
```

Removes the direct membership rule for the device named "SERVER01" from collection SMS00001 without confirmation.

### Example 3: Remove a query membership rule
```powershell
Remove-CMASCollectionMembershipRule -CollectionName "Test Collection" -RuleType Query -RuleName "Test Servers"
```

Removes the query membership rule named "Test Servers" from "Test Collection".

### Example 4: Remove all query rules matching a wildcard pattern
```powershell
Remove-CMASCollectionMembershipRule -CollectionName "Test Collection" -RuleType Query -RuleName "*Test*" -Force
```

Removes all query membership rules containing "Test" in their name without confirmation.

### Example 5: Remove an include membership rule
```powershell
Remove-CMASCollectionMembershipRule -CollectionName "Production Servers" -RuleType Include -IncludeCollectionName "All Servers"
```

Removes the include rule for "All Servers" collection from "Production Servers".

### Example 6: Remove an exclude membership rule
```powershell
Remove-CMASCollectionMembershipRule -CollectionName "Workstations" -RuleType Exclude -ExcludeCollectionName "Test Devices"
```

Removes the exclude rule for "Test Devices" collection from "Workstations".

### Example 7: Remove multiple direct membership rules via pipeline
```powershell
Get-CMASCollection -Name "My Collection" | Remove-CMASCollectionMembershipRule -RuleType Direct -ResourceId @(16777220, 16777221) -Force
```

Removes multiple direct membership rules from the piped collection object without confirmation.

### Example 8: Remove all direct membership rules for devices with wildcard pattern
```powershell
Remove-CMASCollectionMembershipRule -CollectionName "Test Collection" -RuleType Direct -ResourceName "TEST-*" -Force
```

Removes all direct membership rules for devices whose names start with "TEST-" without confirmation.

### Example 9: Remove a rule and return the updated collection
```powershell
$collection = Remove-CMASCollectionMembershipRule -CollectionName "My Collection" -RuleType Query -RuleName "Old Rule" -PassThru -Force
$collection.CollectionRules.Count
```

Removes a query rule and returns the updated collection object to verify the removal.

### Example 10: Use WhatIf to preview removal
```powershell
Remove-CMASCollectionMembershipRule -CollectionName "Production" -RuleType Direct -ResourceName "SERVER-*" -WhatIf
```

Shows what direct membership rules would be removed without actually removing them.

## NOTES
This function is part of the SCCM Admin Service module.
Requires an active connection established via Connect-CMAS.

The Admin Service uses the DeleteMembershipRule WMI method on the SMS_Collection class to remove membership rules. This function retrieves the rule objects first using the appropriate Get-CMASCollection*MembershipRule function, then calls the delete method via POST for each rule to remove.

When using wildcards, the function will prompt for confirmation before removing each rule unless -Force is specified.

The function has a ConfirmImpact of 'High', meaning it will prompt for confirmation by default unless -Confirm:$false or -Force is specified.

## RELATED LINKS

[Connect-CMAS](Connect-CMAS.md)

[Get-CMASCollection](Get-CMASCollection.md)

[Add-CMASCollectionMembershipRule](Add-CMASCollectionMembershipRule.md)

[Get-CMASCollectionDirectMembershipRule](Get-CMASCollectionDirectMembershipRule.md)

[Get-CMASCollectionQueryMembershipRule](Get-CMASCollectionQueryMembershipRule.md)

[Get-CMASCollectionIncludeMembershipRule](Get-CMASCollectionIncludeMembershipRule.md)

[Get-CMASCollectionExcludeMembershipRule](Get-CMASCollectionExcludeMembershipRule.md)

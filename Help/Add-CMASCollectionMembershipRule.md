# Add-CMASCollectionMembershipRule

## SYNOPSIS
Adds a membership rule to a Configuration Manager collection.

## SYNTAX

### ByNameDirect
```powershell
Add-CMASCollectionMembershipRule -CollectionName <String> -RuleType <String> [-ResourceId <Int64[]>]
 [-ResourceName <String[]>] [-PassThru] [-WhatIf] [-Confirm] [<CommonParameters>]
```

### ByIdDirect
```powershell
Add-CMASCollectionMembershipRule -CollectionId <String> -RuleType <String> [-ResourceId <Int64[]>]
 [-ResourceName <String[]>] [-PassThru] [-WhatIf] [-Confirm] [<CommonParameters>]
```

### ByValueDirect
```powershell
Add-CMASCollectionMembershipRule -InputObject <Object> -RuleType <String> [-ResourceId <Int64[]>]
 [-ResourceName <String[]>] [-PassThru] [-WhatIf] [-Confirm] [<CommonParameters>]
```

### ByNameQuery
```powershell
Add-CMASCollectionMembershipRule -CollectionName <String> -RuleType <String> -QueryExpression <String>
 -RuleName <String> [-PassThru] [-WhatIf] [-Confirm] [<CommonParameters>]
```

### ByIdQuery
```powershell
Add-CMASCollectionMembershipRule -CollectionId <String> -RuleType <String> -QueryExpression <String>
 -RuleName <String> [-PassThru] [-WhatIf] [-Confirm] [<CommonParameters>]
```

### ByValueQuery
```powershell
Add-CMASCollectionMembershipRule -InputObject <Object> -RuleType <String> -QueryExpression <String>
 -RuleName <String> [-PassThru] [-WhatIf] [-Confirm] [<CommonParameters>]
```

### ByNameInclude
```powershell
Add-CMASCollectionMembershipRule -CollectionName <String> -RuleType <String> [-IncludeCollectionId <String>]
 [-IncludeCollectionName <String>] [-PassThru] [-WhatIf] [-Confirm] [<CommonParameters>]
```

### ByIdInclude
```powershell
Add-CMASCollectionMembershipRule -CollectionId <String> -RuleType <String> [-IncludeCollectionId <String>]
 [-IncludeCollectionName <String>] [-PassThru] [-WhatIf] [-Confirm] [<CommonParameters>]
```

### ByValueInclude
```powershell
Add-CMASCollectionMembershipRule -InputObject <Object> -RuleType <String> [-IncludeCollectionId <String>]
 [-IncludeCollectionName <String>] [-PassThru] [-WhatIf] [-Confirm] [<CommonParameters>]
```

### ByNameExclude
```powershell
Add-CMASCollectionMembershipRule -CollectionName <String> -RuleType <String> [-ExcludeCollectionId <String>]
 [-ExcludeCollectionName <String>] [-PassThru] [-WhatIf] [-Confirm] [<CommonParameters>]
```

### ByIdExclude
```powershell
Add-CMASCollectionMembershipRule -CollectionId <String> -RuleType <String> [-ExcludeCollectionId <String>]
 [-ExcludeCollectionName <String>] [-PassThru] [-WhatIf] [-Confirm] [<CommonParameters>]
```

### ByValueExclude
```powershell
Add-CMASCollectionMembershipRule -InputObject <Object> -RuleType <String> [-ExcludeCollectionId <String>]
 [-ExcludeCollectionName <String>] [-PassThru] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
This function adds membership rules to Configuration Manager collections via the Admin Service API.
Supports adding Direct, Query, Include, and Exclude membership rules.

- **Direct rules**: Add specific devices/users by ResourceID or ResourceName
- **Query rules**: Add dynamic membership based on WQL queries
- **Include rules**: Include members from another collection
- **Exclude rules**: Exclude members from another collection

The function uses the AddMembershipRule WMI method to add each rule individually. Server-side validation handles duplicate checking and ensures rule integrity.

## PARAMETERS

### -CollectionName
The name of the collection to add the membership rule to.

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
The ID of the collection to add the membership rule to.

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
A collection object (from Get-CMASCollection) to add the membership rule to.
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
The type of membership rule to add. Valid values are:
- **Direct**: Add specific devices/users by ResourceID
- **Query**: Add dynamic membership based on WQL query
- **Include**: Include members from another collection
- **Exclude**: Exclude members from another collection

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
The ResourceID(s) of the device(s)/user(s) to add (for Direct rules).
Can be a single ResourceID or an array to add multiple resources at once.

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
The name(s) of the device(s)/user(s) to add (for Direct rules).
The function will automatically look up the ResourceID for each name.
Can be a single name or an array to add multiple resources at once.

```yaml
Type: String[]
Parameter Sets: ByNameDirect, ByIdDirect, ByValueDirect
Aliases: None
Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -QueryExpression
The WQL query expression (for Query rules).

Example: `"select SMS_R_SYSTEM.ResourceID from SMS_R_System where SMS_R_System.Name like 'SERVER%'"`

```yaml
Type: String
Parameter Sets: ByNameQuery, ByIdQuery, ByValueQuery
Aliases: None
Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -RuleName
The name of the query membership rule (for Query rules).
This name must be unique within the collection.

```yaml
Type: String
Parameter Sets: ByNameQuery, ByIdQuery, ByValueQuery
Aliases: None
Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -IncludeCollectionId
The CollectionID to include members from (for Include rules).

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
The name of the collection to include members from (for Include rules).
The function will automatically look up the CollectionID.

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

### -ExcludeCollectionId
The CollectionID to exclude members from (for Exclude rules).

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
The name of the collection to exclude members from (for Exclude rules).
The function will automatically look up the CollectionID.

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

### -PassThru
Returns the updated collection object after adding the rule.

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
Returns the updated collection object when -PassThru is specified.

### None
By default, this cmdlet does not generate any output.

## NOTES
This function is part of the SCCM Admin Service module.
Requires an active connection established via Connect-CMAS.

The Admin Service uses the AddMembershipRule WMI method on the SMS_Collection class to add membership rules. This function calls this method via POST for each rule to add. The WMI method handles duplicate checking and validation on the server side.

**WARNING**: Attempting to add duplicate rules may result in errors from the server, which will be caught and displayed as warnings.

**Collection Membership Concepts**:
- Collections can have multiple types of membership rules working together
- Direct rules explicitly add specific devices/users
- Query rules dynamically add members based on criteria
- Include rules add all members from another collection
- Exclude rules remove members that would otherwise be included

## EXAMPLES

### Example 1: Add a direct membership rule by ResourceID
```powershell
Add-CMASCollectionMembershipRule -CollectionName "Production Servers" -RuleType Direct -ResourceId 16777220
```

Adds a direct membership rule to add the device with ResourceID 16777220 to the "Production Servers" collection.

### Example 2: Add a direct membership rule by ResourceName
```powershell
Add-CMASCollectionMembershipRule -CollectionId "SMS00001" -RuleType Direct -ResourceName "SERVER01"
```

Adds a direct membership rule to add the device named "SERVER01" to collection SMS00001. The function automatically looks up the ResourceID.

### Example 3: Add multiple direct membership rules
```powershell
$resourceIds = @(16777220, 16777221, 16777222)
Add-CMASCollectionMembershipRule -CollectionName "Test Collection" -RuleType Direct -ResourceId $resourceIds
```

Adds direct membership rules for multiple devices in a single operation.

### Example 4: Add a query membership rule
```powershell
$query = "select SMS_R_SYSTEM.ResourceID from SMS_R_System where SMS_R_System.Name like 'TEST-%'"
Add-CMASCollectionMembershipRule -CollectionName "Test Devices" -RuleType Query -QueryExpression $query -RuleName "Test Devices Query"
```

Adds a query membership rule that dynamically includes devices whose names start with "TEST-".

### Example 5: Add an include membership rule by collection name
```powershell
Add-CMASCollectionMembershipRule -CollectionName "All Production Systems" -RuleType Include -IncludeCollectionName "Production Servers"
```

Adds an include rule to include all members from the "Production Servers" collection into "All Production Systems".

### Example 6: Add an exclude membership rule
```powershell
Add-CMASCollectionMembershipRule -CollectionName "Workstations" -RuleType Exclude -ExcludeCollectionName "Test Devices"
```

Adds an exclude rule to remove any members that are in "Test Devices" from the "Workstations" collection.

### Example 7: Add a rule via pipeline input
```powershell
Get-CMASCollection -Name "My Collection" | Add-CMASCollectionMembershipRule -RuleType Direct -ResourceId 16777220
```

Gets a collection object and pipes it to Add-CMASCollectionMembershipRule to add a direct membership rule.

### Example 8: Add a rule and return the updated collection
```powershell
$collection = Add-CMASCollectionMembershipRule -CollectionName "Production Servers" -RuleType Direct -ResourceId 16777220 -PassThru
$collection.CollectionRules
```

Adds a direct membership rule and returns the updated collection object to verify the rules.

### Example 9: Preview changes with WhatIf
```powershell
Add-CMASCollectionMembershipRule -CollectionName "Production Servers" -RuleType Direct -ResourceId 16777220 -WhatIf
```

Shows what would happen if the rule is added without actually making the change.

### Example 10: Add query rule with complex WQL
```powershell
$query = @"
select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,
SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,
SMS_R_SYSTEM.Client from SMS_R_System
where SMS_R_System.OperatingSystemNameandVersion like '%Server%'
and SMS_R_System.Active = 1
"@
Add-CMASCollectionMembershipRule -CollectionName "Active Servers" -RuleType Query -QueryExpression $query -RuleName "Active Server Systems"
```

Adds a complex query rule that includes active server systems based on multiple criteria.

## RELATED LINKS

[Connect-CMAS](Connect-CMAS.md)

[Get-CMASCollection](Get-CMASCollection.md)

[Get-CMASCollectionDirectMembershipRule](Get-CMASCollectionDirectMembershipRule.md)

[Get-CMASCollectionQueryMembershipRule](Get-CMASCollectionQueryMembershipRule.md)

[Get-CMASCollectionIncludeMembershipRule](Get-CMASCollectionIncludeMembershipRule.md)

[Get-CMASCollectionExcludeMembershipRule](Get-CMASCollectionExcludeMembershipRule.md)

[Get-CMASDevice](Get-CMASDevice.md)

# Remove-CMASCollection

## SYNOPSIS
Removes a Configuration Manager collection via the Admin Service.

## SYNTAX

### ByName
```powershell
Remove-CMASCollection -CollectionName <String> [-Force] [-PassThru] [-WhatIf] [-Confirm] [<CommonParameters>]
```

### ById
```powershell
Remove-CMASCollection -CollectionId <String> [-Force] [-PassThru] [-WhatIf] [-Confirm] [<CommonParameters>]
```

### ByValue
```powershell
Remove-CMASCollection -InputObject <Object> [-Force] [-PassThru] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
This function deletes a device or user collection from Configuration Manager using the Admin Service API. The collection can be specified by name, ID, or by passing a collection object via pipeline.

Important notes:
- Built-in collections (e.g., SMS00001, SMS00002) cannot be deleted
- Collections containing child collections must have those relationships removed first
- Collections with deployed applications, packages, or task sequences may need those removed first
- The function will warn if the collection has members, but will still allow deletion with confirmation

The function uses the Admin Service REST API to DELETE the SMS_Collection WMI class instance. This is a destructive operation that cannot be undone.

## PARAMETERS

### -CollectionName
The name of the collection to remove.

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
The ID of the collection to remove.

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
A collection object (from Get-CMASCollection) to remove. This parameter accepts pipeline input.

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

### -Force
Skip confirmation prompts and suppress warnings about collection members.

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

### -PassThru
Returns a boolean indicating success ($true) or failure ($false).

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
You can pipe collection objects (from Get-CMASCollection) to this function.

## OUTPUTS

### System.Boolean
When using the -PassThru parameter, returns $true if the collection was successfully removed, or $false if the operation failed.

### None
By default, this function does not return any output.

## NOTES

**Author:** SCCM Admin Service Module

**Requirements:**
- An active connection to the SCCM Admin Service (established via Connect-CMAS)
- Appropriate permissions to delete collections in Configuration Manager

**Protected Collections:**
The following built-in collections cannot be deleted:
- SMS00001 (All Systems)
- SMS00002 (All Users)
- SMS00003 (All User Groups)
- SMS00004 (All Systems)

**Important:**
- This is a destructive operation that cannot be undone
- Collection membership rules and relationships will be removed automatically
- Any deployments targeting the collection should be removed first to avoid orphaned deployments
- The function will verify the collection exists before attempting deletion
- Multiple collections with the same name cannot be removed by name; use -CollectionId instead

## EXAMPLES

### Example 1: Remove a collection by name
```powershell
PS C:\> Remove-CMASCollection -CollectionName "Test Collection"
```

Removes the collection named "Test Collection" with confirmation prompt.

### Example 2: Remove a collection by ID without confirmation
```powershell
PS C:\> Remove-CMASCollection -CollectionId "SMS00100" -Force
```

Removes the collection with ID SMS00100 without prompting for confirmation.

### Example 3: Remove multiple collections via pipeline
```powershell
PS C:\> Get-CMASCollection -Name "Old*" | Remove-CMASCollection -Force
```

Gets all collections starting with "Old" and removes them without confirmation.

### Example 4: Remove a collection and verify success
```powershell
PS C:\> $collection = Get-CMASCollection -Name "Temporary Collection"
PS C:\> $result = Remove-CMASCollection -InputObject $collection -PassThru -Force
PS C:\> if ($result) { Write-Host "Collection removed successfully" }
```

Removes the collection and uses PassThru to get a boolean result indicating success.

### Example 5: Use WhatIf to preview deletion
```powershell
PS C:\> Remove-CMASCollection -CollectionName "Test Collection" -WhatIf
```

Shows what would happen if the collection were removed, without actually removing it.

### Example 6: Remove multiple collections programmatically
```powershell
PS C:\> $collectionsToRemove = @("Test Collection 1", "Test Collection 2", "Test Collection 3")
PS C:\> foreach ($collectionName in $collectionsToRemove) {
    try {
        Remove-CMASCollection -CollectionName $collectionName -Force
        Write-Host "Removed: $collectionName" -ForegroundColor Green
    }
    catch {
        Write-Warning "Failed to remove $collectionName : $_"
    }
}
```

Removes multiple collections in a loop with error handling.

### Example 7: Remove collections created in the last hour
```powershell
PS C:\> $recentCollections = Get-CMASCollection | Where-Object {
    $_.LastChangeTime -and
    ([datetime]$_.LastChangeTime) -gt (Get-Date).AddHours(-1)
}
PS C:\> $recentCollections | Remove-CMASCollection -Force
```

Finds and removes all collections created in the last hour.

### Example 8: Remove a collection with verbose output
```powershell
PS C:\> Remove-CMASCollection -CollectionName "Debug Collection" -Force -Verbose
```

Removes a collection with detailed verbose output showing each step of the process.

### Example 9: Safe removal with member count check
```powershell
PS C:\> $collection = Get-CMASCollection -Name "Test Collection"
PS C:\> if ($collection.MemberCount -eq 0) {
    Remove-CMASCollection -InputObject $collection -Force
    Write-Host "Empty collection removed"
} else {
    Write-Warning "Collection has $($collection.MemberCount) members. Manual review required."
}
```

Only removes the collection if it has no members, otherwise displays a warning.

### Example 10: Attempt to remove a protected collection
```powershell
PS C:\> Remove-CMASCollection -CollectionId "SMS00001" -Force
```

Attempts to remove the built-in "All Systems" collection, which will fail with an error message indicating it's protected.

## RELATED LINKS

[Connect-CMAS](Connect-CMAS.md)

[Get-CMASCollection](Get-CMASCollection.md)

[New-CMASCollection](New-CMASCollection.md)

[Add-CMASCollectionMembershipRule](Add-CMASCollectionMembershipRule.md)

[Remove-CMASCollectionMembershipRule](Remove-CMASCollectionMembershipRule.md)

[Get-CMASCollectionDirectMembershipRule](Get-CMASCollectionDirectMembershipRule.md)

[Get-CMASCollectionQueryMembershipRule](Get-CMASCollectionQueryMembershipRule.md)

[Get-CMASCollectionIncludeMembershipRule](Get-CMASCollectionIncludeMembershipRule.md)

[Get-CMASCollectionExcludeMembershipRule](Get-CMASCollectionExcludeMembershipRule.md)

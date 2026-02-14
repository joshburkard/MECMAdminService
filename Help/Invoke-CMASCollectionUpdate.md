# Invoke-CMASCollectionUpdate

## SYNOPSIS
Triggers a membership update for a Configuration Manager collection via the Admin Service.

## DESCRIPTION
This function initiates a manual membership evaluation for a Configuration Manager collection using the Admin Service API. It calls the RequestRefresh method on the SMS_Collection WMI class.

This is equivalent to the `Invoke-CMCollectionUpdate` cmdlet in the ConfigurationManager module or right-clicking a collection in the SCCM console and selecting "Update Membership".

The function supports three ways to specify the target collection:
- By collection name
- By collection ID
- By passing a collection object (supports pipeline input)

## PARAMETERS

### CollectionName
The name of the collection to update.

- Type: String
- Aliases: Name
- Required: true (in ByName parameter set)
- Accept pipeline input: false
- Accept wildcard characters: false

### CollectionId
The ID of the collection to update.

- Type: String
- Aliases: Id
- Required: true (in ById parameter set)
- Accept pipeline input: false
- Accept wildcard characters: false

### InputObject
A collection object (from Get-CMASCollection) to update. This parameter accepts pipeline input.

- Type: Object
- Aliases: Collection
- Required: true (in ByValue parameter set)
- Accept pipeline input: true
- Accept wildcard characters: false

### PassThru
Returns information about the update operation.

- Type: SwitchParameter
- Required: false
- Accept pipeline input: false
- Accept wildcard characters: false

### WhatIf
Shows what would happen if the cmdlet runs. The cmdlet is not run.

- Type: SwitchParameter
- Required: false
- Accept pipeline input: false
- Accept wildcard characters: false

### Confirm
Prompts you for confirmation before running the cmdlet.

- Type: SwitchParameter
- Required: false
- Accept pipeline input: false
- Accept wildcard characters: false

## OUTPUTS

### None
By default, this function does not generate any output.

### PSCustomObject (when -PassThru is specified)
When -PassThru is specified, returns an object with the following properties:
- CollectionId (String): The ID of the collection
- CollectionName (String): The name of the collection
- UpdateInitiated (Boolean): Whether the update was successfully initiated
- Timestamp (DateTime): When the update was initiated

## EXAMPLES

### Example 1: Update collection by name
```powershell
PS C:\> Invoke-CMASCollectionUpdate -CollectionName "All Systems"
```

Triggers a membership update for the "All Systems" collection.

### Example 2: Update collection by ID
```powershell
PS C:\> Invoke-CMASCollectionUpdate -CollectionId "SMS00001"
```

Triggers a membership update using the collection ID.

### Example 3: Update collection via pipeline
```powershell
PS C:\> Get-CMASCollection -Name "Test Collection" | Invoke-CMASCollectionUpdate
```

Updates collection membership via pipeline.

### Example 4: Update multiple collections
```powershell
PS C:\> Get-CMASCollection -Name "Test*" | Invoke-CMASCollectionUpdate -Verbose
```

Updates membership for all collections starting with "Test", showing verbose progress.

### Example 5: Update with PassThru
```powershell
PS C:\> Invoke-CMASCollectionUpdate -CollectionName "Production Servers" -PassThru
```

Updates the collection and returns operation details.

Output:
```
CollectionId           : SMS00100
CollectionName         : Production Servers
UpdateInitiated        : True
Timestamp              : 2/14/2026 10:30:00 AM
```

### Example 6: Using WhatIf
```powershell
PS C:\> Invoke-CMASCollectionUpdate -CollectionName "Critical Systems" -WhatIf
```

Shows what would happen without actually initiating the update.

## NOTES
This function is part of the SCCM Admin Service module.
Requires an active connection established via Connect-CMAS.

The function uses the Admin Service REST API to call the RequestRefresh method on a specific SMS_Collection instance.

**Important considerations:**
- The RequestRefresh method initiates membership evaluation but returns immediately
- The actual membership update is processed asynchronously by SCCM
- For large collections, the update may take several minutes to complete
- Check the collection's LastMemberChangeTime property to verify when the update completed
- You can use `Get-CMASCollection` to retrieve the updated collection and check its properties

**Performance tips:**
- Avoid updating collections too frequently as it can impact site server performance
- Use incremental updates (Continuous refresh type) for collections that need frequent updates
- Schedule periodic updates during maintenance windows for large collections

## RELATED LINKS

[Connect-CMAS](./Connect-CMAS.md)

[Get-CMASCollection](./Get-CMASCollection.md)

[Set-CMASCollection](./Set-CMASCollection.md)

[New-CMASCollection](./New-CMASCollection.md)

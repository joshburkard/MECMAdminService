# Get-CMASCollection

## SYNOPSIS
Retrieves collections from the SCCM Admin Service.

## DESCRIPTION
This function connects to the SCCM Admin Service API to retrieve information about collections.
You can filter collections by name using the -Name parameter.

## PARAMETERS

### Name
Optional. The name of the collection to retrieve. If not specified, all collections will be returned.

- Type: String
- Required: false
- Accept pipeline input: false
- Accept wildcard characters: false

### CollectionID
Optional. The ID of the collection to retrieve. If not specified, all collections will be returned.

- Type: String
- Required: false
- Accept pipeline input: false
- Accept wildcard characters: false

## EXAMPLES

### Example 3
```powershell
Get-CMASCollection -CollectionID "SMS00001"
```

### Example 1
```powershell
Get-CMASCollection
```

### Example 2
```powershell
Get-CMASCollection -Name "All Systems"
```

## NOTES
This function is part of the SCCM Admin Service module.

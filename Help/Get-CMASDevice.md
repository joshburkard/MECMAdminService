# Get-CMASDevice

## SYNOPSIS
Retrieves information about devices from the SCCM Admin Service.

## DESCRIPTION
This function connects to the SCCM Admin Service API to fetch details about devices.
You can filter the results by device name or device ID.

## PARAMETERS

### Name
The name of the device to retrieve information for. If not specified, all devices will be returned.

- Type: String
- Required: false
- Accept pipeline input: false
- Accept wildcard characters: false

### ResourceID


- Type: Int64
- Required: false
- Default value: 0
- Accept pipeline input: false
- Accept wildcard characters: false

## EXAMPLES

### Example 1
```powershell
Get-CMASDevice -Name "Device001"
```

### Example 2
```powershell
Get-CMASDevice -DeviceID "12345"
```

## NOTES
This function is part of the SCCM Admin Service module.

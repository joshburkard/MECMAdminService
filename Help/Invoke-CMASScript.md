# Invoke-CMASScript

## SYNOPSIS
Executes an approved SCCM script on clients using the Admin Service.

## DESCRIPTION
This function looks up a script via the SCCM Admin Service REST API, then executes it using
the Admin Service's InitiateClientOperationEx endpoint. This enables script execution with
parameters in PowerShell 7.x without requiring WMI.

For scripts without parameters targeting a single device, the simpler Device.RunScript
REST endpoint is used automatically.

IMPORTANT: The Admin Service does not return lazy properties (ScriptHash, ScriptVersion,
ParamsDefinition) needed for executing scripts with parameters. To work around this:

1. Use -ScriptHash and -ScriptVersion parameters to provide metadata manually
2. Enable CIM/WinRM to the Site Server (automatic fallback)
3. For scripts WITHOUT parameters, no workaround needed

## PARAMETERS

### ScriptName
The name of the script. Either ScriptName or ScriptID must be specified.

- Type: String
- Required: false
- Accept pipeline input: false
- Accept wildcard characters: false

### ScriptID
The GUID of the script. Either ScriptName or ScriptID must be specified.

- Type: String
- Required: false
- Accept pipeline input: false
- Accept wildcard characters: false

### CollectionId
The ID of the collection on which to execute the script.

- Type: String
- Required: false
- Accept pipeline input: false
- Accept wildcard characters: false

### ResourceId
The ResourceID of a specific device to target. Can be a single ID or an array of IDs.

- Type: Int64[]
- Required: false
- Default value: @()
- Accept pipeline input: false
- Accept wildcard characters: false

### InputParameters
Optional. A hashtable of input parameters to pass to the script.

- Type: Hashtable
- Required: false
- Default value: @{}
- Accept pipeline input: false
- Accept wildcard characters: false

## EXAMPLES

### Example 2
```powershell
# Script with parameters - provide metadata manually
$params = @{ Key = 'HKLM:\SOFTWARE\Test'; Name = 'Value' }
Invoke-CMASScript -ScriptName "Set Registry" -ResourceId 16777219 -InputParameters $params
```

### Example 1
```powershell
# Simple script without parameters
Invoke-CMASScript -ScriptName "Get Info" -ResourceId 16777219
```

## NOTES
This function is part of the SCCM Admin Service module.

To get script metadata from PowerShell 5.1:
$s = Get-CMScript -ScriptName "Script Name"
$s | Select ScriptGuid, ScriptHash, ScriptVersion, ParamsDefinition

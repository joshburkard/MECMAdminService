# Get-CMASScriptExecutionStatus

## SYNOPSIS
Returns the current status of a SCCM Script execution via Admin Service.

## DESCRIPTION
This function retrieves the execution status of SCCM scripts through the Admin Service REST API.
It queries SMS_ScriptsExecutionTask and SMS_ScriptsExecutionStatus to get detailed information
about script execution status, including output from individual clients.

## PARAMETERS

### OperationID
The ClientOperationId returned from Invoke-CMASScript. When specified, retrieves status for
this specific operation.

- Type: String
- Required: false
- Accept pipeline input: false
- Accept wildcard characters: false

### CollectionName
Filter by collection name. Can be combined with ScriptName.

- Type: String
- Required: false
- Accept pipeline input: false
- Accept wildcard characters: false

### CollectionID
Filter by collection ID. Can be combined with ScriptName.

- Type: String
- Required: false
- Accept pipeline input: false
- Accept wildcard characters: false

### ScriptName
Filter by script name. Can be combined with CollectionName or CollectionID.

- Type: String
- Required: false
- Accept pipeline input: false
- Accept wildcard characters: false

## EXAMPLES

### Example 3
```powershell
# Get executions for a specific script
Get-CMASScriptExecutionStatus -ScriptName "Set Registry Value"
```

### Example 1
```powershell
# Get status for a specific operation
$result = Invoke-CMASScript -ScriptName "Get Info" -ResourceId 16777219
Get-CMASScriptExecutionStatus -OperationID $result.OperationId
```

### Example 2
```powershell
# Get all script executions for a collection
Get-CMASScriptExecutionStatus -CollectionName "All Systems"
```

### Example 4
```powershell
# Get executions for a specific script on a collection
Get-CMASScriptExecutionStatus -CollectionID "SMS00001" -ScriptName "Get Info"
```

## NOTES
This function is part of the SCCM Admin Service module.
Requires connection via Connect-CMAS before use.

The function returns:
- OperationID: The client operation ID
- ScriptName: Name of the executed script
- ScriptGuid: GUID of the script
- CollectionID/Name: Target collection information
- Results: Array of per-device results including output
- Status: Overall execution status
- Client counts: Total, Completed, Failed, Offline, NotApplicable, Unknown
- LastUpdateTime: Last status update

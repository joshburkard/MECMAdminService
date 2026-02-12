# Connect-CMAS

## SYNOPSIS
Connects to the SCCM Admin Service on a specified site server.

## DESCRIPTION
This function establishes a connection to the SCCM Admin Service API on the specified site server. It tests the connection by retrieving the administration service information and stores the connection details for use in subsequent API calls.

## PARAMETERS

### SiteServer
The hostname or IP address of the SCCM site server hosting the Admin Service. This parameter is mandatory.

- Type: String
- Required: true
- Accept pipeline input: false
- Accept wildcard characters: false

### Credential
Optional. A PSCredential object for authentication. If not provided, the current user's credentials will be used.

- Type: PSCredential
- Required: false
- Accept pipeline input: false
- Accept wildcard characters: false

### SkipCertificateCheck


- Type: SwitchParameter
- Required: false
- Default value: False
- Accept pipeline input: false
- Accept wildcard characters: false

## EXAMPLES

### Example 1
```powershell
# Connect to the Admin Service using default credentials
Connect-CMAS -SiteServer "sccm.domain.local"
```

### Example 2
```powershell
# Connect to the Admin Service using specific credentials
$cred = Get-Credential
Connect-CMAS -SiteServer "sccm.domain.local" -Credential $cred
```

## NOTES
This function is part of the SCCM Admin Service module.

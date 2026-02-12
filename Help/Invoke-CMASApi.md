# Invoke-CMASApi

## SYNOPSIS
Invokes a REST API call to the Configuration Manager Admin Service.

## DESCRIPTION
This function allows you to interact with the Configuration Manager Admin Service using REST API calls. You
can specify the HTTP method, request body, and credentials for authentication.

## PARAMETERS

### Path
The API endpoint path (e.g., "wmi/SMS_Collection" or "v1.0/AdministrationServiceInformation").

- Type: String
- Required: true
- Accept pipeline input: false
- Accept wildcard characters: false

### Method
The HTTP method to use for the request (GET, POST, PUT, DELETE). Default is GET.

- Type: String
- Required: false
- Default value: GET
- Accept pipeline input: false
- Accept wildcard characters: false

### Body
The request body to send with POST or PUT requests. This should be a PowerShell object that will be converted to JSON.

- Type: Object
- Required: false
- Accept pipeline input: false
- Accept wildcard characters: false

### Credential
The credentials to use for authentication. If not provided, the function will use the current user's credentials.

- Type: PSCredential
- Required: false
- Accept pipeline input: false
- Accept wildcard characters: false

### SiteServer
The hostname or IP address of the Configuration Manager Site Server. This parameter is required.

- Type: String
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
# Example 1: Get a list of collections using default credentials
Invoke-CMASApi -Path "wmi/SMS_Collection" -SiteServer "sccm.domain.local"
```

### Example 2
```powershell
# Example 2: Get administration service information using specific credentials
$cred = Get-Credential
Invoke-CMSApi -Path "v1.0/AdministrationServiceInformation" -SiteServer "sccm.domain.local" -Credential $cred
```

## NOTES
This function is part of the SCCM Admin Service module.

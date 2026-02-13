function Invoke-CMASApi {
    <#
        .SYNOPSIS
            Invokes a REST API call to the Configuration Manager Admin Service.

        .DESCRIPTION
            This function allows you to interact with the Configuration Manager Admin Service using REST API calls. You
            can specify the HTTP method, request body, and credentials for authentication.

        .PARAMETER Path
            The API endpoint path (e.g., "wmi/SMS_Collection" or "v1.0/AdministrationServiceInformation").

        .PARAMETER Method
            The HTTP method to use for the request (GET, POST, PUT, DELETE). Default is GET.

        .PARAMETER Body
            The request body to send with POST or PUT requests. This should be a PowerShell object that will be converted to JSON.

        .PARAMETER Credential
            The credentials to use for authentication. If not provided, the function will use the current user's credentials.

        .PARAMETER SiteServer
            The hostname or IP address of the Configuration Manager Site Server. This parameter is required.

        .EXAMPLE
            # Example 1: Get a list of collections using default credentials
            Invoke-CMASApi -Path "wmi/SMS_Collection" -SiteServer "sccm.domain.local"

        .EXAMPLE
            # Example 2: Get administration service information using specific credentials
            $cred = Get-Credential
            Invoke-CMSApi -Path "v1.0/AdministrationServiceInformation" -SiteServer "sccm.domain.local" -Credential $cred

        .NOTES
            This function is part of the SCCM Admin Service module.

    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,

        [Parameter(Mandatory=$false)]
        [ValidateSet("GET","POST","PUT","PATCH","DELETE")]
        [string]$Method = "GET",

        [Parameter(Mandatory=$false)]
        [object]$Body,

        [Parameter(Mandatory=$false)]
        [pscredential]$Credential,

        [Parameter(Mandatory=$false)]
        [string]$SiteServer

        ,
        [switch]$SkipCertificateCheck


    )

    # Use stored connection
    if (-not $SiteServer) { $SiteServer = $script:CMASConnection.SiteServer }
    if (-not $Credential) { $Credential = $script:CMASConnection.Credential }
    if (-not $SiteServer) { throw "No SiteServer specified. Run Connect-CMAS first." }
    if (-not $SkipCertificateCheck) { $SkipCertificateCheck = $script:CMASConnection.SkipCertificateCheck }

    $uri = "https://$SiteServer/AdminService/$Path"

    $params = @{
        Uri = $uri
        Method = $Method
    }

    if ($SkipCertificateCheck) {
        if ($PSVersionTable.PSVersion.Major -ge 6) {
            $params.SkipCertificateCheck = $true
        } else {
            # For PowerShell 5, we need to use a workaround to ignore certificate errors
            Add-Type @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAllCertsPolicy : ICertificatePolicy {
    public bool CheckValidationResult(
        ServicePoint srvPoint, X509Certificate certificate,
        WebRequest request, int certificateProblem) {
        return true;
    }
}
"@
            [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
        }
    }

    if ($Credential) {
        $params.Credential = $Credential
    } else {
        $params.UseDefaultCredentials = $true
    }

    if ($Body) {
        $params.Body = ($Body | ConvertTo-Json -Depth 10)
        $params.ContentType = "application/json"
    }

    Write-Verbose "Invoking API: $Method $uri"
    Invoke-RestMethod @params
}

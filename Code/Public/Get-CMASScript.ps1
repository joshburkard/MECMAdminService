function Get-CMASScript {
    <#
        .SYNOPSIS
        List CMScripts from AdminService

        .DESCRIPTION
        This function retrieves the content of a specified CMAS script from the AdminService.

        .PARAMETER Name
        The name of the CMAS script to retrieve.

        .EXAMPLE
        Get-CMASScript -Name "Get-SomeSettings"

        .NOTES
        Date, Author, Version, Notes

    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [String]$Name
    )
    try {

        $path = "wmi/SMS_Scripts"
        if ($Name) {
            $path += "?`$filter=ScriptName eq '$Name'"
        }
        $res = Invoke-CMASApi -Path $path
        return $res.value | Select-Object ScriptName, ScriptGUID, Script -ExcludeProperty __*, @odata*
    }
    catch {
        Write-Error "Failed to retrieve CMAS script: $_"
        throw $_
    }
}

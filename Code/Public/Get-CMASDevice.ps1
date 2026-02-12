function Get-CMASDevice {
    <#
        .SYNOPSIS
            Retrieves information about devices from the SCCM Admin Service.

        .DESCRIPTION
            This function connects to the SCCM Admin Service API to fetch details about devices.
            You can filter the results by device name or device ID.

        .PARAMETER Name
            The name of the device to retrieve information for. If not specified, all devices will be returned.

        .PARAMETER ResourceID
            The unique identifier of the device to retrieve information for. If not specified, all devices will be returned.

        .EXAMPLE
            Get-CMASDevice -Name "Device001"

        .EXAMPLE
            Get-CMASDevice -ResourceID "12345"

        .NOTES
            This function is part of the SCCM Admin Service module.

    #>
    [CmdletBinding()]
    param(
        [string]$Name,
        [long]$ResourceID
    )
    try {
        $path = "wmi/SMS_R_System"

        if ($Name) {
            $path += "?`$filter=Name eq '$Name'"
        }
        if ($ResourceID) {
            $path += "?`$filter=ResourceID eq $( $ResourceID.ToString() )"
        }

        Write-Verbose "Fetching device information from Admin Service with path: $path"
        $res = Invoke-CMASApi -Path $path

        # format results as needed, all properties except those starting with "__" (WMI metadata) and @odata.* (OData metadata)
        $devices = $res.value | Select-Object * -ExcludeProperty __*, @odata*

        return $devices
    }
    catch {
        Write-Error "Failed to retrieve device information: $_"
        throw $_
    }
}

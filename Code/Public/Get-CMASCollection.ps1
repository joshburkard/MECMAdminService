function Get-CMASCollection {
    <#
        .SYNOPSIS
            Retrieves collections from the SCCM Admin Service.

        .DESCRIPTION
            This function connects to the SCCM Admin Service API to retrieve information about collections.
            You can filter collections by name using the -Name parameter.

        .PARAMETER Name
            Optional. The name of the collection to retrieve. If not specified, all collections will be returned.

        .PARAMETER CollectionID
            Optional. The ID of the collection to retrieve. If not specified, all collections will be returned.

        .EXAMPLE
            Get-CMASCollection

        .EXAMPLE
            Get-CMASCollection -Name "All Systems"

        .EXAMPLE
            Get-CMASCollection -CollectionID "SMS00001"

        .NOTES
            This function is part of the SCCM Admin Service module.
    #>
    [CmdletBinding()]
    param(
        [string]$Name,
        [string]$CollectionID
    )
    try {

        $path = "wmi/SMS_Collection"

        if ($Name) {
            $path += "?`$filter=Name eq '$Name'"
        }
        if ($CollectionID) {
            $path += "?`$filter=CollectionID eq '$CollectionID'"
        }

        $res = Invoke-CMASApi -Path $path

        # Return all collection properties
        return $res.value
    }
    catch {
        Write-Error "Failed to retrieve collections: $_"
        throw $_
    }
}

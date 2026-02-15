function Get-CMASCollectionMember {
    <#
        .SYNOPSIS
            Retrieves members of a Configuration Manager collection via the Admin Service.

        .DESCRIPTION
            This function retrieves collection members using the Admin Service SMS_FullCollectionMembership
            WMI class. You can specify the target collection by name, CollectionID, or by piping a
            collection object from Get-CMASCollection. Optional filters allow narrowing results by
            resource name or resource ID.

            Wildcard filters for ResourceName are applied client-side after retrieval.

        .PARAMETER CollectionName
            The name of the collection to retrieve members from.

        .PARAMETER CollectionId
            The ID of the collection to retrieve members from.

        .PARAMETER InputObject
            A collection object (from Get-CMASCollection) to retrieve members from.
            This parameter accepts pipeline input.

        .PARAMETER ResourceName
            Optional. Filter members to only include resources with this name.
            Supports wildcard patterns (* and ?).

        .PARAMETER ResourceId
            Optional. Filter members to only include the resource with this ID.

        .EXAMPLE
            Get-CMASCollectionMember -CollectionName "All Systems"

        .EXAMPLE
            Get-CMASCollectionMember -CollectionId "SMS00001"

        .EXAMPLE
            Get-CMASCollectionMember -CollectionName "Test-Collection-Query" -ResourceName "TEST-*"

        .EXAMPLE
            Get-CMASCollection -Name "All Systems" | Get-CMASCollectionMember

        .EXAMPLE
            Get-CMASCollectionMember -CollectionId "SMS00001" -ResourceId 16777220

        .NOTES
            This function is part of the SCCM Admin Service module.
            Requires an active connection established via Connect-CMAS.

        .LINK
            Connect-CMAS
            Get-CMASCollection
    #>
    [CmdletBinding(DefaultParameterSetName='ByCollectionName')]
    param(
        [Parameter(Mandatory=$false, ParameterSetName='ByCollectionName', Position=0)]
        [ValidateNotNullOrEmpty()]
        [Alias('Name')]
        [string]$CollectionName,

        [Parameter(Mandatory=$false, ParameterSetName='ByCollectionId', Position=0)]
        [ValidateNotNullOrEmpty()]
        [Alias('Id')]
        [string]$CollectionId,

        [Parameter(Mandatory=$true, ParameterSetName='ByInputObject', ValueFromPipeline=$true)]
        [Alias('Collection')]
        [object]$InputObject,

        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [SupportsWildcards()]
        [string]$ResourceName,

        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [long]$ResourceId
    )

    begin {
        if (-not $script:CMASConnection.SiteServer) {
            throw "No active connection to SCCM Admin Service. Run Connect-CMAS first."
        }

        if (-not $CollectionName -and -not $CollectionId -and -not $InputObject) {
            throw "Either CollectionName, CollectionId, or InputObject must be specified."
        }
    }

    process {
        try {
            $targetCollectionId = $null
            $targetCollectionName = $null

            if ($InputObject) {
                if ($InputObject.CollectionID) {
                    $targetCollectionId = $InputObject.CollectionID
                    $targetCollectionName = $InputObject.Name
                } else {
                    throw "InputObject does not contain a valid CollectionID property."
                }
            } elseif ($CollectionId) {
                $targetCollectionId = $CollectionId
            } elseif ($CollectionName) {
                Write-Verbose "Resolving CollectionName '$CollectionName' to CollectionID..."
                $collection = Get-CMASCollection -Name $CollectionName
                if (-not $collection) {
                    throw "Collection with name '$CollectionName' not found."
                }
                if (@($collection).Count -gt 1) {
                    throw "Multiple collections found with name '$CollectionName'. Use CollectionId instead."
                }
                $targetCollectionId = $collection.CollectionID
                $targetCollectionName = $collection.Name
            }

            if (-not $targetCollectionId) {
                throw "CollectionID could not be determined."
            }

            if (-not $targetCollectionName) {
                $collection = Get-CMASCollection -CollectionID $targetCollectionId
                if ($collection) {
                    $targetCollectionName = $collection.Name
                }
            }

            $filters = @("CollectionID eq '$targetCollectionId'")

            if ($ResourceId) {
                $filters += "ResourceID eq $($ResourceId.ToString())"
            }

            $applyNameFilterServerSide = $false
            if ($ResourceName -and $ResourceName -notmatch '[\*\?]') {
                $filters += "Name eq '$ResourceName'"
                $applyNameFilterServerSide = $true
            }

            $filterString = $filters -join ' and '
            $path = "wmi/SMS_FullCollectionMembership?`$filter=$filterString"

            Write-Verbose "Fetching collection members from Admin Service with path: $path"
            $response = Invoke-CMASApi -Path $path
            $members = @($response.value)

            if (-not $members -or $members.Count -eq 0) {
                Write-Verbose "No members found for CollectionID '$targetCollectionId'"
                return
            }

            if ($ResourceName -and -not $applyNameFilterServerSide) {
                Write-Verbose "Filtering members by ResourceName (client-side): $ResourceName"
                $members = $members | Where-Object { $_.Name -like $ResourceName }
            }

            if (-not $members -or $members.Count -eq 0) {
                Write-Verbose "No members match the specified filters"
                return
            }

            $output = $members | ForEach-Object {
                $_ | Add-Member -NotePropertyName 'CollectionName' -NotePropertyValue $targetCollectionName -Force -PassThru
            } | Select-Object -Property * -ExcludeProperty __*, @odata*

            foreach ($item in $output) {
                $displayProps = [string[]]@('Name', 'ResourceID', 'CollectionID', 'CollectionName')
                $defaultDisplay = [System.Management.Automation.PSPropertySet]::new(
                    'DefaultDisplayPropertySet',
                    $displayProps
                )
                $item | Add-Member -MemberType MemberSet -Name PSStandardMembers -Value $defaultDisplay -Force
            }

            return $output
        }
        catch {
            Write-Error "Failed to retrieve collection members: $_"
            throw $_
        }
    }
}

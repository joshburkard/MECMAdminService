function Remove-CMASCollection {
    <#
        .SYNOPSIS
            Removes a Configuration Manager collection via the Admin Service.

        .DESCRIPTION
            This function deletes a device or user collection from Configuration Manager using the Admin Service API.
            The collection can be specified by name, ID, or by passing a collection object via pipeline.

            Important notes:
            - Built-in collections (e.g., SMS00001, SMS00002) cannot be deleted
            - Collections containing child collections must have those relationships removed first
            - Collections with deployed applications, packages, or task sequences may need those removed first
            - The function will warn if the collection has members, but will still allow deletion with confirmation

            The function uses the Admin Service REST API to DELETE the SMS_Collection WMI class instance.

        .PARAMETER CollectionName
            The name of the collection to remove.

        .PARAMETER CollectionId
            The ID of the collection to remove.

        .PARAMETER InputObject
            A collection object (from Get-CMASCollection) to remove.
            This parameter accepts pipeline input.

        .PARAMETER Force
            Skip confirmation prompts and suppress warnings about collection members.

        .PARAMETER PassThru
            Returns a boolean indicating success ($true) or failure ($false).

        .EXAMPLE
            Remove-CMASCollection -CollectionName "Test Collection"
            Removes the collection named "Test Collection" with confirmation prompt.

        .EXAMPLE
            Remove-CMASCollection -CollectionId "SMS00100" -Force
            Removes the collection with ID SMS00100 without confirmation.

        .EXAMPLE
            Get-CMASCollection -Name "Old*" | Remove-CMASCollection -Force
            Removes all collections starting with "Old" without confirmation.

        .EXAMPLE
            $collection = Get-CMASCollection -Name "Temporary Collection"
            Remove-CMASCollection -InputObject $collection -PassThru
            Removes the collection and returns a boolean result.

        .EXAMPLE
            Remove-CMASCollection -CollectionName "Test Collection" -WhatIf
            Shows what would happen if the collection were removed, without actually removing it.

        .NOTES
            This function is part of the SCCM Admin Service module.
            Requires an active connection established via Connect-CMAS.

            The Admin Service uses DELETE method on the SMS_Collection class endpoint
            to remove collections. This is a destructive operation that cannot be undone.

            Built-in and system collections are protected and cannot be deleted.

        .LINK
            Connect-CMAS
            Get-CMASCollection
            New-CMASCollection
            Add-CMASCollectionMembershipRule
            Remove-CMASCollectionMembershipRule
    #>
    [CmdletBinding(DefaultParameterSetName='ByName', SupportsShouldProcess=$true, ConfirmImpact='High')]
    param(
        [Parameter(Mandatory=$true, ParameterSetName='ByName')]
        [ValidateNotNullOrEmpty()]
        [Alias('Name')]
        [string]$CollectionName,

        [Parameter(Mandatory=$true, ParameterSetName='ById')]
        [ValidateNotNullOrEmpty()]
        [Alias('Id')]
        [string]$CollectionId,

        [Parameter(Mandatory=$true, ParameterSetName='ByValue', ValueFromPipeline=$true)]
        [ValidateNotNull()]
        [Alias('Collection')]
        [object]$InputObject,

        [Parameter(Mandatory=$false)]
        [switch]$Force,

        [Parameter(Mandatory=$false)]
        [switch]$PassThru
    )

    begin {
        # Validate connection
        if (-not $script:CMASConnection.SiteServer) {
            throw "No active connection to SCCM Admin Service. Run Connect-CMAS first."
        }

        # Protected collections that cannot be deleted
        $protectedCollections = @(
            'SMS00001',  # All Systems
            'SMS00002',  # All Users
            'SMS00003',  # All User Groups
            'SMS00004'   # All Systems
        )
    }

    process {
        try {
            # Resolve the collection
            $targetCollection = $null

            switch ($PSCmdlet.ParameterSetName) {
                'ByName' {
                    Write-Verbose "Resolving collection by name: $CollectionName"
                    $targetCollection = Get-CMASCollection -Name $CollectionName
                    if (-not $targetCollection) {
                        Write-Error "Collection with name '$CollectionName' not found."
                        if ($PassThru) { return $false }
                        return
                    }
                    # Handle multiple collections with same name
                    if ($targetCollection -is [array] -and $targetCollection.Count -gt 1) {
                        Write-Error "Multiple collections found with name '$CollectionName'. Use -CollectionId to specify which one to remove."
                        if ($PassThru) { return $false }
                        return
                    }
                }
                'ById' {
                    Write-Verbose "Resolving collection by ID: $CollectionId"
                    $targetCollection = Get-CMASCollection -CollectionId $CollectionId
                    if (-not $targetCollection) {
                        Write-Error "Collection with ID '$CollectionId' not found."
                        if ($PassThru) { return $false }
                        return
                    }
                }
                'ByValue' {
                    Write-Verbose "Using provided collection object"
                    $targetCollection = $InputObject
                    if (-not $targetCollection.CollectionID) {
                        Write-Error "Invalid collection object. Missing CollectionID property."
                        if ($PassThru) { return $false }
                        return
                    }
                }
            }

            # Extract collection details
            $collectionId = $targetCollection.CollectionID
            $collectionName = $targetCollection.Name
            $collectionType = $targetCollection.CollectionType
            $memberCount = if ($targetCollection.MemberCount) { $targetCollection.MemberCount } else { 0 }

            Write-Verbose "Target Collection: $collectionName (ID: $collectionId)"
            Write-Verbose "Collection Type: $collectionType ($(if($collectionType -eq 1){'User'}elseif($collectionType -eq 2){'Device'}else{'Other'}))"
            Write-Verbose "Member Count: $memberCount"

            # Check if collection is protected
            if ($collectionId -in $protectedCollections) {
                Write-Error "Cannot remove protected system collection '$collectionName' (ID: $collectionId)."
                if ($PassThru) { return $false }
                return
            }

            # Warn about member count
            if ($memberCount -gt 0 -and -not $Force) {
                Write-Warning "Collection '$collectionName' has $memberCount member(s). These memberships will be removed along with the collection."
            }

            # Build description for ShouldProcess
            $description = "collection '$collectionName' (ID: $collectionId)"
            if ($memberCount -gt 0) {
                $description += " with $memberCount member(s)"
            }

            # Determine if we should prompt
            $shouldContinue = $true
            if (-not $Force -and -not $PSCmdlet.ShouldProcess($description, "Remove Configuration Manager collection")) {
                $shouldContinue = $false
            }

            if ($shouldContinue) {
                Write-Verbose "Removing collection: $collectionName (ID: $collectionId)"

                # Delete the collection via DELETE method
                $deletePath = "wmi/SMS_Collection('$collectionId')"
                $result = Invoke-CMASApi -Path $deletePath -Method DELETE

                # The DELETE method typically returns no content on success
                Write-Host "Collection '$collectionName' (ID: $collectionId) removed successfully." -ForegroundColor Green

                if ($PassThru) {
                    return $true
                }
            } else {
                Write-Verbose "Collection removal cancelled by user."
                if ($PassThru) {
                    return $false
                }
            }
        }
        catch {
            $errorMessage = $_.Exception.Message
           
            # Build error message with available information
            $identifier = if ($PSCmdlet.ParameterSetName -eq 'ByName') {
                "'$CollectionName'"
            } elseif ($PSCmdlet.ParameterSetName -eq 'ById') {
                "'$CollectionId'"
            } else {
                "provided collection"
            }
            
            Write-Error "Failed to remove collection $identifier : $errorMessage"

            if ($PassThru) {
                return $false
            }
            throw
        }
    }
}

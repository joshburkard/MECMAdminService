function Invoke-CMASCollectionUpdate {
    <#
        .SYNOPSIS
            Triggers a membership update for a Configuration Manager collection via the Admin Service.

        .DESCRIPTION
            This function initiates a manual membership evaluation for a Configuration Manager collection
            using the Admin Service API. It calls the RequestRefresh method on the SMS_Collection WMI class.

            This is equivalent to the Invoke-CMCollectionUpdate cmdlet in the ConfigurationManager module
            or right-clicking a collection in the SCCM console and selecting "Update Membership".

            The function supports three ways to specify the target collection:
            - By collection name
            - By collection ID
            - By passing a collection object (supports pipeline input)

        .PARAMETER CollectionName
            The name of the collection to update.

        .PARAMETER CollectionId
            The ID of the collection to update.

        .PARAMETER InputObject
            A collection object (from Get-CMASCollection) to update.
            This parameter accepts pipeline input.

        .PARAMETER PassThru
            Returns information about the update operation.

        .EXAMPLE
            Invoke-CMASCollectionUpdate -CollectionName "All Systems"
            Triggers a membership update for the "All Systems" collection.

        .EXAMPLE
            Invoke-CMASCollectionUpdate -CollectionId "SMS00001"
            Triggers a membership update using the collection ID.

        .EXAMPLE
            Get-CMASCollection -Name "Test Collection" | Invoke-CMASCollectionUpdate
            Updates collection membership via pipeline.

        .EXAMPLE
            Get-CMASCollection -Name "Test*" | Invoke-CMASCollectionUpdate -Verbose
            Updates membership for all collections starting with "Test", showing verbose progress.

        .EXAMPLE
            Invoke-CMASCollectionUpdate -CollectionName "Production Servers" -PassThru
            Updates the collection and returns operation details.

        .NOTES
            This function is part of the SCCM Admin Service module.
            Requires an active connection established via Connect-CMAS.

            The function uses the Admin Service REST API to call the RequestRefresh method
            on a specific SMS_Collection instance.

            Important considerations:
            - The RequestRefresh method initiates membership evaluation but returns immediately
            - The actual membership update is processed asynchronously by SCCM
            - For large collections, the update may take several minutes to complete
            - Check the collection's LastMemberChangeTime property to verify when the update completed

        .LINK
            Connect-CMAS
            Get-CMASCollection
            Set-CMASCollection
            New-CMASCollection
    #>
    [CmdletBinding(DefaultParameterSetName='ByName', SupportsShouldProcess=$true, ConfirmImpact='Low')]
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
        [switch]$PassThru
    )

    begin {
        # Validate connection
        if (-not $script:CMASConnection.SiteServer) {
            throw "No active connection to SCCM Admin Service. Run Connect-CMAS first."
        }
    }

    process {
        try {
            # Determine target collection based on parameter set
            $targetCollection = $null

            switch ($PSCmdlet.ParameterSetName) {
                'ByName' {
                    Write-Verbose "Looking up collection by name: $CollectionName"
                    $targetCollection = Get-CMASCollection -Name $CollectionName
                    if (-not $targetCollection) {
                        throw "Collection '$CollectionName' not found."
                    }
                }
                'ById' {
                    Write-Verbose "Looking up collection by ID: $CollectionId"
                    $targetCollection = Get-CMASCollection -CollectionId $CollectionId
                    if (-not $targetCollection) {
                        throw "Collection with ID '$CollectionId' not found."
                    }
                }
                'ByValue' {
                    Write-Verbose "Using collection object from pipeline"
                    $targetCollection = $InputObject
                    if (-not $targetCollection.CollectionID) {
                        throw "Invalid collection object provided. Expected object with CollectionID property."
                    }
                }
            }

            # Ensure we have a valid collection
            if (-not $targetCollection -or -not $targetCollection.CollectionID) {
                throw "Failed to identify target collection."
            }

            $description = "collection '$($targetCollection.Name)' ($($targetCollection.CollectionID))"

            if ($PSCmdlet.ShouldProcess($description, "Trigger membership update for Configuration Manager collection")) {
                Write-Verbose "Triggering membership update for: $($targetCollection.Name) ($($targetCollection.CollectionID))"

                # Build the method call to RequestRefresh
                # For WMI instance methods via Admin Service, the path format is:
                # wmi/ClassName('KeyValue')/AdminService.MethodName
                $methodPath = "wmi/SMS_Collection('$($targetCollection.CollectionID)')/AdminService.RequestRefresh"

                Write-Verbose "Calling RequestRefresh method on collection: $($targetCollection.CollectionID)"

                # Call the RequestRefresh method via Admin Service
                # RequestRefresh takes no parameters, but we need to pass an empty body for proper Content-Type header
                $result = Invoke-CMASApi -Path $methodPath -Method POST -Body @{}

                Write-Verbose "Membership update initiated successfully"
                Write-Host "Collection '$($targetCollection.Name)' membership update initiated." -ForegroundColor Green

                if ($PassThru) {
                    # Return information about the operation
                    [PSCustomObject]@{
                        CollectionId = $targetCollection.CollectionID
                        CollectionName = $targetCollection.Name
                        UpdateInitiated = $true
                        Timestamp = Get-Date
                    }
                }
            }
        }
        catch {
            Write-Error "Failed to update collection membership: $_"
            throw
        }
    }

    end {
    }
}

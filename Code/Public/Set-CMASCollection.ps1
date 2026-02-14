function Set-CMASCollection {
    <#
        .SYNOPSIS
            Modifies properties of a Configuration Manager collection via the Admin Service.

        .DESCRIPTION
            This function updates an existing device or user collection in Configuration Manager using the Admin Service API.
            You can modify collection properties such as name, comment, refresh type, and refresh schedule.

            The function supports updating various collection properties:
            - Name: Change the collection name
            - Comment: Add or modify the collection description
            - RefreshType: Change between Manual, Periodic, Continuous, or Both
            - LimitingCollectionId/Name: Change the limiting collection (use with caution)

            Note: RefreshSchedule updates are NOT supported via Admin Service API.
            Use Set-CMASCollectionSchedule (CIM-based) to manage collection schedules.

            The function uses the Admin Service REST API to PATCH the SMS_Collection WMI class instance.

        .PARAMETER CollectionName
            The current name of the collection to modify.

        .PARAMETER CollectionId
            The ID of the collection to modify.

        .PARAMETER InputObject
            A collection object (from Get-CMASCollection) to modify.
            This parameter accepts pipeline input.

        .PARAMETER NewName
            The new name for the collection. Must be unique within Configuration Manager.

        .PARAMETER Comment
            The new comment or description for the collection. Pass empty string to clear.

        .PARAMETER RefreshType
            The new refresh type for the collection:
            - Manual (1): Manual updates only
            - Periodic (2): Scheduled updates
            - Continuous (4): Incremental updates (continuous evaluation)
            - Both (6): Periodic and Continuous (2 + 4)


        .PARAMETER LimitingCollectionName
            The name of the new limiting collection. The function will look up the CollectionID automatically.

        .PARAMETER PassThru
            Returns the updated collection object.

        .EXAMPLE
            Set-CMASCollection -CollectionName "Old Name" -NewName "New Name"
            Renames a collection.

        .EXAMPLE
            Set-CMASCollection -CollectionId "SMS00100" -Comment "Updated description" -PassThru
            Updates the collection comment and returns the updated collection object.

        .EXAMPLE
            Set-CMASCollection -CollectionName "My Collection" -RefreshType Continuous -Comment "Auto-updating collection"
            Changes the refresh type to continuous and updates the comment.

        .EXAMPLE
            Set-CMASCollection -CollectionName "My Collection" -RefreshType Periodic
            Changes the refresh type to periodic. The collection will use its existing schedule or a default schedule.
            Note: RefreshSchedule cannot be updated via Admin Service API. Use SCCM Console or ConfigurationManager module.

        .EXAMPLE
            Get-CMASCollection -Name "Test*" | Set-CMASCollection -Comment "Test collection" -RefreshType Manual
            Updates all collections starting with "Test" via pipeline.

        .EXAMPLE
            Set-CMASCollection -CollectionName "My Collection" -NewName "Renamed Collection" -RefreshType Both -PassThru
            Updates both the name and refresh type, returning the updated collection.

        .EXAMPLE
            Set-CMASCollection -CollectionName "Collection A" -LimitingCollectionName "All Systems" -WhatIf
            Shows what would happen if the limiting collection were changed, without actually changing it.

        .NOTES
            This function is part of the SCCM Admin Service module.
            Requires an active connection established via Connect-CMAS.

            The Admin Service uses PATCH method on the SMS_Collection class endpoint to update collections.

            Important considerations:
            - Changing the limiting collection can cause members to be removed if they don't match the new limiting collection
            - Collection names must be unique across all collections in Configuration Manager
            - When changing RefreshType to Periodic, the collection will use its existing schedule or a default schedule
            - To update RefreshSchedule, use Set-CMASCollectionSchedule function

            Refresh Types:
            - 1 = Manual only
            - 2 = Scheduled (Periodic) only
            - 4 = Incremental (Continuous) only
            - 6 = Scheduled and Incremental (Both)

        .LINK
            Connect-CMAS
            Get-CMASCollection
            New-CMASCollection
            Remove-CMASCollection
            Set-CMASCollectionSchedule
    #>
    [CmdletBinding(DefaultParameterSetName='ByName', SupportsShouldProcess=$true, ConfirmImpact='Medium')]
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
        [string]$NewName,

        [Parameter(Mandatory=$false)]
        [string]$Comment,

        [Parameter(Mandatory=$false)]
        [ValidateSet('Manual', 'Periodic', 'Continuous', 'Both', '1', '2', '4', '6')]
        [string]$RefreshType,

        [Parameter(Mandatory=$false)]
        [string]$LimitingCollectionId,

        [Parameter(Mandatory=$false)]
        [string]$LimitingCollectionName,

        [Parameter(Mandatory=$false)]
        [switch]$PassThru
    )

    begin {
        # Validate connection
        if (-not $script:CMASConnection.SiteServer) {
            throw "No active connection to SCCM Admin Service. Run Connect-CMAS first."
        }

        # Check if at least one property to update is specified
        if (-not $NewName -and -not $PSBoundParameters.ContainsKey('Comment') -and
            -not $RefreshType -and -not $LimitingCollectionId -and -not $LimitingCollectionName) {
            throw "At least one property to update must be specified (NewName, Comment, RefreshType, or LimitingCollection)."
        }

        # Convert RefreshType string to integer if provided
        $refreshTypeInt = $null
        if ($RefreshType) {
            $refreshTypeInt = switch ($RefreshType) {
                'Manual' { 1 }
                '1' { 1 }
                'Periodic' { 2 }
                '2' { 2 }
                'Continuous' { 4 }
                '4' { 4 }
                'Both' { 6 }
                '6' { 6 }
                default { $null }
            }
        }

        # Inform about schedule behavior when RefreshType includes Periodic
        if ($refreshTypeInt -and ($refreshTypeInt -eq 2 -or $refreshTypeInt -eq 6)) {
            Write-Verbose "RefreshType set to Periodic/Both. The collection will keep its existing schedule or use a default schedule."
            Write-Verbose "Note: To update RefreshSchedule, use the Set-CMASCollectionSchedule function."
        }
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
                        throw "Collection with name '$CollectionName' not found."
                    }
                    # Handle multiple collections with same name
                    if ($targetCollection -is [array] -and $targetCollection.Count -gt 1) {
                        throw "Multiple collections found with name '$CollectionName'. Use -CollectionId to specify which one to modify."
                    }
                }
                'ById' {
                    Write-Verbose "Resolving collection by ID: $CollectionId"
                    $targetCollection = Get-CMASCollection -CollectionId $CollectionId
                    if (-not $targetCollection) {
                        throw "Collection with ID '$CollectionId' not found."
                    }
                }
                'ByValue' {
                    Write-Verbose "Using provided collection object"
                    $targetCollection = $InputObject
                    if (-not $targetCollection.CollectionID) {
                        throw "Invalid collection object. Missing CollectionID property."
                    }
                }
            }

            # Build the update object with required properties and properties that should be changed
            # Always include required fields for PUT/PATCH operations
            $updateObject = @{
                CollectionID = $targetCollection.CollectionID
                Name = $targetCollection.Name
                CollectionType = $targetCollection.CollectionType
                LimitToCollectionID = $targetCollection.LimitToCollectionID
                RefreshType = $targetCollection.RefreshType
            }

            # Include Comment if it exists on the target collection
            if ($targetCollection.PSObject.Properties.Name -contains 'Comment' -and $null -ne $targetCollection.Comment) {
                $updateObject.Comment = $targetCollection.Comment
            }

            # Only include RefreshSchedule if it exists and has a valid value
            # AND we're not explicitly updating it (to avoid null conflicts)
            # This avoids sending null or empty values which cause API errors
            if (-not $RefreshSchedule -and ($targetCollection.PSObject.Properties.Name -contains 'RefreshSchedule')) {
                $schedule = $targetCollection.RefreshSchedule
                $hasValidSchedule = $false

                if ($null -ne $schedule -and $schedule -isnot [System.DBNull]) {
                    if ($schedule -is [array]) {
                        $hasValidSchedule = $schedule.Count -gt 0
                    } else {
                        $hasValidSchedule = $true
                    }
                }

                if ($hasValidSchedule) {
                    # Ensure RefreshSchedule is always an array for PUT operations
                    $updateObject.RefreshSchedule = if ($schedule -is [array]) { $schedule } else { @($schedule) }
                }
            }

            $changeDescription = @()

            # Update Name
            if ($NewName) {
                if ($NewName -ne $targetCollection.Name) {
                    # Check if new name already exists
                    $existingCollection = Get-CMASCollection -Name $NewName
                    if ($existingCollection) {
                        throw "A collection with the name '$NewName' already exists."
                    }
                    $updateObject.Name = $NewName
                    $changeDescription += "Name: '$($targetCollection.Name)' -> '$NewName'"
                } else {
                    Write-Verbose "NewName is the same as current name, skipping."
                }
            }

            # Update Comment
            if ($PSBoundParameters.ContainsKey('Comment')) {
                if ($Comment -ne $targetCollection.Comment) {
                    $updateObject.Comment = $Comment
                    $changeDescription += "Comment: '$($targetCollection.Comment)' -> '$Comment'"
                } else {
                    Write-Verbose "Comment is the same as current comment, skipping."
                }
            }

            # Update RefreshType
            if ($refreshTypeInt -and $refreshTypeInt -ne $targetCollection.RefreshType) {
                $updateObject.RefreshType = $refreshTypeInt
                $changeDescription += "RefreshType: $($targetCollection.RefreshType) -> $refreshTypeInt"
            }

            # Note: RefreshSchedule updates are blocked in the begin block
            # The Admin Service API does not support RefreshSchedule operations
            # Use Set-CMASCollectionSchedule instead for schedule management via CIM

            # Update LimitingCollection
            $targetLimitingCollectionId = $null
            if ($LimitingCollectionId) {
                $targetLimitingCollectionId = $LimitingCollectionId
            } elseif ($LimitingCollectionName) {
                Write-Verbose "Resolving LimitingCollectionName '$LimitingCollectionName' to CollectionID..."
                $limitingCollection = Get-CMASCollection -Name $LimitingCollectionName
                if (-not $limitingCollection) {
                    throw "Limiting collection with name '$LimitingCollectionName' not found."
                }
                $targetLimitingCollectionId = $limitingCollection.CollectionID
                Write-Verbose "Resolved limiting collection to ID: $targetLimitingCollectionId"
            }

            if ($targetLimitingCollectionId) {
                if ($targetLimitingCollectionId -ne $targetCollection.LimitToCollectionID) {
                    # Verify limiting collection exists
                    Write-Verbose "Verifying limiting collection '$targetLimitingCollectionId' exists..."
                    $path = "wmi/SMS_Collection('$targetLimitingCollectionId')"
                    $limitingRes = Invoke-CMASApi -Path $path

                    if (-not $limitingRes.value -or $limitingRes.value.Count -eq 0) {
                        throw "Limiting collection '$targetLimitingCollectionId' not found."
                    }

                    $updateObject.LimitToCollectionID = $targetLimitingCollectionId
                    $changeDescription += "LimitToCollectionID: '$($targetCollection.LimitToCollectionID)' -> '$targetLimitingCollectionId'"
                } else {
                    Write-Verbose "LimitingCollectionId is the same as current limiting collection, skipping."
                }
            }

            # Check if there are actually changes to make
            if ($changeDescription.Count -eq 0) {
                Write-Warning "No changes detected. All specified values match current collection properties."
                if ($PassThru) {
                    return $targetCollection
                }
                return
            }

            $description = "collection '$($targetCollection.Name)' ($($targetCollection.CollectionID)): $($changeDescription -join ', ')"

            if ($PSCmdlet.ShouldProcess($description, "Update Configuration Manager collection")) {
                Write-Verbose "Updating collection: $($targetCollection.Name) ($($targetCollection.CollectionID))"
                foreach ($change in $changeDescription) {
                    Write-Verbose "  $change"
                }

                Write-Verbose "Update object being sent to API:"
                Write-Verbose ($updateObject | ConvertTo-Json -Depth 10 -Compress)

                # Update the collection via PUT to SMS_Collection
                $updatePath = "wmi/SMS_Collection('$($targetCollection.CollectionID)')"
                $result = Invoke-CMASApi -Path $updatePath -Method PUT -Body $updateObject

                Write-Verbose "Collection updated successfully"

                if ($PassThru) {
                    Write-Verbose "Retrieving updated collection..."
                    Start-Sleep -Seconds 2  # Brief delay to allow replication

                    # Retrieve by ID since name might have changed
                    $updatedCollection = Get-CMASCollection -CollectionId $targetCollection.CollectionID

                    if ($updatedCollection) {
                        Write-Verbose "Successfully retrieved updated collection"
                        return $updatedCollection
                    } else {
                        Write-Warning "Collection was updated but could not be retrieved immediately."
                    }
                } else {
                    Write-Host "Collection '$($targetCollection.Name)' updated successfully." -ForegroundColor Green
                }
            }
        }
        catch {
            Write-Error "Failed to update collection '$($targetCollection.Name)': $_"
            throw
        }
    }
}

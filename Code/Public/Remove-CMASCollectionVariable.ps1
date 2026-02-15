function Remove-CMASCollectionVariable {
    <#
        .SYNOPSIS
            Removes collection variables from a Configuration Manager collection via the Admin Service.

        .DESCRIPTION
            This function removes custom variables that are assigned to a specific collection in Configuration Manager
            using the Admin Service API. Collection variables can be removed by exact name or using wildcard patterns
            to remove multiple variables at once.

            The function supports identifying the target collection by either collection name or CollectionID.
            Supports pipeline input from Get-CMASCollection or Get-CMASCollectionVariable.

        .PARAMETER CollectionName
            The name of the collection to remove variables from. Either CollectionName or CollectionID must be specified.

        .PARAMETER CollectionID
            The CollectionID of the collection to remove variables from. Either CollectionName or CollectionID must be specified.

        .PARAMETER VariableName
            The name of the variable(s) to remove. Supports wildcard patterns (*) for removing multiple variables.
            If using wildcards, all matching variables will be removed.

        .PARAMETER Force
            If specified, suppresses confirmation prompts when removing variables.

        .PARAMETER WhatIf
            Shows what would happen if the cmdlet runs. The cmdlet is not run.

        .PARAMETER Confirm
            Prompts you for confirmation before running the cmdlet.

        .EXAMPLE
            Remove-CMASCollectionVariable -CollectionName "Test Collection" -VariableName "OSDComputerOU" -Force
            Removes the collection variable named "OSDComputerOU" from collection "Test Collection" without confirmation.

        .EXAMPLE
            Remove-CMASCollectionVariable -CollectionID "SMS00001" -VariableName "AppPath"
            Removes the collection variable named "AppPath" from the collection with CollectionID SMS00001 with confirmation prompt.

        .EXAMPLE
            Remove-CMASCollectionVariable -CollectionName "Production Servers" -VariableName "Temp*" -Force
            Removes all collection variables starting with "Temp" from collection "Production Servers" without confirmation.

        .EXAMPLE
            Get-CMASCollection -Name "Test Collection" | Remove-CMASCollectionVariable -VariableName "OSDVar" -Force
            Uses pipeline input to remove a collection variable.

        .EXAMPLE
            Get-CMASCollectionVariable -CollectionName "Production Servers" -VariableName "OldVar*" | Remove-CMASCollectionVariable -Force
            Removes all variables matching the pattern by piping from Get-CMASCollectionVariable.

        .EXAMPLE
            Remove-CMASCollectionVariable -CollectionName "Test Collection" -VariableName "TestVar" -WhatIf
            Shows what would be removed without actually removing the variable.

        .NOTES
            This function is part of the SCCM Admin Service module.
            Requires an active connection established via Connect-CMAS.

            The function uses the Admin Service REST API to interact with the SMS_CollectionSettings WMI class.
            When removing variables, the entire SMS_CollectionSettings object is updated. If all variables are
            removed, an empty CollectionVariables array is maintained to preserve the settings object.

            Returns the removed variable object(s) to the pipeline.

        .LINK
            Connect-CMAS
            Get-CMASCollection
            Get-CMASCollectionVariable
            New-CMASCollectionVariable
    #>
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High', DefaultParameterSetName='ByCollectionName')]
    param(
        [Parameter(Mandatory=$false, ParameterSetName='ByCollectionName', Position=0, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$CollectionName,

        [Parameter(Mandatory=$false, ParameterSetName='ByCollectionID', Position=0, ValueFromPipelineByPropertyName=$true)]
        [string]$CollectionID,

        [Parameter(Mandatory=$true, Position=1, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [SupportsWildcards()]
        [Alias('Name')]
        [string]$VariableName,

        [Parameter(Mandatory=$false)]
        [switch]$Force
    )

    begin {
        # Validate connection
        if (-not $script:CMASConnection.SiteServer) {
            throw "No active connection to SCCM Admin Service. Run Connect-CMAS first."
        }

        # Collection to hold removed variables
        $removedVariables = @()
    }

    process {
        try {
            # Validate that either CollectionName or CollectionID is specified
            if (-not $CollectionName -and -not $CollectionID) {
                throw "Either CollectionName or CollectionID must be specified."
            }

            # Resolve collection to CollectionID if needed
            $targetCollectionID = $null
            $targetCollectionName = $null

            if ($CollectionID) {
                $targetCollectionID = $CollectionID
                Write-Verbose "Using CollectionID: $targetCollectionID"

                # Get collection name for display purposes
                $collection = Get-CMASCollection -CollectionID $targetCollectionID
                if (-not $collection) {
                    throw "Collection with CollectionID '$targetCollectionID' not found."
                }
                $targetCollectionName = $collection.Name
            }
            elseif ($CollectionName) {
                Write-Verbose "Resolving CollectionName '$CollectionName' to CollectionID..."
                $collection = Get-CMASCollection -Name $CollectionName
                if (-not $collection) {
                    throw "Collection with name '$CollectionName' not found."
                }
                if (@($collection).Count -gt 1) {
                    throw "Multiple collections found with name '$CollectionName'. Use CollectionID instead."
                }
                $targetCollectionID = $collection.CollectionID
                $targetCollectionName = $collection.Name
                Write-Verbose "Resolved collection to CollectionID: $targetCollectionID"
            }

            # Get current collection settings
            Write-Verbose "Retrieving collection settings for CollectionID '$targetCollectionID'..."
            $settingsPath = "wmi/SMS_CollectionSettings('$targetCollectionID')"

            $existingSettings = $null
            try {
                $response = Invoke-CMASApi -Path $settingsPath

                # Extract settings from response
                $existingSettings = if ($response.value) {
                    $response.value | Select-Object -First 1
                } else {
                    $response
                }

                if (-not $existingSettings) {
                    Write-Warning "No collection settings found for collection '$targetCollectionName' (CollectionID: $targetCollectionID)."
                    return
                }
            }
            catch {
                if ($_.Exception.Message -like "*404*" -or $_.Exception.Message -like "*Not Found*") {
                    Write-Warning "No collection settings found for collection '$targetCollectionName' (CollectionID: $targetCollectionID)."
                    return
                }
                else {
                    throw
                }
            }

            # Check if collection has any variables
            if (-not $existingSettings.CollectionVariables -or @($existingSettings.CollectionVariables).Count -eq 0) {
                Write-Warning "Collection '$targetCollectionName' has no variables to remove."
                return
            }

            # Convert to array for consistency
            $currentVariables = @($existingSettings.CollectionVariables)
            Write-Verbose "Found $($currentVariables.Count) existing variable(s)"

            # Find variables to remove using wildcard matching
            $variablesToRemove = @()
            $variablesToKeep = @()

            # Check if VariableName contains wildcards
            $hasWildcard = $VariableName -match '[*?]'

            foreach ($var in $currentVariables) {
                if ($hasWildcard) {
                    # Use wildcard matching
                    if ($var.Name -like $VariableName) {
                        $variablesToRemove += $var
                        Write-Verbose "Matched variable for removal: $($var.Name)"
                    }
                    else {
                        $variablesToKeep += $var
                    }
                }
                else {
                    # Exact match
                    if ($var.Name -eq $VariableName) {
                        $variablesToRemove += $var
                        Write-Verbose "Found exact match for removal: $($var.Name)"
                    }
                    else {
                        $variablesToKeep += $var
                    }
                }
            }

            # Check if any variables were found to remove
            if ($variablesToRemove.Count -eq 0) {
                Write-Warning "No variables matching '$VariableName' found on collection '$targetCollectionName'."
                return
            }

            Write-Verbose "Variables to remove: $($variablesToRemove.Count)"
            Write-Verbose "Variables to keep: $($variablesToKeep.Count)"

            # Build description for ShouldProcess
            if ($variablesToRemove.Count -eq 1) {
                $description = "collection variable '$($variablesToRemove[0].Name)' from collection '$targetCollectionName' (CollectionID: $targetCollectionID)"
            }
            else {
                $varNames = ($variablesToRemove | ForEach-Object { $_.Name }) -join "', '"
                $description = "$($variablesToRemove.Count) collection variables ('$varNames') from collection '$targetCollectionName' (CollectionID: $targetCollectionID)"
            }

            # Determine if confirmation is needed
            $shouldProcessConfirm = $true
            if ($Force) {
                # Force parameter overrides confirmation
                $shouldProcessConfirm = $PSCmdlet.ShouldProcess($description, "Remove")
            }
            else {
                # Show confirmation prompt
                $shouldProcessConfirm = $PSCmdlet.ShouldProcess($description, "Remove collection variable(s)")
            }

            if ($shouldProcessConfirm) {
                Write-Verbose "Removing $($variablesToRemove.Count) variable(s)..."

                # Prepare the updated settings
                $updateBody = @{
                    CollectionID = $targetCollectionID
                    CollectionVariables = $variablesToKeep
                }

                # Copy required properties
                if ($existingSettings.LocaleID) {
                    $updateBody.LocaleID = $existingSettings.LocaleID
                }
                else {
                    $updateBody.LocaleID = 1033
                }

                if ($existingSettings.SourceSite) {
                    $updateBody.SourceSite = $existingSettings.SourceSite
                }

                # Update the settings
                $updatePath = "wmi/SMS_CollectionSettings('$targetCollectionID')"
                $result = Invoke-CMASApi -Path $updatePath -Method PUT -Body $updateBody

                if ($result) {
                    Write-Verbose "Collection variable(s) removed successfully"

                    # Add collection information to the removed variables and return them
                    foreach ($var in $variablesToRemove) {
                        $var | Add-Member -NotePropertyName 'CollectionID' -NotePropertyValue $targetCollectionID -Force
                        $var | Add-Member -NotePropertyName 'CollectionName' -NotePropertyValue $targetCollectionName -Force

                        # Format output - exclude WMI and OData metadata
                        $output = $var | Select-Object -Property * -ExcludeProperty __*, @odata*
                        $removedVariables += $output
                    }

                    # Output summary message
                    if ($variablesToRemove.Count -eq 1) {
                        Write-Host "Collection variable '$($variablesToRemove[0].Name)' removed from collection '$targetCollectionName'." -ForegroundColor Green
                    }
                    else {
                        Write-Host "Removed $($variablesToRemove.Count) collection variable(s) from collection '$targetCollectionName'." -ForegroundColor Green
                    }
                }
                else {
                    Write-Error "Failed to remove collection variable(s). No result returned from API."
                }
            }
            else {
                Write-Verbose "Operation cancelled by user or WhatIf"
            }
        }
        catch {
            Write-Error "Failed to remove collection variable: $($_.Exception.Message)"
            Write-Verbose "Error details: $($_ | Out-String)"
        }
    }

    end {
        # Return all removed variables
        if ($removedVariables.Count -gt 0) {
            return $removedVariables
        }
    }
}

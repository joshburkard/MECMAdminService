function New-CMASCollectionVariable {
    <#
        .SYNOPSIS
            Creates a new collection variable for a Configuration Manager collection via the Admin Service.

        .DESCRIPTION
            This function creates a custom variable that can be assigned to a specific collection in Configuration Manager
            using the Admin Service API. Collection variables are name-value pairs that can be used in task sequences,
            scripts, and other Configuration Manager operations for all members of the collection.

            Variables can be marked as masked (sensitive) to hide their values in the Configuration Manager console.
            The function supports identifying the target collection by either collection name or CollectionID.

        .PARAMETER CollectionName
            The name of the collection to create the variable for. Either CollectionName or CollectionID must be specified.

        .PARAMETER CollectionID
            The CollectionID of the collection to create the variable for. Either CollectionName or CollectionID must be specified.

        .PARAMETER VariableName
            The name of the variable to create. Variable names should not contain spaces or special characters.
            The name must be unique for the collection.

        .PARAMETER VariableValue
            The value to assign to the variable. Can be any string value.

        .PARAMETER IsMasked
            If specified, marks the variable as masked (sensitive). Masked variables have their values hidden
            in the Configuration Manager console for security purposes.

        .PARAMETER PassThru
            If specified, returns the created variable object.

        .EXAMPLE
            New-CMASCollectionVariable -CollectionName "Production Servers" -VariableName "OSDComputerOU" -VariableValue "OU=Servers,DC=contoso,DC=com"
            Creates a new collection variable named "OSDComputerOU" with the specified OU path for the "Production Servers" collection.

        .EXAMPLE
            New-CMASCollectionVariable -CollectionID "SMS00001" -VariableName "AppPath" -VariableValue "C:\Apps\MyApp" -PassThru
            Creates a new collection variable by CollectionID and returns the created variable object.

        .EXAMPLE
            New-CMASCollectionVariable -CollectionName "Finance Workstations" -VariableName "DBPassword" -VariableValue "P@ssw0rd" -IsMasked
            Creates a new masked (sensitive) collection variable for storing a password.

        .EXAMPLE
            New-CMASCollectionVariable -CollectionName "Test Collection" -VariableName "InstallPath" -VariableValue "D:\Software"
            Creates a simple collection variable for use in deployment task sequences.

        .NOTES
            This function is part of the SCCM Admin Service module.
            Requires an active connection established via Connect-CMAS.

            The function uses the Admin Service REST API to interact with the SMS_CollectionSettings WMI class.
            Variable names must be unique per collection. If a variable with the same name already exists,
            the function will fail.

            Collection variables are commonly used in:
            - Operating System Deployment (OSD) task sequences
            - Application deployment customization
            - Script execution with collection-specific values
            - Configuration baselines

        .LINK
            Connect-CMAS
            Get-CMASCollection
            Get-CMASCollectionVariable
    #>
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
    param(
        [Parameter(Mandatory=$false, ParameterSetName='ByCollectionName')]
        [ValidateNotNullOrEmpty()]
        [string]$CollectionName,

        [Parameter(Mandatory=$false, ParameterSetName='ByCollectionID')]
        [ValidateNotNullOrEmpty()]
        [string]$CollectionID,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^[a-zA-Z0-9_-]+$')]
        [string]$VariableName,

        [Parameter(Mandatory=$true)]
        [AllowEmptyString()]
        [string]$VariableValue,

        [Parameter(Mandatory=$false)]
        [switch]$IsMasked,

        [Parameter(Mandatory=$false)]
        [switch]$PassThru
    )

    begin {
        # Validate connection
        if (-not $script:CMASConnection.SiteServer) {
            throw "No active connection to SCCM Admin Service. Run Connect-CMAS first."
        }

        # Validate that either CollectionName or CollectionID is specified
        if (-not $CollectionName -and -not $CollectionID) {
            throw "Either CollectionName or CollectionID must be specified."
        }
    }

    process {
        try {
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

            # Check if collection settings already exist for this collection
            Write-Verbose "Checking for existing collection settings for CollectionID '$targetCollectionID'..."
            $settingsPath = "wmi/SMS_CollectionSettings('$targetCollectionID')"

            $existingSettings = $null
            $settingsExist = $false

            try {
                $response = Invoke-CMASApi -Path $settingsPath

                # Extract settings from response - API returns { value: [object] }
                $existingSettings = if ($response.value) {
                    $response.value | Select-Object -First 1
                } else {
                    $response
                }

                if ($existingSettings) {
                    # Settings exist
                    $settingsExist = $true
                    Write-Verbose "Found existing CollectionSettings for CollectionID: $targetCollectionID"

                    # Get existing variables for this collection
                    if ($existingSettings.CollectionVariables) {
                        Write-Verbose "Found $(@($existingSettings.CollectionVariables).Count) existing variables"
                        # Check if variable already exists
                        $existingVar = $existingSettings.CollectionVariables | Where-Object { $_.Name -eq $VariableName }
                        if ($existingVar) {
                            throw "A variable with name '$VariableName' already exists for collection '$targetCollectionName'. Use Set-CMASCollectionVariable to modify it."
                        }
                    } else {
                        Write-Verbose "No existing variables found"
                    }
                }
            }
            catch {
                # Check if this is a 404 error (settings don't exist) or another error
                if ($_.Exception.Message -like "*404*" -or $_.Exception.Message -like "*Not Found*") {
                    # Settings don't exist (404 error expected), need to create them
                    Write-Verbose "No existing CollectionSettings found for collection. Will create new CollectionSettings..."
                    $settingsExist = $false
                }
                else {
                    # This is a different error (like duplicate variable), re-throw it
                    throw
                }
            }

            # Build the new variable object
            $newVariable = @{
                Name = $VariableName
                Value = $VariableValue
                IsMasked = $IsMasked.IsPresent
            }

            $description = "collection variable '$VariableName' for collection '$targetCollectionName' (CollectionID: $targetCollectionID)"

            if ($PSCmdlet.ShouldProcess($description, "Create new collection variable")) {
                Write-Verbose "Creating collection variable: $VariableName"
                Write-Verbose "Value: $(if($IsMasked){'[MASKED]'}else{$VariableValue})"
                Write-Verbose "IsMasked: $($IsMasked.IsPresent)"
                Write-Verbose "CollectionID: $targetCollectionID"

                # Determine the variables array
                $variablesArray = @()
                if ($settingsExist) {
                    # Add to existing variables
                    if ($existingSettings.CollectionVariables) {
                        $variablesArray = @($existingSettings.CollectionVariables)
                    }
                }
                # Add the new variable
                $variablesArray = @($variablesArray) + @($newVariable)

                # Prepare the body for PUT
                $updateBody = @{
                    CollectionID = $targetCollectionID
                    CollectionVariables = $variablesArray
                }

                # Add ReplicateToSubSites if it exists in settings
                if ($settingsExist -and $null -ne $existingSettings.ReplicateToSubSites) {
                    $updateBody.ReplicateToSubSites = $existingSettings.ReplicateToSubSites
                }

                # Use PUT to create or update
                $updatePath = "wmi/SMS_CollectionSettings('$targetCollectionID')"
                $result = Invoke-CMASApi -Path $updatePath -Method PUT -Body $updateBody

                if ($result) {
                    Write-Verbose "Collection variable created successfully"

                    if ($PassThru) {
                        # Retrieve the settings again to get the created variable
                        Write-Verbose "PassThru requested - retrieving updated settings..."
                        Start-Sleep -Seconds 2

                        $updatedResponse = Invoke-CMASApi -Path $settingsPath

                        # Extract settings from response - API returns { value: [object] }
                        $updatedSettings = if ($updatedResponse.value) {
                            $updatedResponse.value | Select-Object -First 1
                        } else {
                            $updatedResponse
                        }

                        Write-Verbose "Retrieved settings: $($updatedSettings -ne $null)"
                        Write-Verbose "CollectionVariables exists: $($null -ne $updatedSettings.CollectionVariables)"

                        if ($updatedSettings -and $updatedSettings.CollectionVariables) {
                            Write-Verbose "Number of variables in settings: $(@($updatedSettings.CollectionVariables).Count)"
                            Write-Verbose "Looking for variable: $VariableName"

                            # Find the newly created variable
                            $createdVariable = $updatedSettings.CollectionVariables | Where-Object { $_.Name -eq $VariableName }

                            if ($createdVariable) {
                                # Add collection information to output
                                $createdVariable | Add-Member -NotePropertyName 'CollectionID' -NotePropertyValue $targetCollectionID -Force
                                $createdVariable | Add-Member -NotePropertyName 'CollectionName' -NotePropertyValue $targetCollectionName -Force

                                # Format output - exclude WMI and OData metadata
                                $output = $createdVariable | Select-Object -Property * -ExcludeProperty __*, @odata*

                                Write-Verbose "Successfully retrieved variable"
                                return $output
                            } else {
                                Write-Verbose "Variable names in settings: $($updatedSettings.CollectionVariables.Name -join ', ')"
                                Write-Warning "Variable was created but could not be retrieved immediately."
                            }
                        } else {
                            Write-Warning "Variable was created but could not be retrieved immediately."
                        }
                    } else {
                        Write-Host "Collection variable '$VariableName' created successfully for collection '$targetCollectionName'." -ForegroundColor Green
                    }
                } else {
                    Write-Error "Failed to create collection variable. No result returned from API."
                }
            }
        }
        catch {
            # Just throw the error - don't Write-Error first as it shows up in tests
            throw "Failed to create collection variable '$VariableName' for collection '$targetCollectionName': $_"
        }
    }
}

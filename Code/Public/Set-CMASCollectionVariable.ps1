function Set-CMASCollectionVariable {
    <#
        .SYNOPSIS
            Modifies an existing collection variable for a Configuration Manager collection via the Admin Service.

        .DESCRIPTION
            This function modifies the properties of an existing custom variable that is assigned to a specific
            collection in Configuration Manager using the Admin Service API. You can change the variable's value
            and/or its masked (sensitive) status.

            Collection variables are name-value pairs that can be used in task sequences, scripts, and other
            Configuration Manager operations. The function supports identifying the target collection by either
            collection name or CollectionID.

        .PARAMETER CollectionName
            The name of the collection containing the variable to modify. Either CollectionName or CollectionID must be specified.

        .PARAMETER CollectionID
            The CollectionID of the collection containing the variable to modify. Either CollectionName or CollectionID must be specified.

        .PARAMETER VariableName
            The name of the variable to modify. The variable must already exist on the collection.

        .PARAMETER VariableValue
            The new value to assign to the variable. Can be any string value.

        .PARAMETER IsMasked
            If specified, marks the variable as masked (sensitive). Masked variables have their values hidden
            in the Configuration Manager console for security purposes.

        .PARAMETER IsNotMasked
            If specified, marks the variable as not masked (visible). This allows you to unmask a previously masked variable.

        .PARAMETER PassThru
            If specified, returns the modified variable object.

        .EXAMPLE
            Set-CMASCollectionVariable -CollectionName "Production Servers" -VariableName "OSDComputerOU" -VariableValue "OU=Servers,DC=contoso,DC=com"
            Updates the value of the collection variable "OSDComputerOU" for collection "Production Servers".

        .EXAMPLE
            Set-CMASCollectionVariable -CollectionID "SMS00001" -VariableName "AppPath" -VariableValue "C:\Apps\MyApp" -PassThru
            Updates a collection variable by CollectionID and returns the modified variable object.

        .EXAMPLE
            Set-CMASCollectionVariable -CollectionName "Finance Workstations" -VariableName "DBPassword" -VariableValue "NewP@ssw0rd" -IsMasked
            Updates a collection variable and marks it as masked (sensitive).

        .EXAMPLE
            Set-CMASCollectionVariable -CollectionName "Test Collection" -VariableName "TestVar" -VariableValue "Public" -IsNotMasked
            Updates a variable and explicitly sets it as not masked (visible).

        .NOTES
            This function is part of the SCCM Admin Service module.
            Requires an active connection established via Connect-CMAS.

            The function uses the Admin Service REST API to interact with the SMS_CollectionSettings WMI class.
            The specified variable must already exist on the collection. To create new variables, use New-CMASCollectionVariable.

            Collection variables are commonly used in:
            - Operating System Deployment (OSD) task sequences
            - Application deployment customization
            - Script execution with collection-specific values
            - Configuration baselines

        .LINK
            Connect-CMAS
            Get-CMASCollection
            Get-CMASCollectionVariable
            New-CMASCollectionVariable
            Remove-CMASCollectionVariable
    #>
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium', DefaultParameterSetName='ByCollectionName')]
    param(
        [Parameter(Mandatory=$false, ParameterSetName='ByCollectionName', Position=0, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$CollectionName,

        [Parameter(Mandatory=$false, ParameterSetName='ByCollectionID', Position=0, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$CollectionID,

        [Parameter(Mandatory=$true, Position=1, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [Alias('Name')]
        [string]$VariableName,

        [Parameter(Mandatory=$true, Position=2)]
        [AllowEmptyString()]
        [Alias('Value')]
        [string]$VariableValue,

        [Parameter(Mandatory=$false)]
        [switch]$IsMasked,

        [Parameter(Mandatory=$false)]
        [switch]$IsNotMasked,

        [Parameter(Mandatory=$false)]
        [switch]$PassThru
    )

    begin {
        # Validate connection
        if (-not $script:CMASConnection.SiteServer) {
            throw "No active connection to SCCM Admin Service. Run Connect-CMAS first."
        }

        # Validate that IsMasked and IsNotMasked are not both specified
        if ($IsMasked -and $IsNotMasked) {
            throw "Cannot specify both -IsMasked and -IsNotMasked. Choose one or neither."
        }
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
            }
            catch {
                if ($_.Exception.Message -like "*404*" -or $_.Exception.Message -like "*Not Found*") {
                    throw "No collection settings found for collection '$targetCollectionName' (CollectionID: $targetCollectionID). Use New-CMASCollectionVariable to create variables."
                }
                else {
                    throw
                }
            }

            # Check if collection has any variables
            if (-not $existingSettings.CollectionVariables) {
                throw "Collection '$targetCollectionName' has no variables configured. Use New-CMASCollectionVariable to create variables."
            }

            # Find the variable to modify
            $variables = @($existingSettings.CollectionVariables)
            $existingVariable = $variables | Where-Object { $_.Name -eq $VariableName }

            if (-not $existingVariable) {
                throw "Variable '$VariableName' not found on collection '$targetCollectionName'. Use New-CMASCollectionVariable to create it."
            }

            # Determine the new masked state
            $newMaskedState = $existingVariable.IsMasked
            if ($IsMasked) {
                $newMaskedState = $true
            }
            elseif ($IsNotMasked) {
                $newMaskedState = $false
            }

            # Check if anything is actually changing
            if ($existingVariable.Value -eq $VariableValue -and $existingVariable.IsMasked -eq $newMaskedState) {
                Write-Verbose "Variable '$VariableName' already has the specified value and masked state. No changes needed."
                if ($PassThru) {
                    $existingVariable | Add-Member -NotePropertyName 'CollectionID' -NotePropertyValue $targetCollectionID -Force
                    $existingVariable | Add-Member -NotePropertyName 'CollectionName' -NotePropertyValue $targetCollectionName -Force
                    return ($existingVariable | Select-Object -Property * -ExcludeProperty __*, @odata*)
                }
                return
            }

            $description = "collection variable '$VariableName' for collection '$targetCollectionName' (CollectionID: $targetCollectionID)"

            if ($PSCmdlet.ShouldProcess($description, "Modify collection variable")) {
                Write-Verbose "Modifying collection variable: $VariableName"
                Write-Verbose "Old Value: $(if($existingVariable.IsMasked){'[MASKED]'}else{$existingVariable.Value})"
                Write-Verbose "New Value: $(if($newMaskedState){'[MASKED]'}else{$VariableValue})"
                Write-Verbose "Old IsMasked: $($existingVariable.IsMasked)"
                Write-Verbose "New IsMasked: $newMaskedState"

                # Update the variable in the array
                $updatedVariables = @()
                foreach ($var in $variables) {
                    if ($var.Name -eq $VariableName) {
                        $updatedVariables += @{
                            Name = $VariableName
                            Value = $VariableValue
                            IsMasked = $newMaskedState
                        }
                    }
                    else {
                        $updatedVariables += @{
                            Name = $var.Name
                            Value = $var.Value
                            IsMasked = $var.IsMasked
                        }
                    }
                }

                # Prepare the body for PUT
                $updateBody = @{
                    CollectionID = $targetCollectionID
                    CollectionVariables = $updatedVariables
                }

                if ($existingSettings.LocaleID) {
                    $updateBody.LocaleID = $existingSettings.LocaleID
                }
                else {
                    $updateBody.LocaleID = 1033
                }

                if ($existingSettings.SourceSite) {
                    $updateBody.SourceSite = $existingSettings.SourceSite
                }

                if ($null -ne $existingSettings.ReplicateToSubSites) {
                    $updateBody.ReplicateToSubSites = $existingSettings.ReplicateToSubSites
                }

                # Use PUT to update
                $updatePath = "wmi/SMS_CollectionSettings('$targetCollectionID')"
                $result = Invoke-CMASApi -Path $updatePath -Method PUT -Body $updateBody

                if ($result) {
                    Write-Verbose "Collection variable modified successfully"

                    if ($PassThru) {
                        $updatedVariable = $updatedVariables | Where-Object { $_.Name -eq $VariableName } | Select-Object -First 1
                        if ($updatedVariable) {
                            $output = [PSCustomObject]@{
                                Name = $updatedVariable.Name
                                Value = $updatedVariable.Value
                                IsMasked = $updatedVariable.IsMasked
                                CollectionID = $targetCollectionID
                                CollectionName = $targetCollectionName
                            }
                            return $output
                        }
                    }
                }
            }
        }
        catch {
            throw "Failed to modify collection variable for collection '$targetCollectionName': $_"
        }
    }
}

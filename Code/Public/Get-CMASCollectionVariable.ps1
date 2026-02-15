function Get-CMASCollectionVariable {
    <#
        .SYNOPSIS
            Gets collection variables for a Configuration Manager collection via the Admin Service.

        .DESCRIPTION
            This function retrieves custom variables that are assigned to a specific collection in Configuration Manager
            using the Admin Service API. Collection variables are name-value pairs that can be used in task sequences,
            scripts, and other Configuration Manager operations.

            The function supports identifying the target collection by either collection name or CollectionID.
            You can optionally filter the results to specific variable names using wildcard patterns.

        .PARAMETER CollectionName
            The name of the collection to retrieve variables from. Either CollectionName or CollectionID must be specified.

        .PARAMETER CollectionID
            The CollectionID of the collection to retrieve variables from. Either CollectionName or CollectionID must be specified.

        .PARAMETER VariableName
            Optional. The name of a specific variable to retrieve. Supports wildcard patterns (*).
            If not specified, all variables for the collection are returned.

        .EXAMPLE
            Get-CMASCollectionVariable -CollectionName "Production Servers"
            Retrieves all collection variables for collection "Production Servers".

        .EXAMPLE
            Get-CMASCollectionVariable -CollectionID "SMS00001"
            Retrieves all collection variables for the collection with CollectionID SMS00001.

        .EXAMPLE
            Get-CMASCollectionVariable -CollectionName "Production Servers" -VariableName "OSD*"
            Retrieves all collection variables starting with "OSD" for collection "Production Servers".

        .EXAMPLE
            Get-CMASCollectionVariable -CollectionName "Test Servers" -VariableName "AppPath"
            Retrieves the specific collection variable named "AppPath" for collection "Test Servers".

        .NOTES
            This function is part of the SCCM Admin Service module.
            Requires an active connection established via Connect-CMAS.

            The function queries the SMS_CollectionSettings WMI class via the Admin Service REST API.
            Returns an empty result if the collection has no variables configured.

            Collection variables are commonly used in:
            - Operating System Deployment (OSD) task sequences
            - Application deployment customization
            - Script execution with collection-specific values
            - Configuration baselines

        .LINK
            Connect-CMAS
            Get-CMASCollection
    #>
    [CmdletBinding(DefaultParameterSetName='ByCollectionName')]
    param(
        [Parameter(Mandatory=$false, ParameterSetName='ByCollectionName', Position=0)]
        [ValidateNotNullOrEmpty()]
        [string]$CollectionName,

        [Parameter(Mandatory=$false, ParameterSetName='ByCollectionID', Position=0)]
        [ValidateNotNullOrEmpty()]
        [string]$CollectionID,

        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [SupportsWildcards()]
        [string]$VariableName
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

            # Query for collection settings
            # Note: Using parentheses syntax to properly load lazy properties like CollectionVariables
            Write-Verbose "Retrieving collection variables for CollectionID '$targetCollectionID'..."
            $settingsPath = "wmi/SMS_CollectionSettings('$targetCollectionID')"

            try {
                $response = Invoke-CMASApi -Path $settingsPath

                # Extract settings from response - API returns { value: [object] } when using parentheses syntax
                $settings = if ($response.value) {
                    $response.value | Select-Object -First 1
                } else {
                    $response
                }

                # If no settings found, return empty
                if (-not $settings) {
                    Write-Verbose "No CollectionSettings found for collection '$targetCollectionName' (CollectionID: $targetCollectionID)"
                    return
                }
            }
            catch {
                # 404 means no settings exist for this collection
                if ($_.Exception.Message -like "*404*" -or $_.Exception.Message -like "*Not Found*") {
                    Write-Verbose "No CollectionSettings found for collection '$targetCollectionName' (CollectionID: $targetCollectionID)"
                    return
                }
                else {
                    throw
                }
            }

            # Check if collection has any variables
            if (-not $settings.CollectionVariables) {
                Write-Verbose "Collection '$targetCollectionName' has no variables configured"
                return
            }

            $variables = @($settings.CollectionVariables)
            Write-Verbose "Found $($variables.Count) variable(s) for collection '$targetCollectionName'"

            # Filter by variable name if specified
            if ($VariableName) {
                Write-Verbose "Filtering variables by name: $VariableName"
                $variables = $variables | Where-Object { $_.Name -like $VariableName }
                Write-Verbose "After filtering: $($variables.Count) variable(s) match"
            }

            # If no variables match the filter, return empty
            if ($variables.Count -eq 0) {
                Write-Verbose "No variables match the specified criteria"
                return
            }

            # Return each variable with collection information
            foreach ($var in $variables) {
                # Add collection information to output
                $var | Add-Member -NotePropertyName 'CollectionID' -NotePropertyValue $targetCollectionID -Force
                $var | Add-Member -NotePropertyName 'CollectionName' -NotePropertyValue $targetCollectionName -Force

                # Format output - exclude WMI and OData metadata
                $output = $var | Select-Object -Property * -ExcludeProperty __*, @odata*

                # Return the variable
                Write-Output $output
            }
        }
        catch {
            throw "Failed to retrieve collection variables for collection '$targetCollectionName': $_"
        }
    }
}

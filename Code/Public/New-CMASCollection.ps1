function New-CMASCollection {
    <#
        .SYNOPSIS
            Creates a new Configuration Manager collection via the Admin Service.

        .DESCRIPTION
            This function creates a new device or user collection in Configuration Manager using the Admin Service API.
            You can specify collection properties such as name, type, limiting collection, refresh schedule, and comments.

            The function supports creating both device and user collections with various refresh types:
            - Manual: Collection membership is only updated manually
            - Periodic: Collection membership is updated on a schedule
            - Continuous: Collection membership is continuously evaluated (incremental updates)
            - Both: Combination of Periodic and Continuous refresh

        .PARAMETER Name
            The name of the new collection to create. Must be unique within Configuration Manager.

        .PARAMETER CollectionType
            The type of collection to create: Device or User.
            - Device (2): Creates a device collection
            - User (1): Creates a user collection
            Default is Device.

        .PARAMETER LimitingCollectionId
            The CollectionID of the limiting collection. The new collection can only contain members
            of this limiting collection. For device collections, typically "SMS00001" (All Systems).

        .PARAMETER LimitingCollectionName
            The name of the limiting collection. If specified, the function will look up the
            CollectionID automatically. Either LimitingCollectionId or LimitingCollectionName must be provided.

        .PARAMETER Comment
            Optional comment or description for the collection.

        .PARAMETER RefreshType
            The refresh type for the collection:
            - Manual (1): Manual updates only
            - Periodic (2): Scheduled updates
            - Continuous (4): Incremental updates (continuous evaluation)
            - Both (6): Periodic and Continuous (2 + 4)
            Default is Manual.

        .PARAMETER RefreshSchedule
            Optional. The schedule for periodic updates (used when RefreshType includes Periodic).
            Must be a valid SMS_ST_RecurInterval schedule string.
            Example: For daily updates - @{DaySpan=1; StartTime="20250213000000.000000+***"}

        .PARAMETER PassThru
            Returns the created collection object.

        .EXAMPLE
            New-CMASCollection -Name "My Device Collection" -LimitingCollectionName "All Systems"
            Creates a new device collection with manual refresh, limited to All Systems.

        .EXAMPLE
            New-CMASCollection -Name "Test Servers" -LimitingCollectionId "SMS00001" -RefreshType Periodic -Comment "Test environment servers"
            Creates a device collection with periodic refresh and a comment.

        .EXAMPLE
            New-CMASCollection -Name "My Users" -CollectionType User -LimitingCollectionName "All Users" -RefreshType Continuous
            Creates a user collection with continuous (incremental) updates.

        .EXAMPLE
            New-CMASCollection -Name "Production Servers" -LimitingCollectionId "SMS00001" -RefreshType Both -PassThru
            Creates a device collection with both periodic and continuous refresh, returning the collection object.

        .EXAMPLE
            $schedule = @{
                DaySpan = 1
                StartTime = (Get-Date).AddHours(1).ToString("yyyyMMddHHmmss.000000+***")
            }
            New-CMASCollection -Name "Scheduled Collection" -LimitingCollectionName "All Systems" -RefreshType Periodic -RefreshSchedule $schedule
            Creates a collection with a custom daily refresh schedule.

        .NOTES
            This function is part of the SCCM Admin Service module.
            Requires an active connection established via Connect-CMAS.

            The function uses the Admin Service REST API to POST to the SMS_Collection WMI class.
            Collection names must be unique across all collections in Configuration Manager.

            Collection Types:
            - 0 = Other
            - 1 = User
            - 2 = Device (default)

            Refresh Types:
            - 1 = Manual only
            - 2 = Scheduled (Periodic) only
            - 4 = Incremental (Continuous) only
            - 6 = Scheduled and Incremental (Both)

        .LINK
            Connect-CMAS
            Get-CMASCollection
            Add-CMASCollectionMembershipRule
            Remove-CMASCollectionMembershipRule
    #>
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory=$false)]
        [ValidateSet('Device', 'User', '1', '2')]
        [string]$CollectionType = 'Device',

        [Parameter(Mandatory=$false, ParameterSetName='ByLimitingId')]
        [string]$LimitingCollectionId,

        [Parameter(Mandatory=$false, ParameterSetName='ByLimitingName')]
        [string]$LimitingCollectionName,

        [Parameter(Mandatory=$false)]
        [string]$Comment,

        [Parameter(Mandatory=$false)]
        [ValidateSet('Manual', 'Periodic', 'Continuous', 'Both', '1', '2', '4', '6')]
        [string]$RefreshType = 'Manual',

        [Parameter(Mandatory=$false)]
        [hashtable]$RefreshSchedule,

        [Parameter(Mandatory=$false)]
        [switch]$PassThru
    )

    begin {
        # Validate connection
        if (-not $script:CMASConnection.SiteServer) {
            throw "No active connection to SCCM Admin Service. Run Connect-CMAS first."
        }

        # Validate that a limiting collection is specified
        if (-not $LimitingCollectionId -and -not $LimitingCollectionName) {
            throw "Either LimitingCollectionId or LimitingCollectionName must be specified."
        }

        # Convert CollectionType string to integer
        $collectionTypeInt = switch ($CollectionType) {
            'User' { 1 }
            '1' { 1 }
            'Device' { 2 }
            '2' { 2 }
            default { 2 }
        }

        # Convert RefreshType string to integer
        $refreshTypeInt = switch ($RefreshType) {
            'Manual' { 1 }
            '1' { 1 }
            'Periodic' { 2 }
            '2' { 2 }
            'Continuous' { 4 }
            '4' { 4 }
            'Both' { 6 }
            '6' { 6 }
            default { 1 }
        }

        # Validate RefreshSchedule is provided if RefreshType includes Periodic
        if (($refreshTypeInt -eq 2 -or $refreshTypeInt -eq 6) -and -not $RefreshSchedule) {
            Write-Warning "RefreshType includes Periodic updates but no RefreshSchedule was provided. Using default schedule."
        }
    }

    process {
        try {
            # Resolve LimitingCollectionName to LimitingCollectionId if needed
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

            # Verify limiting collection exists
            Write-Verbose "Verifying limiting collection '$targetLimitingCollectionId' exists..."
            $path = "wmi/SMS_Collection('$targetLimitingCollectionId')"
            $limitingRes = Invoke-CMASApi -Path $path

            if (-not $limitingRes.value -or $limitingRes.value.Count -eq 0) {
                throw "Limiting collection '$targetLimitingCollectionId' not found."
            }

            # Check if collection with the same name already exists
            Write-Verbose "Checking if collection with name '$Name' already exists..."
            $existingCollection = Get-CMASCollection -Name $Name
            if ($existingCollection) {
                throw "A collection with the name '$Name' already exists."
            }

            # Build the collection object
            $newCollection = @{
                Name = $Name
                CollectionType = $collectionTypeInt
                LimitToCollectionID = $targetLimitingCollectionId
                RefreshType = $refreshTypeInt
            }

            # Add optional properties
            if ($Comment) {
                $newCollection.Comment = $Comment
            }

            # Add refresh schedule if provided and RefreshType includes Periodic
            if ($RefreshSchedule -and ($refreshTypeInt -eq 2 -or $refreshTypeInt -eq 6)) {
                # Build SMS_ST_RecurInterval object
                $scheduleToken = @{
                    '@odata.type' = '#AdminService.SMS_ST_RecurInterval'
                }

                # Add schedule properties from the provided hashtable
                foreach ($key in $RefreshSchedule.Keys) {
                    $scheduleToken[$key] = $RefreshSchedule[$key]
                }

                $newCollection.RefreshSchedule = $scheduleToken
            }

            $description = "collection '$Name' (Type: $CollectionType, Limiting: $targetLimitingCollectionId)"

            if ($PSCmdlet.ShouldProcess($description, "Create new Configuration Manager collection")) {
                Write-Verbose "Creating new collection: $Name"
                Write-Verbose "Collection Type: $collectionTypeInt ($(if($collectionTypeInt -eq 1){'User'}else{'Device'}))"
                Write-Verbose "Limiting Collection: $targetLimitingCollectionId"
                Write-Verbose "Refresh Type: $refreshTypeInt"

                # Create the collection via POST to SMS_Collection
                $createPath = "wmi/SMS_Collection"
                $result = Invoke-CMASApi -Path $createPath -Method POST -Body $newCollection

                if ($result) {
                    Write-Verbose "Collection created successfully"

                    # Retrieve the newly created collection
                    if ($PassThru) {
                        Write-Verbose "Retrieving newly created collection..."
                        Start-Sleep -Seconds 2  # Brief delay to allow replication
                        $createdCollection = Get-CMASCollection -Name $Name

                        if ($createdCollection) {
                            Write-Verbose "Successfully retrieved collection: $($createdCollection.CollectionID)"
                            return $createdCollection
                        } else {
                            Write-Warning "Collection was created but could not be retrieved immediately. Try Get-CMASCollection -Name '$Name'"
                        }
                    } else {
                        Write-Host "Collection '$Name' created successfully." -ForegroundColor Green
                    }
                } else {
                    Write-Error "Failed to create collection. No result returned from API."
                }
            }
        }
        catch {
            Write-Error "Failed to create collection '$Name': $_"
            throw
        }
    }
}

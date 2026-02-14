function Set-CMASCollectionSchedule {
    <#
        .SYNOPSIS
            Sets the refresh schedule for a collection using CIM cmdlets.

        .DESCRIPTION
            This function uses CIM (WMI) directly to set the refresh schedule for a Configuration Manager collection.
            This is a workaround for the Admin Service API limitation that doesn't support RefreshSchedule operations.

            ** REQUIREMENTS **:
            - WinRM must be enabled on the SMS Provider server
            - You must have permissions to access the SMS Provider via CIM/WMI
            - Works in PowerShell 5.1 and PowerShell 7.x

            This function creates a schedule token using the same approach as the ConfigurationManager module,
            but works directly with CIM cmdlets so it's compatible with PowerShell 7.x.

        .PARAMETER CollectionName
            The name of the collection to update.

        .PARAMETER CollectionId
            The ID of the collection to update.

        .PARAMETER RecurInterval
            The interval for recurring schedules. Valid values: Minutes, Hours, Days

        .PARAMETER RecurCount
            The number of intervals between recurrences (e.g., 1 for daily, 7 for weekly).

        .PARAMETER StartTime
            Optional. The start date/time for the schedule. Defaults to current time.

        .PARAMETER SiteServer
            Optional. The SMS Provider server name. Uses the connected server from Connect-CMAS if not specified.

        .PARAMETER SiteCode
            Optional. The site code. Uses the connected site from Connect-CMAS if not specified.

        .PARAMETER Credential
            Optional. Credentials for CIM connection. Uses current credentials if not specified.

        .EXAMPLE
            Set-CMASCollectionSchedule -CollectionName "My Collection" -RecurInterval Days -RecurCount 1
            Sets the collection to refresh daily starting now.

        .EXAMPLE
            Set-CMASCollectionSchedule -CollectionId "SMS00100" -RecurInterval Days -RecurCount 7 -StartTime (Get-Date "2026-02-15 02:00")
            Sets the collection to refresh weekly starting at 2 AM on Feb 15.

        .EXAMPLE
            Set-CMASCollectionSchedule -CollectionName "Servers" -RecurInterval Hours -RecurCount 4 -Credential $Cred
            Sets the collection to refresh every 4 hours using specific credentials.

        .NOTES
            This function requires WinRM/CIM access to the SMS Provider server.
            If WinRM is not available, use the SCCM Console or ConfigurationManager PowerShell module instead.

        .LINK
            Set-CMASCollection
            Connect-CMAS
    #>
    [CmdletBinding(DefaultParameterSetName='ByName', SupportsShouldProcess=$true, ConfirmImpact='Medium')]
    param(
        [Parameter(Mandatory=$true, ParameterSetName='ByName')]
        [ValidateNotNullOrEmpty()]
        [string]$CollectionName,

        [Parameter(Mandatory=$true, ParameterSetName='ById')]
        [ValidateNotNullOrEmpty()]
        [string]$CollectionId,

        [Parameter(Mandatory=$true)]
        [ValidateSet('Minutes', 'Hours', 'Days')]
        [string]$RecurInterval,

        [Parameter(Mandatory=$true)]
        [ValidateRange(1, 365)]
        [int]$RecurCount,

        [Parameter(Mandatory=$false)]
        [DateTime]$StartTime = (Get-Date),

        [Parameter(Mandatory=$false)]
        [string]$SiteServer,

        [Parameter(Mandatory=$false)]
        [string]$SiteCode,

        [Parameter(Mandatory=$false)]
        [pscredential]$Credential
    )

    begin {
        # Use stored connection if parameters not provided
        if (-not $SiteServer) {
            $SiteServer = $script:CMASConnection.SiteServer
            if (-not $SiteServer) {
                throw "No SiteServer specified and no active connection. Run Connect-CMAS first or provide -SiteServer parameter."
            }
        }
        if (-not $SiteCode) {
            $SiteCode = $script:CMASConnection.SiteCode
            if (-not $SiteCode) {
                throw "No SiteCode specified and no active connection. Run Connect-CMAS first or provide -SiteCode parameter."
            }
        }
        if (-not $Credential) {
            $Credential = $script:CMASConnection.Credential
        }

        $namespace = "root\sms\site_$SiteCode"
        Write-Verbose "Using SMS Provider: $SiteServer, Namespace: $namespace"
    }

    process {
        try {
            # Create CIM session
            Write-Verbose "Creating CIM session to $SiteServer..."
            $sessionParams = @{
                ComputerName = $SiteServer
                ErrorAction = 'Stop'
            }
            if ($Credential) {
                $sessionParams.Credential = $Credential
            }

            try {
                $cimSession = New-CimSession @sessionParams
            }
            catch {
                throw "Failed to create CIM session to '$SiteServer'. Ensure WinRM is enabled and accessible. Error: $_"
            }

            # Get the collection
            Write-Verbose "Retrieving collection..."
            if ($PSCmdlet.ParameterSetName -eq 'ByName') {
                $collection = Get-CimInstance -CimSession $cimSession -Namespace $namespace `
                    -ClassName SMS_Collection -Filter "Name='$CollectionName'" -ErrorAction Stop
                if (-not $collection) {
                    throw "Collection '$CollectionName' not found."
                }
            }
            else {
                $collection = Get-CimInstance -CimSession $cimSession -Namespace $namespace `
                    -ClassName SMS_Collection -Filter "CollectionID='$CollectionId'" -ErrorAction Stop
                if (-not $collection) {
                    throw "Collection '$CollectionId' not found."
                }
            }

            # Get the lazy properties (RefreshSchedule is a lazy property)
            Write-Verbose "Getting full collection properties..."
            $collection = $collection | Get-CimInstance

            # Create schedule token
            Write-Verbose "Creating schedule token: $RecurInterval every $RecurCount interval(s)"
            $scheduleClass = Get-CimClass -CimSession $cimSession -Namespace $namespace `
                -ClassName SMS_ST_RecurInterval -ErrorAction Stop

            # Build schedule properties hashtable
            $scheduleProperties = @{
                DaySpan = 0
                HourSpan = 0
                MinuteSpan = 0
                StartTime = $StartTime  # CIM expects DateTime object, not string
                IsGMT = $false
            }

            # Set the appropriate span based on interval type
            switch ($RecurInterval) {
                'Minutes' { $scheduleProperties.MinuteSpan = $RecurCount }
                'Hours' { $scheduleProperties.HourSpan = $RecurCount }
                'Days' { $scheduleProperties.DaySpan = $RecurCount }
            }

            Write-Verbose "Schedule properties: Interval=$RecurInterval, Count=$RecurCount, StartTime=$StartTime"
            $scheduleToken = New-CimInstance -CimClass $scheduleClass -Property $scheduleProperties -ClientOnly

            # Update the collection
            $collection.RefreshSchedule = @($scheduleToken)
            $collection.RefreshType = 2  # 2 = Periodic

            $description = "collection '$($collection.Name)' ($($collection.CollectionID)) with $RecurInterval/$RecurCount schedule"

            if ($PSCmdlet.ShouldProcess($description, "Update refresh schedule")) {
                Write-Verbose "Saving collection changes via CIM..."
                Set-CimInstance -CimSession $cimSession -InputObject $collection -ErrorAction Stop
                Write-Host "Successfully updated refresh schedule for collection '$($collection.Name)'" -ForegroundColor Green
            }
        }
        catch {
            Write-Error "Failed to set collection schedule: $_"
            throw
        }
        finally {
            if ($cimSession) {
                Remove-CimSession -CimSession $cimSession
                Write-Verbose "CIM session closed"
            }
        }
    }
}

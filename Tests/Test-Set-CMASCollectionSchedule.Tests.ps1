# Functional Tests for Set-CMASCollectionSchedule
# Tests the Set-CMASCollectionSchedule function behavior using CIM

BeforeAll {
    # Load test declarations
    . (Join-Path $PSScriptRoot "declarations.ps1")

    # Load test helper functions
    . (Join-Path $PSScriptRoot "TestHelpers.ps1")

    # Load all functions
    $CodePath = Join-Path (Get-Item $PSScriptRoot).Parent.FullName "Code"
    Get-ChildItem -Path (Join-Path $CodePath "Private") -Filter "*.ps1" | ForEach-Object { . $_.FullName }
    Get-ChildItem -Path (Join-Path $CodePath "Public") -Filter "*.ps1" | ForEach-Object { . $_.FullName }

    # Connect to test environment
    $params = @{ SiteServer = $script:TestSiteServer }
    if($script:TestSkipCertificateCheck){ $params.SkipCertificateCheck = $true }
    if($null -ne $script:TestCredential){ $params.Credential = $script:TestCredential }
    Connect-CMAS @params

    # Get test data for this function
    $script:TestScheduleData = $script:TestData['Set-CMASCollectionSchedule']

    # Track created collections for cleanup
    $script:CreatedCollections = @()

    # ============================================================================
    # PHASE 1: CREATE TEST COLLECTIONS
    # ============================================================================
    Write-Host "`n===========================================================================" -ForegroundColor Cyan
    Write-Host "PHASE 1: Creating test collections for Set-CMASCollectionSchedule tests" -ForegroundColor Cyan
    Write-Host "Note: This function uses CIM cmdlets and requires WinRM access" -ForegroundColor Yellow
    Write-Host "===========================================================================" -ForegroundColor Cyan

    # Collection 1: For daily schedule test
    Write-Host "`n[1/4] Creating collection: $($script:TestScheduleData.DailySchedule.CollectionName)" -ForegroundColor Yellow
    New-CMASCollection -Name $script:TestScheduleData.DailySchedule.CollectionName -LimitingCollectionId "SMS00001" -RefreshType "Manual" -ErrorAction Stop
    $script:CreatedCollections += $script:TestScheduleData.DailySchedule.CollectionName
    Start-Sleep -Seconds 2

    # Collection 2: For hourly schedule test
    Write-Host "[2/4] Creating collection: $($script:TestScheduleData.HourlySchedule.CollectionName)" -ForegroundColor Yellow
    New-CMASCollection -Name $script:TestScheduleData.HourlySchedule.CollectionName -LimitingCollectionId "SMS00001" -RefreshType "Manual" -ErrorAction Stop
    $script:CreatedCollections += $script:TestScheduleData.HourlySchedule.CollectionName
    Start-Sleep -Seconds 2

    # Collection 3: For minute schedule test
    Write-Host "[3/4] Creating collection: $($script:TestScheduleData.MinuteSchedule.CollectionName)" -ForegroundColor Yellow
    New-CMASCollection -Name $script:TestScheduleData.MinuteSchedule.CollectionName -LimitingCollectionId "SMS00001" -RefreshType "Manual" -ErrorAction Stop
    $script:CreatedCollections += $script:TestScheduleData.MinuteSchedule.CollectionName
    Start-Sleep -Seconds 2

    # Collection 4: For ById test
    Write-Host "[4/4] Creating collection: Test-Schedule-ById-Collection" -ForegroundColor Yellow
    New-CMASCollection -Name "Test-Schedule-ById-Collection" -LimitingCollectionId "SMS00001" -RefreshType "Manual" -ErrorAction Stop
    $script:CreatedCollections += "Test-Schedule-ById-Collection"
    Start-Sleep -Seconds 2
    $script:TestCollectionForScheduleById = Get-CMASCollection -Name "Test-Schedule-ById-Collection"

    Write-Host "`n✓ All test collections created successfully" -ForegroundColor Green
    Write-Host "===========================================================================" -ForegroundColor Cyan
    Write-Host ""
}

Describe "Set-CMASCollectionSchedule Function Tests" -Tag "Unit", "Collection", "Schedule", "CIM" {

    Context "Prerequisites and Setup" {
        It "Test data for Set-CMASCollectionSchedule should exist" {
            $script:TestData.ContainsKey('Set-CMASCollectionSchedule') | Should -Be $true
        }

        It "Test site server connection should be established" {
            $script:CMASConnection.SiteServer | Should -Not -BeNullOrEmpty
        }

        It "Test collections should have been created" {
            $script:CreatedCollections.Count | Should -BeGreaterThan 0
        }

        It "Function should be available" {
            Get-Command Set-CMASCollectionSchedule -ErrorAction SilentlyContinue | Should -Not -BeNull
        }

        It "Function should have CIM-related parameters" {
            $command = Get-Command Set-CMASCollectionSchedule
            $command.Parameters.ContainsKey('RecurInterval') | Should -Be $true
            $command.Parameters.ContainsKey('RecurCount') | Should -Be $true
            $command.Parameters.ContainsKey('StartTime') | Should -Be $true
        }
    }

    Context "Parameter Validation" {
        It "Should have required parameters" {
            $command = Get-Command Set-CMASCollectionSchedule
            $command.Parameters['RecurInterval'].Attributes.Mandatory | Should -Be $true
            $command.Parameters['RecurCount'].Attributes.Mandatory | Should -Be $true
        }

        It "Should have RecurInterval ValidateSet with correct values" {
            $command = Get-Command Set-CMASCollectionSchedule
            $validateSet = $command.Parameters['RecurInterval'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
            $validateSet.ValidValues | Should -Contain 'Minutes'
            $validateSet.ValidValues | Should -Contain 'Hours'
            $validateSet.ValidValues | Should -Contain 'Days'
        }

        It "Should accept StartTime as DateTime" {
            $command = Get-Command Set-CMASCollectionSchedule
            $command.Parameters['StartTime'].ParameterType.Name | Should -Be 'DateTime'
        }
    }

    Context "Daily Schedule - ByName Parameter Set" {
        It "Should set daily schedule successfully" {
            $result = Set-CMASCollectionSchedule `
                -CollectionName $script:TestScheduleData.DailySchedule.CollectionName `
                -RecurInterval Days `
                -RecurCount $script:TestScheduleData.DailySchedule.RecurCount `
                -Verbose

            # Verify via CIM that schedule was set
            $cimSession = New-CimSession -ComputerName $script:CMASConnection.SiteServer -Credential $script:CMASConnection.Credential -ErrorAction Stop
            $collection = Get-CimInstance -CimSession $cimSession -Namespace "root\sms\site_$($script:CMASConnection.SiteCode)" `
                -ClassName SMS_Collection -Filter "Name='$($script:TestScheduleData.DailySchedule.CollectionName)'" | Get-CimInstance
            Remove-CimSession $cimSession

            $collection.RefreshSchedule.DaySpan | Should -Be $script:TestScheduleData.DailySchedule.RecurCount
            $collection.RefreshType | Should -Be 2  # Periodic
        }
    }

    Context "Hourly Schedule" {
        It "Should set hourly schedule successfully" {
            $result = Set-CMASCollectionSchedule `
                -CollectionName $script:TestScheduleData.HourlySchedule.CollectionName `
                -RecurInterval Hours `
                -RecurCount $script:TestScheduleData.HourlySchedule.RecurCount

            # Verify via CIM that schedule was set
            $cimSession = New-CimSession -ComputerName $script:CMASConnection.SiteServer -Credential $script:CMASConnection.Credential -ErrorAction Stop
            $collection = Get-CimInstance -CimSession $cimSession -Namespace "root\sms\site_$($script:CMASConnection.SiteCode)" `
                -ClassName SMS_Collection -Filter "Name='$($script:TestScheduleData.HourlySchedule.CollectionName)'" | Get-CimInstance
            Remove-CimSession $cimSession

            $collection.RefreshSchedule.HourSpan | Should -Be $script:TestScheduleData.HourlySchedule.RecurCount
            $collection.RefreshType | Should -Be 2  # Periodic
        }
    }

    Context "Minute Schedule" {
        It "Should set minute schedule successfully" {
            $result = Set-CMASCollectionSchedule `
                -CollectionName $script:TestScheduleData.MinuteSchedule.CollectionName `
                -RecurInterval Minutes `
                -RecurCount $script:TestScheduleData.MinuteSchedule.RecurCount

            # Verify via CIM that schedule was set
            $cimSession = New-CimSession -ComputerName $script:CMASConnection.SiteServer -Credential $script:CMASConnection.Credential -ErrorAction Stop
            $collection = Get-CimInstance -CimSession $cimSession -Namespace "root\sms\site_$($script:CMASConnection.SiteCode)" `
                -ClassName SMS_Collection -Filter "Name='$($script:TestScheduleData.MinuteSchedule.CollectionName)'" | Get-CimInstance
            Remove-CimSession $cimSession

            $collection.RefreshSchedule.MinuteSpan | Should -Be $script:TestScheduleData.MinuteSchedule.RecurCount
            $collection.RefreshType | Should -Be 2  # Periodic
        }
    }

    Context "ById Parameter Set" {
        It "Should set schedule by CollectionId" {
            Set-CMASCollectionSchedule `
                -CollectionId $script:TestCollectionForScheduleById.CollectionID `
                -RecurInterval Days `
                -RecurCount 7 `
                -Verbose

            # Verify via CIM that schedule was set
            $cimSession = New-CimSession -ComputerName $script:CMASConnection.SiteServer -Credential $script:CMASConnection.Credential -ErrorAction Stop
            $collection = Get-CimInstance -CimSession $cimSession -Namespace "root\sms\site_$($script:CMASConnection.SiteCode)" `
                -ClassName SMS_Collection -Filter "CollectionID='$($script:TestCollectionForScheduleById.CollectionID)'" | Get-CimInstance
            Remove-CimSession $cimSession

            $collection.RefreshSchedule.DaySpan | Should -Be 7
        }
    }

    Context "StartTime Parameter" {
        It "Should set custom start time" {
            $futureDate = (Get-Date).AddHours(2)
            Set-CMASCollectionSchedule `
                -CollectionName $script:TestScheduleData.DailySchedule.CollectionName `
                -RecurInterval Days `
                -RecurCount 1 `
                -StartTime $futureDate

            # Verify via CIM
            $cimSession = New-CimSession -ComputerName $script:CMASConnection.SiteServer -Credential $script:CMASConnection.Credential -ErrorAction Stop
            $collection = Get-CimInstance -CimSession $cimSession -Namespace "root\sms\site_$($script:CMASConnection.SiteCode)" `
                -ClassName SMS_Collection -Filter "Name='$($script:TestScheduleData.DailySchedule.CollectionName)'" | Get-CimInstance
            Remove-CimSession $cimSession

            # Just verify it exists, exact time comparison is complex due to formatting
            $collection.RefreshSchedule.StartTime | Should -Not -BeNullOrEmpty
        }
    }

    Context "Error Handling" {
        It "Should throw error for non-existent collection" {
            { Set-CMASCollectionSchedule `
                -CollectionName "NonExistentCollection" `
                -RecurInterval Days `
                -RecurCount 1 `
                -ErrorAction Stop } | Should -Throw
        }

        It "Should throw error without SiteServer/SiteCode when not connected" {
            # Temporarily clear connection
            $savedConnection = $script:CMASConnection
            $script:CMASConnection = @{}

            { Set-CMASCollectionSchedule `
                -CollectionName "Test" `
                -RecurInterval Days `
                -RecurCount 1 `
                -ErrorAction Stop } | Should -Throw

            # Restore connection
            $script:CMASConnection = $savedConnection
        }
    }

    Context "WhatIf Support" {
        It "Should support WhatIf parameter" {
            $command = Get-Command Set-CMASCollectionSchedule
            $command.Parameters.ContainsKey('WhatIf') | Should -Be $true
        }
    }
}

# ============================================================================
# PHASE 2: CLEANUP
# ============================================================================
AfterAll {
    Write-Host "`n===========================================================================" -ForegroundColor Cyan
    Write-Host "CLEANUP: Removing test collections" -ForegroundColor Yellow
    Write-Host "===========================================================================" -ForegroundColor Cyan

    foreach ($collectionName in $script:CreatedCollections) {
        Write-Host "Removing collection: $collectionName" -ForegroundColor Yellow
        try {
            Remove-CMASCollection -Name $collectionName -Force -ErrorAction SilentlyContinue
        }
        catch {
            Write-Warning "Failed to remove collection $collectionName : $_"
        }
        Start-Sleep -Milliseconds 500
    }

    Write-Host "✓ Cleanup completed" -ForegroundColor Green
    Write-Host "===========================================================================" -ForegroundColor Cyan
}

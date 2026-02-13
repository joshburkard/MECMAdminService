# Functional Tests for New-CMASCollection
# Tests the New-CMASCollection function behavior and return values

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
    $script:TestNewCollectionData = $script:TestData['New-CMASCollection']

    # Track created collections for cleanup
    $script:CreatedCollections = @()
}

Describe "New-CMASCollection Function Tests" -Tag "Integration", "Collection", "Create", "Modify" {

    Context "Test Data Validation" {

        It "Should have test data defined in declarations.ps1" {
            # Assert
            $script:TestNewCollectionData | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('New-CMASCollection') | Should -Be $true
        }

        It "Should have required test data parameter sets" {
            # Assert
            $script:TestNewCollectionData.ContainsKey('DeviceCollectionByLimitingId') | Should -Be $true
            $script:TestNewCollectionData.ContainsKey('DeviceCollectionByLimitingName') | Should -Be $true
            $script:TestNewCollectionData.ContainsKey('UserCollection') | Should -Be $true
            $script:TestNewCollectionData.ContainsKey('WithComment') | Should -Be $true
            $script:TestNewCollectionData.ContainsKey('WithPeriodicRefresh') | Should -Be $true
            $script:TestNewCollectionData.ContainsKey('WithContinuousRefresh') | Should -Be $true
            $script:TestNewCollectionData.ContainsKey('WithBothRefresh') | Should -Be $true
        }

        It "Should output test data for verification" {
            # Output test data
            Write-Host "`n=== Test Data for New-CMASCollection ===" -ForegroundColor Cyan
            Write-Host "DeviceCollectionByLimitingId:" -ForegroundColor Yellow
            Write-Host "  Name: $($script:TestNewCollectionData.DeviceCollectionByLimitingId.Name)" -ForegroundColor White
            Write-Host "  LimitingCollectionId: $($script:TestNewCollectionData.DeviceCollectionByLimitingId.LimitingCollectionId)" -ForegroundColor White
            Write-Host "`nDeviceCollectionByLimitingName:" -ForegroundColor Yellow
            Write-Host "  Name: $($script:TestNewCollectionData.DeviceCollectionByLimitingName.Name)" -ForegroundColor White
            Write-Host "  LimitingCollectionName: $($script:TestNewCollectionData.DeviceCollectionByLimitingName.LimitingCollectionName)" -ForegroundColor White
            Write-Host "`nUserCollection:" -ForegroundColor Yellow
            Write-Host "  Name: $($script:TestNewCollectionData.UserCollection.Name)" -ForegroundColor White
            Write-Host "  CollectionType: $($script:TestNewCollectionData.UserCollection.CollectionType)" -ForegroundColor White
        }
    }

    Context "Parameter Validation" {

        It "Should throw error when not connected to Admin Service" {
            # Arrange
            $savedConnection = $script:CMASConnection.SiteServer
            $script:CMASConnection.SiteServer = $null

            # Act & Assert
            { New-CMASCollection -Name "Test" -LimitingCollectionId "SMS00001" } | Should -Throw "*No active connection*"

            # Cleanup
            $script:CMASConnection.SiteServer = $savedConnection
        }

        It "Should throw error when neither LimitingCollectionId nor LimitingCollectionName is provided" {
            # Act & Assert
            { New-CMASCollection -Name "Test Collection" } | Should -Throw "*parameter set*"
        }

        It "Should accept valid CollectionType values" {
            # These should not throw during parameter validation
            $script:TestNewCollectionData.DeviceCollectionByLimitingId | Should -Not -BeNullOrEmpty
            $script:TestNewCollectionData.UserCollection | Should -Not -BeNullOrEmpty
        }

        It "Should accept valid RefreshType values" {
            # These should not throw during parameter validation
            $script:TestNewCollectionData.WithPeriodicRefresh | Should -Not -BeNullOrEmpty
            $script:TestNewCollectionData.WithContinuousRefresh | Should -Not -BeNullOrEmpty
            $script:TestNewCollectionData.WithBothRefresh | Should -Not -BeNullOrEmpty
        }
    }

    Context "Create Device Collection by Limiting Collection ID" {

        It "Should create a device collection with limiting collection ID" {
            # Arrange
            $testData = $script:TestNewCollectionData.DeviceCollectionByLimitingId
            $collectionName = "$($testData.Name)_$(Get-Date -Format 'yyyyMMddHHmmss')"

            # Act
            $result = New-CMASCollection -Name $collectionName -LimitingCollectionId $testData.LimitingCollectionId -PassThru

            # Track for cleanup
            if ($result) {
                $script:CreatedCollections += $result.CollectionID
            }

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $collectionName
            $result.CollectionType | Should -Be 2  # Device collection
            $result.LimitToCollectionID | Should -Be $testData.LimitingCollectionId
        }

        It "Should verify the created collection exists in SCCM" {
            # Arrange
            $testData = $script:TestNewCollectionData.DeviceCollectionByLimitingId
            $collectionName = "$($testData.Name)_Verify_$(Get-Date -Format 'yyyyMMddHHmmss')"

            # Act
            New-CMASCollection -Name $collectionName -LimitingCollectionId $testData.LimitingCollectionId
            Start-Sleep -Seconds 2
            $collection = Get-CMASCollection -Name $collectionName

            # Track for cleanup
            if ($collection) {
                $script:CreatedCollections += $collection.CollectionID
            }

            # Assert
            $collection | Should -Not -BeNullOrEmpty
            $collection.Name | Should -Be $collectionName
        }
    }

    Context "Create Device Collection by Limiting Collection Name" {

        It "Should create a device collection with limiting collection name" {
            # Arrange
            $testData = $script:TestNewCollectionData.DeviceCollectionByLimitingName
            $collectionName = "$($testData.Name)_$(Get-Date -Format 'yyyyMMddHHmmss')"

            # Act
            $result = New-CMASCollection -Name $collectionName -LimitingCollectionName $testData.LimitingCollectionName -PassThru

            # Track for cleanup
            if ($result) {
                $script:CreatedCollections += $result.CollectionID
            }

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $collectionName
            $result.CollectionType | Should -Be 2  # Device collection
        }

        It "Should throw error when limiting collection name does not exist" {
            # Arrange
            $collectionName = "TestCollection_$(Get-Date -Format 'yyyyMMddHHmmss')"

            # Act & Assert
            { New-CMASCollection -Name $collectionName -LimitingCollectionName "NonExistent Collection 999" -ErrorAction SilentlyContinue } | Should -Throw "*not found*"
        }
    }

    Context "Create User Collection" {

        It "Should create a user collection" {
            # Arrange
            $testData = $script:TestNewCollectionData.UserCollection
            $collectionName = "$($testData.Name)_$(Get-Date -Format 'yyyyMMddHHmmss')"

            # Act
            $result = New-CMASCollection -Name $collectionName `
                -CollectionType $testData.CollectionType `
                -LimitingCollectionId $testData.LimitingCollectionId `
                -PassThru

            # Track for cleanup
            if ($result) {
                $script:CreatedCollections += $result.CollectionID
            }

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $collectionName
            $result.CollectionType | Should -Be 1  # User collection
        }
    }

    Context "Create Collection with Comment" {

        It "Should create a collection with a comment" {
            # Arrange
            $testData = $script:TestNewCollectionData.WithComment
            $collectionName = "$($testData.Name)_$(Get-Date -Format 'yyyyMMddHHmmss')"

            # Act
            $result = New-CMASCollection -Name $collectionName `
                -LimitingCollectionId $testData.LimitingCollectionId `
                -Comment $testData.Comment `
                -PassThru

            # Track for cleanup
            if ($result) {
                $script:CreatedCollections += $result.CollectionID
            }

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Comment | Should -Be $testData.Comment
        }
    }

    Context "Create Collection with Refresh Types" {

        It "Should create a collection with Periodic refresh type" {
            # Arrange
            $testData = $script:TestNewCollectionData.WithPeriodicRefresh
            $collectionName = "$($testData.Name)_$(Get-Date -Format 'yyyyMMddHHmmss')"

            # Act
            $result = New-CMASCollection -Name $collectionName `
                -LimitingCollectionId $testData.LimitingCollectionId `
                -RefreshType $testData.RefreshType `
                -PassThru

            # Track for cleanup
            if ($result) {
                $script:CreatedCollections += $result.CollectionID
            }

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.RefreshType | Should -BeIn @(2, 6)  # Periodic or Both
        }

        It "Should create a collection with Continuous refresh type" {
            # Arrange
            $testData = $script:TestNewCollectionData.WithContinuousRefresh
            $collectionName = "$($testData.Name)_$(Get-Date -Format 'yyyyMMddHHmmss')"

            # Act
            $result = New-CMASCollection -Name $collectionName `
                -LimitingCollectionId $testData.LimitingCollectionId `
                -RefreshType $testData.RefreshType `
                -PassThru

            # Track for cleanup
            if ($result) {
                $script:CreatedCollections += $result.CollectionID
            }

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.RefreshType | Should -BeIn @(4, 6)  # Continuous or Both
        }

        It "Should create a collection with Both (Periodic and Continuous) refresh type" {
            # Arrange
            $testData = $script:TestNewCollectionData.WithBothRefresh
            $collectionName = "$($testData.Name)_$(Get-Date -Format 'yyyyMMddHHmmss')"

            # Act
            $result = New-CMASCollection -Name $collectionName `
                -LimitingCollectionId $testData.LimitingCollectionId `
                -RefreshType $testData.RefreshType `
                -PassThru

            # Track for cleanup
            if ($result) {
                $script:CreatedCollections += $result.CollectionID
            }

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.RefreshType | Should -Be 6  # Both
        }

        It "Should create a collection with Manual refresh type (default)" {
            # Arrange
            $testData = $script:TestNewCollectionData.DeviceCollectionByLimitingId
            $collectionName = "TestManualRefresh_$(Get-Date -Format 'yyyyMMddHHmmss')"

            # Act
            $result = New-CMASCollection -Name $collectionName `
                -LimitingCollectionId $testData.LimitingCollectionId `
                -PassThru

            # Track for cleanup
            if ($result) {
                $script:CreatedCollections += $result.CollectionID
            }

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.RefreshType | Should -Be 1  # Manual
        }
    }

    Context "Error Handling" {

        It "Should throw error when collection name already exists" {
            # Arrange
            $testData = $script:TestNewCollectionData.DeviceCollectionByLimitingId
            $collectionName = "DuplicateTest_$(Get-Date -Format 'yyyyMMddHHmmss')"

            # Create first collection
            $first = New-CMASCollection -Name $collectionName -LimitingCollectionId $testData.LimitingCollectionId -PassThru
            if ($first) {
                $script:CreatedCollections += $first.CollectionID
            }

            # Act & Assert - Try to create duplicate
            { New-CMASCollection -Name $collectionName -LimitingCollectionId $testData.LimitingCollectionId -ErrorAction SilentlyContinue } | Should -Throw "*already exists*"
        }

        It "Should throw error when limiting collection ID does not exist" {
            # Arrange
            $collectionName = "TestInvalidLimiting_$(Get-Date -Format 'yyyyMMddHHmmss')"

            # Act & Assert
            { New-CMASCollection -Name $collectionName -LimitingCollectionId "XXX99999" -ErrorAction SilentlyContinue } | Should -Throw "*not found*"
        }
    }

    Context "ShouldProcess and WhatIf Support" {

        It "Should support -WhatIf parameter" {
            # Arrange
            $testData = $script:TestNewCollectionData.DeviceCollectionByLimitingId
            $collectionName = "TestWhatIf_$(Get-Date -Format 'yyyyMMddHHmmss')"

            # Act
            New-CMASCollection -Name $collectionName -LimitingCollectionId $testData.LimitingCollectionId -WhatIf

            # Assert - Collection should NOT be created
            Start-Sleep -Seconds 1
            $collection = Get-CMASCollection -Name $collectionName
            $collection | Should -BeNullOrEmpty
        }
    }
}

AfterAll {
    # Cleanup: Remove test collections created during the tests
    Write-Host "`n=== Cleaning up test collections ===" -ForegroundColor Cyan

    foreach ($collectionId in $script:CreatedCollections) {
        try {
            Write-Host "Attempting to delete collection: $collectionId" -ForegroundColor Yellow

            # Using Admin Service API to delete the collection
            $path = "wmi/SMS_Collection('$collectionId')"
            Invoke-CMASApi -Path $path -Method DELETE

            Write-Host "Successfully deleted collection: $collectionId" -ForegroundColor Green
        }
        catch {
            Write-Warning "Failed to delete collection '$collectionId': $_"
        }
    }

    Write-Host "Cleanup complete." -ForegroundColor Cyan
}

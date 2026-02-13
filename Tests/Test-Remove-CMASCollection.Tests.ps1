# Functional Tests for Remove-CMASCollection
# Tests the Remove-CMASCollection function behavior and return values

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
    $script:TestRemoveCollectionData = $script:TestData['Remove-CMASCollection']

    # Create test collections for removal
    $script:CreatedTestCollections = @()

    # Helper function to create a test collection for removal
    function New-TestCollection {
        param(
            [string]$Suffix
        )
        $collectionName = "Test-Remove-Collection-$Suffix-$(Get-Random -Minimum 1000 -Maximum 9999)"
        try {
            $newCollection = New-CMASCollection -Name $collectionName -LimitingCollectionId "SMS00001" -PassThru
            if ($newCollection) {
                $script:CreatedTestCollections += $newCollection
                return $newCollection
            }
        }
        catch {
            Write-Warning "Failed to create test collection: $_"
        }
        return $null
    }
}

Describe "Remove-CMASCollection Function Tests" -Tag "Integration", "Collection", "Delete", "Modify" {

    Context "Test Data Validation" {

        It "Should have test data defined in declarations.ps1" {
            # Assert
            $script:TestRemoveCollectionData | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('Remove-CMASCollection') | Should -Be $true
        }

        It "Should have required test data parameter sets" {
            # Assert
            $script:TestRemoveCollectionData.ContainsKey('ByName') | Should -Be $true
            $script:TestRemoveCollectionData.ContainsKey('ById') | Should -Be $true
            $script:TestRemoveCollectionData.ContainsKey('WithMembers') | Should -Be $true
        }

        It "Should output test data for verification" {
            # Output test data
            Write-Host "`n=== Test Data for Remove-CMASCollection ===" -ForegroundColor Cyan
            Write-Host "ByName:" -ForegroundColor Yellow
            Write-Host "  (Dynamic test collections will be created)" -ForegroundColor White
            Write-Host "`nProtected Collections (Cannot Delete):" -ForegroundColor Yellow
            Write-Host "  SMS00001, SMS00002, SMS00003, SMS00004" -ForegroundColor White
        }
    }

    Context "Parameter Validation" {

        It "Should throw error when not connected to Admin Service" {
            # Arrange
            $savedConnection = $script:CMASConnection.SiteServer
            $script:CMASConnection.SiteServer = $null

            # Act & Assert
            { Remove-CMASCollection -CollectionName "Test" -Force } | Should -Throw "*No active connection*"

            # Cleanup
            $script:CMASConnection.SiteServer = $savedConnection
        }

        It "Should throw error when collection name is empty" {
            # Act & Assert
            { Remove-CMASCollection -CollectionName "" -Force } | Should -Throw
        }

        It "Should throw error when collection ID is empty" {
            # Act & Assert
            { Remove-CMASCollection -CollectionId "" -Force } | Should -Throw
        }
    }

    Context "Remove Collection by Name" {

        BeforeEach {
            $script:TestCollection = New-TestCollection -Suffix "ByName"
        }

        It "Should remove a collection by name" -Skip:($null -eq $script:TestCollection) {
            # Arrange
            $collectionName = $script:TestCollection.Name

            # Act
            Remove-CMASCollection -CollectionName $collectionName -Force

            # Assert - verify collection no longer exists
            Start-Sleep -Seconds 2
            $removedCollection = Get-CMASCollection -Name $collectionName
            $removedCollection | Should -BeNullOrEmpty
        }

        It "Should remove a collection by name with PassThru returning true" -Skip:($null -eq $script:TestCollection) {
            # Arrange
            $collectionName = $script:TestCollection.Name

            # Act
            $result = Remove-CMASCollection -CollectionName $collectionName -Force -PassThru

            # Assert
            $result | Should -Be $true
        }

        It "Should handle non-existent collection gracefully" {
            # Arrange
            $nonExistentName = "NonExistent-Collection-$(Get-Random)"

            # Act & Assert
            { Remove-CMASCollection -CollectionName $nonExistentName -Force -ErrorAction Stop } | Should -Throw "*not found*"
        }
    }

    Context "Remove Collection by ID" {

        BeforeEach {
            $script:TestCollection = New-TestCollection -Suffix "ById"
        }

        It "Should remove a collection by ID" -Skip:($null -eq $script:TestCollection) {
            # Arrange
            $collectionId = $script:TestCollection.CollectionID

            # Act
            Remove-CMASCollection -CollectionId $collectionId -Force

            # Assert - verify collection no longer exists
            Start-Sleep -Seconds 2
            $removedCollection = Get-CMASCollection -CollectionId $collectionId
            $removedCollection | Should -BeNullOrEmpty
        }

        It "Should remove a collection by ID with PassThru returning true" -Skip:($null -eq $script:TestCollection) {
            # Arrange
            $collectionId = $script:TestCollection.CollectionID

            # Act
            $result = Remove-CMASCollection -CollectionId $collectionId -Force -PassThru

            # Assert
            $result | Should -Be $true
        }

        It "Should handle non-existent collection ID gracefully" {
            # Arrange
            $nonExistentId = "XXX99999"

            # Act & Assert
            { Remove-CMASCollection -CollectionId $nonExistentId -Force -ErrorAction Stop } | Should -Throw "*not found*"
        }
    }

    Context "Remove Collection via Pipeline" {

        BeforeEach {
            $script:TestCollection = New-TestCollection -Suffix "Pipeline"
        }

        It "Should remove a collection via pipeline input" -Skip:($null -eq $script:TestCollection) {
            # Arrange
            $collectionName = $script:TestCollection.Name

            # Act
            $script:TestCollection | Remove-CMASCollection -Force

            # Assert - verify collection no longer exists
            Start-Sleep -Seconds 2
            $removedCollection = Get-CMASCollection -Name $collectionName
            $removedCollection | Should -BeNullOrEmpty
        }

        It "Should remove multiple collections via pipeline" {
            # Arrange - create multiple test collections
            $collection1 = New-TestCollection -Suffix "Multi1"
            $collection2 = New-TestCollection -Suffix "Multi2"

            if ($collection1 -and $collection2) {
                # Act
                @($collection1, $collection2) | Remove-CMASCollection -Force

                # Assert
                Start-Sleep -Seconds 2
                $check1 = Get-CMASCollection -Name $collection1.Name
                $check2 = Get-CMASCollection -Name $collection2.Name
                $check1 | Should -BeNullOrEmpty
                $check2 | Should -BeNullOrEmpty
            }
        }
    }

    Context "Protected Collections" {

        It "Should not allow removal of SMS00001 (All Systems)" {
            # Act & Assert
            { Remove-CMASCollection -CollectionId "SMS00001" -Force -ErrorAction Stop } | Should -Throw "*protected*"
        }

        It "Should not allow removal of SMS00002 (All Users)" {
            # Act & Assert
            { Remove-CMASCollection -CollectionId "SMS00002" -Force -ErrorAction Stop } | Should -Throw "*protected*"
        }
    }

    Context "WhatIf Support" {

        BeforeEach {
            $script:TestCollection = New-TestCollection -Suffix "WhatIf"
        }

        It "Should support WhatIf parameter" -Skip:($null -eq $script:TestCollection) {
            # Arrange
            $collectionName = $script:TestCollection.Name

            # Act
            Remove-CMASCollection -CollectionName $collectionName -WhatIf

            # Assert - collection should still exist
            $stillExists = Get-CMASCollection -Name $collectionName
            $stillExists | Should -Not -BeNullOrEmpty

            # Cleanup
            Remove-CMASCollection -CollectionName $collectionName -Force
        }
    }

    Context "Confirmation Behavior" {

        BeforeEach {
            $script:TestCollection = New-TestCollection -Suffix "Confirm"
        }

        It "Should proceed with removal when Force is specified" -Skip:($null -eq $script:TestCollection) {
            # Arrange
            $collectionName = $script:TestCollection.Name

            # Act
            Remove-CMASCollection -CollectionName $collectionName -Force

            # Assert
            Start-Sleep -Seconds 2
            $removed = Get-CMASCollection -Name $collectionName
            $removed | Should -BeNullOrEmpty
        }
    }

    Context "Error Handling" {

        It "Should return false with PassThru on error" {
            # Arrange
            $nonExistentId = "XXX99999"

            # Act
            $result = Remove-CMASCollection -CollectionId $nonExistentId -Force -PassThru -ErrorAction SilentlyContinue

            # Assert
            $result | Should -Be $false
        }
    }
}

AfterAll {
    # Cleanup any remaining test collections
    Write-Host "`nCleaning up test collections..." -ForegroundColor Cyan
    foreach ($collection in $script:CreatedTestCollections) {
        try {
            $exists = Get-CMASCollection -CollectionId $collection.CollectionID -ErrorAction SilentlyContinue
            if ($exists) {
                Remove-CMASCollection -CollectionId $collection.CollectionID -Force -ErrorAction SilentlyContinue
                Write-Host "  Removed: $($collection.Name)" -ForegroundColor Yellow
            }
        }
        catch {
            Write-Warning "Could not remove test collection $($collection.Name): $_"
        }
    }
}

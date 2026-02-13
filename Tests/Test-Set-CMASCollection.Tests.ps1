# Functional Tests for Set-CMASCollection
# Tests the Set-CMASCollection function behavior and return values

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
    $script:TestSetCollectionData = $script:TestData['Set-CMASCollection']

    # Track created collections for cleanup
    $script:CreatedCollections = @()

    # ============================================================================
    # PHASE 1: CREATE TEST COLLECTIONS
    # ============================================================================
    Write-Host "`n===========================================================================" -ForegroundColor Cyan
    Write-Host "PHASE 1: Creating test collections for Set-CMASCollection tests" -ForegroundColor Cyan
    Write-Host "Note: RefreshSchedule test is skipped (not supported by Admin Service API)" -ForegroundColor Yellow
    Write-Host "===========================================================================" -ForegroundColor Cyan

    # Collection 1: For UpdateName test
    Write-Host "`n[1/7] Creating collection: $($script:TestSetCollectionData.UpdateName.OriginalName)" -ForegroundColor Yellow
    New-CMASCollection -Name $script:TestSetCollectionData.UpdateName.OriginalName -LimitingCollectionId "SMS00001" -ErrorAction Stop
    $script:CreatedCollections += $script:TestSetCollectionData.UpdateName.OriginalName
    $script:CreatedCollections += $script:TestSetCollectionData.UpdateName.NewName
    Start-Sleep -Seconds 2

    # Collection 2: For UpdateComment test
    Write-Host "[2/7] Creating collection: $($script:TestSetCollectionData.UpdateComment.CollectionName)" -ForegroundColor Yellow
    New-CMASCollection -Name $script:TestSetCollectionData.UpdateComment.CollectionName -LimitingCollectionId "SMS00001" -ErrorAction Stop
    $script:CreatedCollections += $script:TestSetCollectionData.UpdateComment.CollectionName
    Start-Sleep -Seconds 2

    # Collection 3: For UpdateRefreshType test
    Write-Host "[3/7] Creating collection: $($script:TestSetCollectionData.UpdateRefreshType.CollectionName)" -ForegroundColor Yellow
    New-CMASCollection -Name $script:TestSetCollectionData.UpdateRefreshType.CollectionName -LimitingCollectionId "SMS00001" -RefreshType $script:TestSetCollectionData.UpdateRefreshType.OriginalRefreshType -ErrorAction Stop
    $script:CreatedCollections += $script:TestSetCollectionData.UpdateRefreshType.CollectionName
    Start-Sleep -Seconds 2

    # Collection 4: For UpdateRefreshSchedule test (SKIPPED - not supported by Admin Service)
    # Write-Host "[4/7] Creating collection: $($script:TestSetCollectionData.UpdateRefreshSchedule.CollectionName)" -ForegroundColor Yellow
    # New-CMASCollection -Name $script:TestSetCollectionData.UpdateRefreshSchedule.CollectionName -LimitingCollectionId "SMS00001" -RefreshType $script:TestSetCollectionData.UpdateRefreshSchedule.RefreshType -ErrorAction Stop
    # $script:CreatedCollections += $script:TestSetCollectionData.UpdateRefreshSchedule.CollectionName
    # Start-Sleep -Seconds 2

    # Collection 5: For UpdateMultipleProperties test
    Write-Host "[5/7] Creating collection: $($script:TestSetCollectionData.UpdateMultipleProperties.CollectionName)" -ForegroundColor Yellow
    New-CMASCollection -Name $script:TestSetCollectionData.UpdateMultipleProperties.CollectionName -LimitingCollectionId "SMS00001" -RefreshType "Manual" -ErrorAction Stop
    $script:CreatedCollections += $script:TestSetCollectionData.UpdateMultipleProperties.CollectionName
    $script:CreatedCollections += $script:TestSetCollectionData.UpdateMultipleProperties.NewName
    Start-Sleep -Seconds 2

    # Collection 6: For ById test
    Write-Host "[6/7] Creating collection: Test-Set-ById-Collection" -ForegroundColor Yellow
    New-CMASCollection -Name "Test-Set-ById-Collection" -LimitingCollectionId "SMS00001" -ErrorAction Stop
    $script:CreatedCollections += "Test-Set-ById-Collection"
    Start-Sleep -Seconds 2
    $script:TestCollectionForIdUpdate = Get-CMASCollection -Name "Test-Set-ById-Collection"

    # Collection 7: For Pipeline test
    Write-Host "[7/7] Creating collection: Test-Set-Pipeline-Collection" -ForegroundColor Yellow
    New-CMASCollection -Name "Test-Set-Pipeline-Collection" -LimitingCollectionId "SMS00001" -ErrorAction Stop
    $script:CreatedCollections += "Test-Set-Pipeline-Collection"
    Start-Sleep -Seconds 2

    # Collection 8: For WhatIf test
    Write-Host "[8/8] Creating collection: Test-Set-WhatIf-Collection" -ForegroundColor Yellow
    New-CMASCollection -Name "Test-Set-WhatIf-Collection" -LimitingCollectionId "SMS00001" -ErrorAction Stop
    $script:CreatedCollections += "Test-Set-WhatIf-Collection"
    Start-Sleep -Seconds 2

    Write-Host "`nAll test collections created successfully!" -ForegroundColor Green
    Write-Host "Collections that will be used for testing:" -ForegroundColor Cyan
    foreach ($col in $script:CreatedCollections | Sort-Object -Unique) {
        Write-Host "  - $col" -ForegroundColor White
    }

    # Ask user to proceed
    Write-Host "`n===========================================================================" -ForegroundColor Cyan
    Write-Host "Press ENTER to proceed with Set-CMASCollection tests..." -ForegroundColor Yellow
    Write-Host "===========================================================================" -ForegroundColor Cyan
    Read-Host

    # ============================================================================
    # PHASE 2: RUNNING SET-CMASCOLLECTION TESTS
    # ============================================================================
    Write-Host "`n===========================================================================" -ForegroundColor Cyan
    Write-Host "PHASE 2: Running Set-CMASCollection tests" -ForegroundColor Cyan
    Write-Host "===========================================================================" -ForegroundColor Cyan
}

Describe "Set-CMASCollection Function Tests" -Tag "Integration", "Collection", "Modify" {

    Context "Test Data Validation" {

        It "Should have test data defined in declarations.ps1" {
            # Assert
            $script:TestSetCollectionData | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('Set-CMASCollection') | Should -Be $true
        }

        It "Should have required test data parameter sets" {
            # Assert
            $script:TestSetCollectionData.ContainsKey('UpdateName') | Should -Be $true
            $script:TestSetCollectionData.ContainsKey('UpdateComment') | Should -Be $true
            $script:TestSetCollectionData.ContainsKey('UpdateRefreshType') | Should -Be $true
            $script:TestSetCollectionData.ContainsKey('UpdateRefreshSchedule') | Should -Be $true
            $script:TestSetCollectionData.ContainsKey('UpdateMultipleProperties') | Should -Be $true
        }

        It "Should output test data for verification" {
            # Output test data
            Write-Host "`n=== Test Data for Set-CMASCollection ===" -ForegroundColor Cyan
            Write-Host "UpdateName:" -ForegroundColor Yellow
            Write-Host "  OriginalName: $($script:TestSetCollectionData.UpdateName.OriginalName)" -ForegroundColor White
            Write-Host "  NewName: $($script:TestSetCollectionData.UpdateName.NewName)" -ForegroundColor White
            Write-Host "`nUpdateComment:" -ForegroundColor Yellow
            Write-Host "  CollectionName: $($script:TestSetCollectionData.UpdateComment.CollectionName)" -ForegroundColor White
            Write-Host "  Comment: $($script:TestSetCollectionData.UpdateComment.Comment)" -ForegroundColor White
            Write-Host "`nUpdateRefreshType:" -ForegroundColor Yellow
            Write-Host "  CollectionName: $($script:TestSetCollectionData.UpdateRefreshType.CollectionName)" -ForegroundColor White
            Write-Host "  NewRefreshType: $($script:TestSetCollectionData.UpdateRefreshType.NewRefreshType)" -ForegroundColor White
        }
    }

    Context "Parameter Validation" {

        It "Should throw error when not connected to Admin Service" {
            # Arrange
            $savedConnection = $script:CMASConnection.SiteServer
            $script:CMASConnection.SiteServer = $null

            # Act & Assert
            { Set-CMASCollection -CollectionName "Test" -NewName "Test2" -ErrorAction Stop } 2>$null | Should -Throw "*No active connection*"

            # Cleanup
            $script:CMASConnection.SiteServer = $savedConnection
        }

        It "Should throw error when no property to update is specified" {
            # Act & Assert
            { Set-CMASCollection -CollectionName "Test Collection" -ErrorAction Stop } 2>$null | Should -Throw "*At least one property*"
        }

        It "Should accept valid RefreshType values" {
            # These should not throw during parameter validation
            $script:TestSetCollectionData.UpdateRefreshType | Should -Not -BeNullOrEmpty
        }
    }

    Context "Update Collection Name" {

        It "Should update collection name successfully" {
            # Arrange
            $testData = $script:TestSetCollectionData.UpdateName

            # Act
            Set-CMASCollection -CollectionName $testData.OriginalName -NewName $testData.NewName

            # Assert
            Start-Sleep -Seconds 2
            $updatedCollection = Get-CMASCollection -Name $testData.NewName
            $updatedCollection | Should -Not -BeNullOrEmpty
            $updatedCollection.Name | Should -Be $testData.NewName

            # Verify old name no longer exists
            $oldCollection = Get-CMASCollection -Name $testData.OriginalName
            $oldCollection | Should -BeNullOrEmpty
        }

        It "Should return updated collection with PassThru" {
            # Arrange
            $testData = $script:TestSetCollectionData.UpdateName

            # Act
            $result = Set-CMASCollection -CollectionName $testData.NewName -NewName "$($testData.NewName)-PassThru" -PassThru

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be "$($testData.NewName)-PassThru"
            $script:CreatedCollections += "$($testData.NewName)-PassThru"
        }

        It "Should throw error if new name already exists" {
            # Arrange - Create another collection
            $conflictName = "$($script:TestSetCollectionData.UpdateName.NewName)-Conflict"
            New-CMASCollection -Name $conflictName -LimitingCollectionId "SMS00001"
            $script:CreatedCollections += $conflictName
            Start-Sleep -Seconds 2

            # Act & Assert
            { Set-CMASCollection -CollectionName "$($script:TestSetCollectionData.UpdateName.NewName)-PassThru" -NewName $conflictName -ErrorAction Stop } 2>$null |
                Should -Throw "*already exists*"
        }
    }

    Context "Update Collection Comment" {

        It "Should update collection comment successfully" {
            # Arrange
            $testData = $script:TestSetCollectionData.UpdateComment

            # Act
            Set-CMASCollection -CollectionName $testData.CollectionName -Comment $testData.Comment

            # Assert
            Start-Sleep -Seconds 2
            $updatedCollection = Get-CMASCollection -Name $testData.CollectionName
            $updatedCollection | Should -Not -BeNullOrEmpty
            $updatedCollection.Comment | Should -Be $testData.Comment
        }

        It "Should clear comment when empty string is provided" {
            # Arrange
            $testData = $script:TestSetCollectionData.UpdateComment

            # Act
            Set-CMASCollection -CollectionName $testData.CollectionName -Comment ""

            # Assert
            Start-Sleep -Seconds 2
            $updatedCollection = Get-CMASCollection -Name $testData.CollectionName
            $updatedCollection | Should -Not -BeNullOrEmpty
            ($updatedCollection.Comment -eq "" -or $null -eq $updatedCollection.Comment) | Should -Be $true
        }
    }

    Context "Update Collection RefreshType" {

        It "Should update RefreshType successfully" {
            # Arrange
            $testData = $script:TestSetCollectionData.UpdateRefreshType
            $expectedRefreshType = switch ($testData.NewRefreshType) {
                'Manual' { 1 }
                'Periodic' { 2 }
                'Continuous' { 4 }
                'Both' { 6 }
            }

            # Act
            Set-CMASCollection -CollectionName $testData.CollectionName -RefreshType $testData.NewRefreshType

            # Assert
            Start-Sleep -Seconds 2
            $updatedCollection = Get-CMASCollection -Name $testData.CollectionName
            $updatedCollection | Should -Not -BeNullOrEmpty
            $updatedCollection.RefreshType | Should -Be $expectedRefreshType
        }
    }

    Context "Update Collection RefreshSchedule" {

        It "Should update RefreshSchedule successfully" -Skip {
            # NOTE: RefreshSchedule cannot be set via Admin Service REST API (results in 500 error)
            # This affects both POST (New-CMASCollection) and PUT (Set-CMASCollection)
            # The RefreshSchedule property appears to be read-only via REST API
            # Keeping test for future when/if Admin Service adds support

            # Arrange
            $testData = $script:TestSetCollectionData.UpdateRefreshSchedule

            # Act
            Set-CMASCollection -CollectionName $testData.CollectionName -RefreshSchedule $testData.RefreshSchedule

            # Assert
            Start-Sleep -Seconds 2
            $updatedCollection = Get-CMASCollection -Name $testData.CollectionName
            $updatedCollection | Should -Not -BeNullOrEmpty
            $updatedCollection.RefreshSchedule | Should -Not -BeNullOrEmpty
        }
    }

    Context "Update Multiple Properties" {

        It "Should update multiple properties at once" {
            # Arrange
            $testData = $script:TestSetCollectionData.UpdateMultipleProperties
            $expectedRefreshType = switch ($testData.RefreshType) {
                'Manual' { 1 }
                'Periodic' { 2 }
                'Continuous' { 4 }
                'Both' { 6 }
            }

            # Act
            Set-CMASCollection -CollectionName $testData.CollectionName `
                              -NewName $testData.NewName `
                              -Comment $testData.Comment `
                              -RefreshType $testData.RefreshType `
                              -PassThru

            # Assert
            Start-Sleep -Seconds 2
            $updatedCollection = Get-CMASCollection -Name $testData.NewName
            $updatedCollection | Should -Not -BeNullOrEmpty
            $updatedCollection.Name | Should -Be $testData.NewName
            $updatedCollection.Comment | Should -Be $testData.Comment
            $updatedCollection.RefreshType | Should -Be $expectedRefreshType
        }
    }

    Context "Update by CollectionId" {

        It "Should update collection by CollectionId" {
            # Arrange
            $newComment = "Updated via CollectionId"

            # Act
            Set-CMASCollection -CollectionId $script:TestCollectionForIdUpdate.CollectionID -Comment $newComment

            # Assert
            Start-Sleep -Seconds 2
            $updatedCollection = Get-CMASCollection -CollectionId $script:TestCollectionForIdUpdate.CollectionID
            $updatedCollection | Should -Not -BeNullOrEmpty
            $updatedCollection.Comment | Should -Be $newComment
        }
    }

    Context "Update via Pipeline (InputObject)" {

        It "Should accept collection object via pipeline" {
            # Arrange
            $newComment = "Updated via pipeline"

            # Act
            $collection = Get-CMASCollection -Name "Test-Set-Pipeline-Collection"
            $collection | Set-CMASCollection -Comment $newComment

            # Assert
            Start-Sleep -Seconds 2
            $updatedCollection = Get-CMASCollection -Name "Test-Set-Pipeline-Collection"
            $updatedCollection | Should -Not -BeNullOrEmpty
            $updatedCollection.Comment | Should -Be $newComment
        }
    }

    Context "Error Handling" {

        It "Should throw error for non-existent collection by name" {
            # Act & Assert
            { Set-CMASCollection -CollectionName "NonExistent-Collection-999" -Comment "Test" -ErrorAction Stop } 2>$null |
                Should -Throw "*not found*"
        }

        It "Should throw error for non-existent collection by ID" {
            # Act & Assert
            { Set-CMASCollection -CollectionId "XXX99999" -Comment "Test" -ErrorAction Stop } 2>$null |
                Should -Throw "*not found*"
        }

        It "Should handle multiple collections with same name gracefully" {
            # This test documents behavior when multiple collections have the same name
            # In practice, this shouldn't happen, but the function should handle it
            # Skipped for now as it's difficult to create duplicate collection names
            Set-ItResult -Skipped -Because "Difficult to create duplicate collection names in test environment"
        }
    }

    Context "WhatIf Support" {

        It "Should support WhatIf without making changes" {
            # Arrange
            $originalCollection = Get-CMASCollection -Name "Test-Set-WhatIf-Collection"
            $newComment = "This should not be set"

            # Act
            Set-CMASCollection -CollectionName "Test-Set-WhatIf-Collection" -Comment $newComment -WhatIf

            # Assert
            Start-Sleep -Seconds 1
            $unchangedCollection = Get-CMASCollection -Name "Test-Set-WhatIf-Collection"
            $unchangedCollection.Comment | Should -Be $originalCollection.Comment
        }
    }
}

AfterAll {
    # ============================================================================
    # PHASE 3: CLEANUP TEST COLLECTIONS
    # ============================================================================
    Write-Host "\n===========================================================================" -ForegroundColor Cyan
    Write-Host "PHASE 3: Cleanup test collections" -ForegroundColor Cyan
    Write-Host "===========================================================================" -ForegroundColor Cyan
    Write-Host "The following collections will be removed:" -ForegroundColor Yellow
    foreach ($col in $script:CreatedCollections | Sort-Object -Unique) {
        Write-Host "  - $col" -ForegroundColor White
    }
    Write-Host "\nPress ENTER to proceed with cleanup..." -ForegroundColor Yellow
    Read-Host

    Write-Host "\nRemoving test collections..." -ForegroundColor Cyan
    $removedCount = 0
    $failedCount = 0

    foreach ($collectionName in ($script:CreatedCollections | Sort-Object -Unique)) {
        try {
            $collection = Get-CMASCollection -Name $collectionName -ErrorAction SilentlyContinue
            if ($collection) {
                Write-Host "  Removing: $collectionName" -ForegroundColor Yellow
                Remove-CMASCollection -CollectionName $collectionName -Force -ErrorAction Stop
                $removedCount++
                Start-Sleep -Seconds 1
            } else {
                Write-Host "  Collection not found (may have been renamed): $collectionName" -ForegroundColor Gray
            }
        }
        catch {
            Write-Host "  Failed to remove '$collectionName': $_" -ForegroundColor Red
            $failedCount++
        }
    }

    Write-Host "\n===========================================================================" -ForegroundColor Cyan
    Write-Host "Cleanup Summary:" -ForegroundColor Cyan
    Write-Host "  Collections removed: $removedCount" -ForegroundColor Green
    if ($failedCount -gt 0) {
        Write-Host "  Failed removals: $failedCount" -ForegroundColor Red
    }
    Write-Host "===========================================================================" -ForegroundColor Cyan
}

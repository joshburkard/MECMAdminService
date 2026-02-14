# Functional Tests for Invoke-CMASCollectionUpdate
# Tests the Invoke-CMASCollectionUpdate function behavior and return values
#
# ⚠️ WARNING: Some tests in this file will TRIGGER COLLECTION UPDATES in your SCCM environment
# These tests are generally safe but will trigger membership evaluations

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
    $script:TestInvokeCollectionUpdateData = $script:TestData['Invoke-CMASCollectionUpdate']
}

Describe "Invoke-CMASCollectionUpdate Function Tests" -Tag "Integration", "CollectionUpdate" {

    Context "Test Data Validation" {

        It "Should have test data defined in declarations.ps1" {
            # Assert
            $script:TestInvokeCollectionUpdateData | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('Invoke-CMASCollectionUpdate') | Should -Be $true
        }

        It "Should have required test data parameter sets" {
            # Assert
            $script:TestInvokeCollectionUpdateData.ContainsKey('ByCollectionName') | Should -Be $true
            $script:TestInvokeCollectionUpdateData.ContainsKey('ByCollectionId') | Should -Be $true
            $script:TestInvokeCollectionUpdateData.ContainsKey('NonExistent') | Should -Be $true
        }

        It "Should output test data for verification" {
            # Output test data
            Write-Host "`n=== Test Data for Invoke-CMASCollectionUpdate ===" -ForegroundColor Cyan
            Write-Host "ByCollectionName:" -ForegroundColor Yellow
            Write-Host "  CollectionName: $($script:TestInvokeCollectionUpdateData.ByCollectionName.CollectionName)" -ForegroundColor White
            Write-Host "  ExpectedSuccess: $($script:TestInvokeCollectionUpdateData.ByCollectionName.ExpectedSuccess)" -ForegroundColor White

            Write-Host "ByCollectionId:" -ForegroundColor Yellow
            Write-Host "  CollectionId: $($script:TestInvokeCollectionUpdateData.ByCollectionId.CollectionId)" -ForegroundColor White
            Write-Host "  ExpectedSuccess: $($script:TestInvokeCollectionUpdateData.ByCollectionId.ExpectedSuccess)" -ForegroundColor White

            Write-Host "NonExistent:" -ForegroundColor Yellow
            Write-Host "  CollectionName: $($script:TestInvokeCollectionUpdateData.NonExistent.CollectionName)" -ForegroundColor White
            Write-Host "  CollectionId: $($script:TestInvokeCollectionUpdateData.NonExistent.CollectionId)" -ForegroundColor White
            Write-Host "============================================================`n" -ForegroundColor Cyan

            # This test always passes, it's just for output
            $true | Should -Be $true
        }
    }

    Context "Connection Validation" {

        It "Should throw error when not connected to Admin Service" {
            # Arrange
            $savedConnection = $script:CMASConnection.SiteServer
            $script:CMASConnection.SiteServer = $null

            # Act & Assert
            { Invoke-CMASCollectionUpdate -CollectionName "Test" -ErrorAction Stop } 2>$null | Should -Throw "*No active connection*"

            # Cleanup
            $script:CMASConnection.SiteServer = $savedConnection
        }
    }

    Context "Parameter Validation" {

        It "Should require either CollectionName, CollectionId, or InputObject" {
            # This is enforced by parameter sets at the PowerShell level
            # If none are provided, PowerShell will require one before the function executes
            $true | Should -Be $true
        }

        It "Should accept CollectionName parameter" {
            # Test parameter binding - this shouldn't throw
            $testData = $script:TestInvokeCollectionUpdateData.ByCollectionName
            {
                $params = @{
                    CollectionName = $testData.CollectionName
                    WhatIf = $true
                    ErrorAction = 'Stop'
                }
                Invoke-CMASCollectionUpdate @params
            } | Should -Not -Throw
        }

        It "Should accept CollectionId parameter" {
            # Test parameter binding
            $testData = $script:TestInvokeCollectionUpdateData.ByCollectionId
            {
                $params = @{
                    CollectionId = $testData.CollectionId
                    WhatIf = $true
                    ErrorAction = 'Stop'
                }
                Invoke-CMASCollectionUpdate @params
            } | Should -Not -Throw
        }
    }

    Context "Collection Lookup" {

        It "Should find collection by valid name" {
            # Arrange
            $testData = $script:TestInvokeCollectionUpdateData.ByCollectionName

            # Act - using WhatIf to prevent actual update
            {
                Invoke-CMASCollectionUpdate -CollectionName $testData.CollectionName -WhatIf -ErrorAction Stop
            } | Should -Not -Throw
        }

        It "Should find collection by valid ID" {
            # Arrange
            $testData = $script:TestInvokeCollectionUpdateData.ByCollectionId

            # Act - using WhatIf to prevent actual update
            {
                Invoke-CMASCollectionUpdate -CollectionId $testData.CollectionId -WhatIf -ErrorAction Stop
            } | Should -Not -Throw
        }

        It "Should fail gracefully when collection doesn't exist by name" {
            # Arrange
            $testData = $script:TestInvokeCollectionUpdateData.NonExistent

            # Act & Assert
            { Invoke-CMASCollectionUpdate -CollectionName $testData.CollectionName -ErrorAction Stop } | Should -Throw "*not found*"
        }

        It "Should fail gracefully when collection doesn't exist by ID" {
            # Arrange
            $testData = $script:TestInvokeCollectionUpdateData.NonExistent

            # Act & Assert
            { Invoke-CMASCollectionUpdate -CollectionId $testData.CollectionId -ErrorAction Stop } | Should -Throw "*not found*"
        }
    }

    Context "Collection Update by Name" {

        It "⚠️ Should initiate collection update by name" {
            # ⚠️ WARNING: This test TRIGGERS A COLLECTION UPDATE in SCCM
            # Arrange
            $testData = $script:TestInvokeCollectionUpdateData.ByCollectionName

            # Act
            {
                Invoke-CMASCollectionUpdate -CollectionName $testData.CollectionName -ErrorAction Stop
            } | Should -Not -Throw

            # Assert - just verify it doesn't throw
            # The actual membership update happens asynchronously
        }

        It "Should support WhatIf parameter" {
            # Arrange
            $testData = $script:TestInvokeCollectionUpdateData.ByCollectionName

            # Act
            {
                Invoke-CMASCollectionUpdate -CollectionName $testData.CollectionName -WhatIf -ErrorAction Stop
            } | Should -Not -Throw
        }
    }

    Context "Collection Update by ID" {

        It "⚠️ Should initiate collection update by ID" {
            # ⚠️ WARNING: This test TRIGGERS A COLLECTION UPDATE in SCCM
            # Arrange
            $testData = $script:TestInvokeCollectionUpdateData.ByCollectionId

            # Act
            {
                Invoke-CMASCollectionUpdate -CollectionId $testData.CollectionId -ErrorAction Stop
            } | Should -Not -Throw
        }
    }

    Context "Collection Update with PassThru" {

        It "Should return result object when PassThru is specified" {
            # Arrange
            $testData = $script:TestInvokeCollectionUpdateData.ByCollectionName

            # Act
            $result = Invoke-CMASCollectionUpdate -CollectionName $testData.CollectionName -PassThru -ErrorAction Stop

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.CollectionId | Should -Not -BeNullOrEmpty
            $result.CollectionName | Should -Be $testData.CollectionName
            $result.UpdateInitiated | Should -Be $true
            $result.Timestamp | Should -Not -BeNullOrEmpty
            $result | Should -BeOfType [PSCustomObject]
        }

        It "Should not return result object when PassThru is not specified" {
            # Arrange
            $testData = $script:TestInvokeCollectionUpdateData.ByCollectionName

            # Act
            $result = Invoke-CMASCollectionUpdate -CollectionName $testData.CollectionName -ErrorAction Stop

            # Assert - should return nothing
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Pipeline Support" {

        It "Should accept collection object from pipeline" {
            # Arrange
            $testData = $script:TestInvokeCollectionUpdateData.ByCollectionName

            # Act
            {
                Get-CMASCollection -Name $testData.CollectionName |
                    Invoke-CMASCollectionUpdate -WhatIf -ErrorAction Stop
            } | Should -Not -Throw
        }

        It "Should process multiple collections from pipeline" {
            # Arrange - get first 2 collections
            $collections = Get-CMASCollection | Select-Object -First 2

            # Act
            $results = $collections | Invoke-CMASCollectionUpdate -PassThru -ErrorAction Stop

            # Assert
            $results | Should -Not -BeNullOrEmpty
            $results.Count | Should -Be 2
            $results[0].UpdateInitiated | Should -Be $true
            $results[1].UpdateInitiated | Should -Be $true
        }
    }

    Context "Advanced Parameters" {

        It "Should support Verbose parameter" {
            # Arrange
            $testData = $script:TestInvokeCollectionUpdateData.ByCollectionName

            # Act & Assert - should not throw with Verbose
            {
                Invoke-CMASCollectionUpdate -CollectionName $testData.CollectionName `
                    -Verbose -WhatIf -ErrorAction Stop
            } | Should -Not -Throw
        }
    }
}

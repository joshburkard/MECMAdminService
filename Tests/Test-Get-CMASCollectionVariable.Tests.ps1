# Functional Tests for Get-CMASCollectionVariable
# Tests the Get-CMASCollectionVariable function behavior and return values

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
    $script:TestGetCollectionVariableData = $script:TestData['Get-CMASCollectionVariable']
}

Describe "Get-CMASCollectionVariable Function Tests" -Tag "Integration", "CollectionVariable", "Get" {

    Context "Test Data Validation" {

        It "Should have test data defined in declarations.ps1" {
            # Assert
            $script:TestGetCollectionVariableData | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('Get-CMASCollectionVariable') | Should -Be $true
        }

        It "Should have required test data parameter sets" {
            # Assert
            $script:TestGetCollectionVariableData.ContainsKey('ByCollectionName') | Should -Be $true
            $script:TestGetCollectionVariableData.ContainsKey('ByCollectionId') | Should -Be $true
            $script:TestGetCollectionVariableData.ContainsKey('ByCollectionNameAndVariableName') | Should -Be $true
        }

        It "Should output test data for verification" {
            # Output test data
            Write-Host "`n=== Test Data for Get-CMASCollectionVariable ===" -ForegroundColor Cyan
            Write-Host "ByCollectionName:" -ForegroundColor Yellow
            Write-Host "  CollectionName: $($script:TestGetCollectionVariableData.ByCollectionName.CollectionName)" -ForegroundColor White
            Write-Host "`nByCollectionId:" -ForegroundColor Yellow
            Write-Host "  CollectionId: $($script:TestGetCollectionVariableData.ByCollectionId.CollectionId)" -ForegroundColor White
        }
    }

    Context "Parameter Validation" {

        It "Should throw error when not connected to Admin Service" {
            # Arrange
            $savedConnection = $script:CMASConnection.SiteServer
            $script:CMASConnection.SiteServer = $null

            # Act & Assert
            { Get-CMASCollectionVariable -CollectionName "Test" } |
                Should -Throw "*No active connection*"

            # Cleanup
            $script:CMASConnection.SiteServer = $savedConnection
        }

        It "Should throw error when neither CollectionName nor CollectionID is provided" {
            # Act & Assert
            { Get-CMASCollectionVariable } |
                Should -Throw "*CollectionName*CollectionID*"
        }
    }

    Context "Get Collection Variables by Collection Name" {

        It "Should get all variables for a collection by name" {
            # Arrange
            $testData = $script:TestGetCollectionVariableData.ByCollectionName

            # Act
            $result = Get-CMASCollectionVariable -CollectionName $testData.CollectionName

            # Assert
            $result | Should -Not -BeNullOrEmpty
            @($result).Count | Should -BeGreaterOrEqual $testData.ExpectedMinCount
            $result[0].PSObject.Properties.Name | Should -Contain 'Name'
            $result[0].PSObject.Properties.Name | Should -Contain 'Value'
            $result[0].PSObject.Properties.Name | Should -Contain 'IsMasked'
        }

        It "Should get a specific variable by collection name and variable name" {
            # Arrange
            $testData = $script:TestGetCollectionVariableData.ByCollectionNameAndVariableName

            # Act
            $result = Get-CMASCollectionVariable -CollectionName $testData.CollectionName -VariableName $testData.VariableName

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result[0].Name | Should -BeLike $testData.VariableName
        }

        It "Should return empty result for collection without variables" {
            # Arrange
            $testData = $script:TestGetCollectionVariableData.CollectionWithoutVariables

            # Skip if no test collection specified
            if (-not $testData.CollectionName) {
                Set-ItResult -Skipped -Because "No test collection without variables specified in declarations.ps1"
                return
            }

            # Act
            $result = Get-CMASCollectionVariable -CollectionName $testData.CollectionName

            # Assert
            $result | Should -BeNullOrEmpty
        }

        It "Should throw error for non-existent collection" {
            # Arrange
            $testData = $script:TestGetCollectionVariableData.NonExistentCollection

            # Act & Assert
            { Get-CMASCollectionVariable -CollectionName $testData.CollectionName } |
                Should -Throw "*not found*"
        }
    }

    Context "Get Collection Variables by CollectionID" {

        It "Should get all variables for a collection by CollectionID" {
            # Arrange
            $testData = $script:TestGetCollectionVariableData.ByCollectionId

            # Act
            $result = Get-CMASCollectionVariable -CollectionID $testData.CollectionId

            # Assert
            $result | Should -Not -BeNullOrEmpty
            @($result).Count | Should -BeGreaterOrEqual $testData.ExpectedMinCount
        }

        It "Should get a specific variable by CollectionID and variable name" {
            # Arrange
            $testData = $script:TestGetCollectionVariableData.ByCollectionIdAndVariableName

            # Act
            $result = Get-CMASCollectionVariable -CollectionID $testData.CollectionId -VariableName $testData.VariableName

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result[0].Name | Should -BeLike $testData.VariableName
        }
    }

    Context "Variable Filtering" {

        It "Should support wildcard patterns in variable name" {
            # Arrange
            $testData = $script:TestGetCollectionVariableData.ByWildcard

            # Act
            $result = Get-CMASCollectionVariable -CollectionName $testData.CollectionName -VariableName $testData.VariableName

            # Assert
            $result | Should -Not -BeNullOrEmpty
            # All returned variables should match the pattern
            foreach ($var in $result) {
                $var.Name | Should -BeLike $testData.VariableName
            }
        }

        It "Should return empty for non-existent variable name" {
            # Arrange
            $testData = $script:TestGetCollectionVariableData.NonExistentVariable

            # Act
            $result = Get-CMASCollectionVariable -CollectionName $testData.CollectionName -VariableName $testData.VariableName

            # Assert
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Output Properties" {

        It "Should include collection information in output" {
            # Arrange
            $testData = $script:TestGetCollectionVariableData.ByCollectionName

            # Act
            $result = Get-CMASCollectionVariable -CollectionName $testData.CollectionName

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result[0].PSObject.Properties.Name | Should -Contain 'CollectionName'
            $result[0].PSObject.Properties.Name | Should -Contain 'CollectionID'
            $result[0].CollectionName | Should -Be $testData.CollectionName
        }

        It "Should not include OData metadata in output" {
            # Arrange
            $testData = $script:TestGetCollectionVariableData.ByCollectionName

            # Act
            $result = Get-CMASCollectionVariable -CollectionName $testData.CollectionName

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result[0].PSObject.Properties.Name | Should -Not -Contain '@odata.type'
            $result[0].PSObject.Properties.Name | Should -Not -Contain '@odata.context'
        }

        It "Should correctly identify masked variables" {
            # Arrange
            $testData = $script:TestGetCollectionVariableData.ByCollectionIdAndVariableName

            # Act - Get the Test-Masked variable
            $result = Get-CMASCollectionVariable -CollectionID $testData.CollectionId -VariableName $testData.VariableName

            # Assert
            if ($result) {
                $result.IsMasked | Should -Be $true
                # Masked variables have their values hidden (null or empty)
                # This is expected behavior for sensitive variables
                $result.PSObject.Properties.Name | Should -Contain 'Value'
            }
            else {
                Set-ItResult -Skipped -Because "Masked variable not found for testing"
            }
        }
    }

    Context "Multiple Collection Support" {

        It "Should handle collections with many variables efficiently" {
            # Arrange
            $testData = $script:TestGetCollectionVariableData.ByCollectionName

            # Act
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            $result = Get-CMASCollectionVariable -CollectionName $testData.CollectionName
            $stopwatch.Stop()

            # Assert
            $result | Should -Not -BeNullOrEmpty
            # Should complete in reasonable time (< 5 seconds)
            $stopwatch.Elapsed.TotalSeconds | Should -BeLessThan 5
        }
    }
}

AfterAll {
    # No cleanup needed for Get operations
    Write-Verbose "Get-CMASCollectionVariable tests completed"
}

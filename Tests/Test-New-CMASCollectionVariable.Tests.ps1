# Functional Tests for New-CMASCollectionVariable
# Tests the New-CMASCollectionVariable function behavior and return values

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
    $script:TestNewCollectionVariableData = $script:TestData['New-CMASCollectionVariable']

    # Track created variables for cleanup
    $script:CreatedVariables = @()
}

Describe "New-CMASCollectionVariable Function Tests" -Tag "Integration", "CollectionVariable", "Create", "Modify" {

    Context "Test Data Validation" {

        It "Should have test data defined in declarations.ps1" {
            # Assert
            $script:TestNewCollectionVariableData | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('New-CMASCollectionVariable') | Should -Be $true
        }

        It "Should have required test data parameter sets" {
            # Assert
            $script:TestNewCollectionVariableData.ContainsKey('ByCollectionName') | Should -Be $true
            $script:TestNewCollectionVariableData.ContainsKey('ByCollectionId') | Should -Be $true
            $script:TestNewCollectionVariableData.ContainsKey('WithSpecialChars') | Should -Be $true
            $script:TestNewCollectionVariableData.ContainsKey('MaskedVariable') | Should -Be $true
        }

        It "Should output test data for verification" {
            # Output test data
            Write-Host "`n=== Test Data for New-CMASCollectionVariable ===" -ForegroundColor Cyan
            Write-Host "ByCollectionName:" -ForegroundColor Yellow
            Write-Host "  CollectionName: $($script:TestNewCollectionVariableData.ByCollectionName.CollectionName)" -ForegroundColor White
            Write-Host "  VariableName: $($script:TestNewCollectionVariableData.ByCollectionName.VariableName)" -ForegroundColor White
            Write-Host "`nByCollectionId:" -ForegroundColor Yellow
            Write-Host "  CollectionId: $($script:TestNewCollectionVariableData.ByCollectionId.CollectionId)" -ForegroundColor White
            Write-Host "  VariableName: $($script:TestNewCollectionVariableData.ByCollectionId.VariableName)" -ForegroundColor White
            Write-Host "`nMaskedVariable:" -ForegroundColor Yellow
            Write-Host "  IsMasked: $($script:TestNewCollectionVariableData.MaskedVariable.IsMasked)" -ForegroundColor White
        }
    }

    Context "Parameter Validation" {

        It "Should throw error when not connected to Admin Service" {
            # Arrange
            $savedConnection = $script:CMASConnection.SiteServer
            $script:CMASConnection.SiteServer = $null

            # Act & Assert
            { New-CMASCollectionVariable -CollectionName "Test" -VariableName "TestVar" -VariableValue "TestValue" } |
                Should -Throw "*No active connection*"

            # Cleanup
            $script:CMASConnection.SiteServer = $savedConnection
        }

        It "Should throw error when neither CollectionName nor CollectionID is provided" {
            # Act & Assert
            { New-CMASCollectionVariable -VariableName "TestVar" -VariableValue "TestValue" } |
                Should -Throw "*parameter set*"
        }

        It "Should reject variable names with spaces" {
            # Arrange
            $testData = $script:TestNewCollectionVariableData.InvalidVariableName

            # Act & Assert
            { New-CMASCollectionVariable -CollectionName $testData.CollectionName -VariableName $testData.VariableName -VariableValue $testData.VariableValue } |
                Should -Throw
        }

        It "Should accept valid variable name patterns" {
            # Variable names with letters, numbers, underscores, and hyphens should be valid
            $validNames = @('TestVar', 'Test_Var', 'Test-Var', 'TestVar123', 'TEST_VAR_123')

            foreach ($name in $validNames) {
                {
                    $params = @{
                        CollectionName = $script:TestNewCollectionVariableData.ByCollectionName.CollectionName
                        VariableName = $name
                        VariableValue = "test"
                        WhatIf = $true
                    }
                    New-CMASCollectionVariable @params
                } | Should -Not -Throw
            }
        }
    }

    Context "Create Collection Variable by Collection Name" {

        It "Should create a collection variable using collection name" {
            # Arrange
            $testData = $script:TestNewCollectionVariableData.ByCollectionName
            $uniqueVarName = "$($testData.VariableName)_$(Get-Date -Format 'HHmmss')"

            # Act
            $result = New-CMASCollectionVariable -CollectionName $testData.CollectionName -VariableName $uniqueVarName -VariableValue $testData.VariableValue -PassThru

            # Track for cleanup
            if ($result) {
                $script:CreatedVariables += @{ CollectionName = $testData.CollectionName; VariableName = $uniqueVarName }
            }

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $uniqueVarName
            $result.Value | Should -Be $testData.VariableValue
            $result.IsMasked | Should -Be $false
        }

        It "Should verify the created variable exists" {
            # Arrange
            $testData = $script:TestNewCollectionVariableData.ByCollectionName
            $uniqueVarName = "$($testData.VariableName)_Verify_$(Get-Date -Format 'HHmmss')"

            # Act
            New-CMASCollectionVariable -CollectionName $testData.CollectionName -VariableName $uniqueVarName -VariableValue $testData.VariableValue
            Start-Sleep -Seconds 2

            # Track for cleanup
            $script:CreatedVariables += @{ CollectionName = $testData.CollectionName; VariableName = $uniqueVarName }

            # Get collection and check variables
            $collection = Get-CMASCollection -Name $testData.CollectionName
            $settingsPath = "wmi/SMS_CollectionSettings('$($collection.CollectionID)')"
            $settings = Invoke-CMASApi -Path $settingsPath

            # Assert
            $settings.value | Should -Not -BeNullOrEmpty
        }

        It "Should throw error for non-existent collection" {
            # Arrange
            $testData = $script:TestNewCollectionVariableData.NonExistentCollection

            # Act & Assert
            { New-CMASCollectionVariable -CollectionName $testData.CollectionName -VariableName $testData.VariableName -VariableValue $testData.VariableValue } |
                Should -Throw "*not found*"
        }
    }

    Context "Create Collection Variable by CollectionID" {

        It "Should create a collection variable using CollectionID" {
            # Arrange
            $testData = $script:TestNewCollectionVariableData.ByCollectionId
            $uniqueVarName = "$($testData.VariableName)_$(Get-Date -Format 'HHmmss')"

            # Act
            $result = New-CMASCollectionVariable -CollectionID $testData.CollectionId -VariableName $uniqueVarName -VariableValue $testData.VariableValue -PassThru

            # Track for cleanup
            if ($result) {
                $script:CreatedVariables += @{ CollectionId = $testData.CollectionId; VariableName = $uniqueVarName }
            }

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $uniqueVarName
            $result.Value | Should -Be $testData.VariableValue
            $result.CollectionID | Should -Be $testData.CollectionId
        }
    }

    Context "Create Collection Variable with Special Values" {

        It "Should create a variable with special characters in value" {
            # Arrange
            $testData = $script:TestNewCollectionVariableData.WithSpecialChars
            $uniqueVarName = "$($testData.VariableName)_$(Get-Date -Format 'HHmmss')"

            # Act
            $result = New-CMASCollectionVariable -CollectionName $testData.CollectionName -VariableName $uniqueVarName -VariableValue $testData.VariableValue -PassThru

            # Track for cleanup
            if ($result) {
                $script:CreatedVariables += @{ CollectionName = $testData.CollectionName; VariableName = $uniqueVarName }
            }

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $uniqueVarName
            $result.Value | Should -Be $testData.VariableValue
        }

        It "Should create a variable with empty value" {
            # Arrange
            $testData = $script:TestNewCollectionVariableData.EmptyValue
            $uniqueVarName = "$($testData.VariableName)_$(Get-Date -Format 'HHmmss')"

            # Act
            $result = New-CMASCollectionVariable -CollectionName $testData.CollectionName -VariableName $uniqueVarName -VariableValue $testData.VariableValue -PassThru

            # Track for cleanup
            if ($result) {
                $script:CreatedVariables += @{ CollectionName = $testData.CollectionName; VariableName = $uniqueVarName }
            }

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $uniqueVarName
            $result.Value | Should -Be ""
        }
    }

    Context "Create Masked Collection Variable" {

        It "Should create a masked (sensitive) variable" {
            # Arrange
            $testData = $script:TestNewCollectionVariableData.MaskedVariable
            $uniqueVarName = "$($testData.VariableName)_$(Get-Date -Format 'HHmmss')"

            # Act
            $result = New-CMASCollectionVariable -CollectionName $testData.CollectionName -VariableName $uniqueVarName -VariableValue $testData.VariableValue -IsMasked -PassThru

            # Track for cleanup
            if ($result) {
                $script:CreatedVariables += @{ CollectionName = $testData.CollectionName; VariableName = $uniqueVarName }
            }

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $uniqueVarName
            $result.IsMasked | Should -Be $true
        }
    }

    Context "WhatIf Support" {

        It "Should support -WhatIf parameter" {
            # Arrange
            $testData = $script:TestNewCollectionVariableData.ByCollectionName
            $uniqueVarName = "$($testData.VariableName)_WhatIf_$(Get-Date -Format 'HHmmss')"

            # Act & Assert - Should not throw and should not create variable
            { New-CMASCollectionVariable -CollectionName $testData.CollectionName -VariableName $uniqueVarName -VariableValue $testData.VariableValue -WhatIf } |
                Should -Not -Throw

            # Verify variable was not actually created
            Start-Sleep -Seconds 2
            $variables = Get-CMASCollectionVariable -CollectionName $testData.CollectionName -VariableName $uniqueVarName
            $variables | Should -BeNullOrEmpty
        }
    }

    Context "Error Handling" {

        It "Should handle duplicate variable names gracefully" {
            # Arrange
            $testData = $script:TestNewCollectionVariableData.ByCollectionName
            $uniqueVarName = "$($testData.VariableName)_Duplicate_$(Get-Date -Format 'HHmmss')"

            # Act - Create first variable
            New-CMASCollectionVariable -CollectionName $testData.CollectionName -VariableName $uniqueVarName -VariableValue $testData.VariableValue

            # Track for cleanup
            $script:CreatedVariables += @{ CollectionName = $testData.CollectionName; VariableName = $uniqueVarName }

            Start-Sleep -Seconds 2

            # Assert - Attempt to create duplicate should throw error
            { New-CMASCollectionVariable -CollectionName $testData.CollectionName -VariableName $uniqueVarName -VariableValue "DifferentValue" } |
                Should -Throw "*already exists*"
        }
    }

    Context "PassThru Parameter" {

        It "Should return created variable when PassThru is specified" {
            # Arrange
            $testData = $script:TestNewCollectionVariableData.ByCollectionName
            $uniqueVarName = "$($testData.VariableName)_PassThru_$(Get-Date -Format 'HHmmss')"

            # Act
            $result = New-CMASCollectionVariable -CollectionName $testData.CollectionName -VariableName $uniqueVarName -VariableValue $testData.VariableValue -PassThru

            # Track for cleanup
            if ($result) {
                $script:CreatedVariables += @{ CollectionName = $testData.CollectionName; VariableName = $uniqueVarName }
            }

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $uniqueVarName
            $result.Value | Should -Be $testData.VariableValue
            $result.CollectionName | Should -Not -BeNullOrEmpty
            $result.CollectionID | Should -Not -BeNullOrEmpty
        }

        It "Should not return output when PassThru is not specified" {
            # Arrange
            $testData = $script:TestNewCollectionVariableData.ByCollectionName
            $uniqueVarName = "$($testData.VariableName)_NoPassThru_$(Get-Date -Format 'HHmmss')"

            # Act
            $result = New-CMASCollectionVariable -CollectionName $testData.CollectionName -VariableName $uniqueVarName -VariableValue $testData.VariableValue

            # Track for cleanup
            $script:CreatedVariables += @{ CollectionName = $testData.CollectionName; VariableName = $uniqueVarName }

            # Assert
            $result | Should -BeNullOrEmpty
        }
    }
}

AfterAll {
    # Cleanup: Remove created test variables
    Write-Host "`n=== Cleaning up created test variables ===" -ForegroundColor Cyan

    foreach ($varInfo in $script:CreatedVariables) {
        try {
            if ($varInfo.CollectionName) {
                Write-Host "Removing variable '$($varInfo.VariableName)' from collection '$($varInfo.CollectionName)'..." -ForegroundColor Yellow
                Remove-CMASCollectionVariable -CollectionName $varInfo.CollectionName -VariableName $varInfo.VariableName -Confirm:$false
            }
            elseif ($varInfo.CollectionId) {
                Write-Host "Removing variable '$($varInfo.VariableName)' from collection '$($varInfo.CollectionId)'..." -ForegroundColor Yellow
                Remove-CMASCollectionVariable -CollectionID $varInfo.CollectionId -VariableName $varInfo.VariableName -Confirm:$false
            }
            Write-Host "  Removed successfully" -ForegroundColor Green
        }
        catch {
            Write-Host "  Failed to remove: $_" -ForegroundColor Red
        }
    }

    Write-Host "Cleanup completed`n" -ForegroundColor Cyan
}

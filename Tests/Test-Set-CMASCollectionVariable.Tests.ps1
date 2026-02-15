# Functional Tests for Set-CMASCollectionVariable
# Tests the Set-CMASCollectionVariable function behavior and return values

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
    $script:TestSetCollectionVariableData = $script:TestData['Set-CMASCollectionVariable']

    # Track created variables for cleanup
    $script:TestVariables = @()
}

Describe "Set-CMASCollectionVariable Function Tests" -Tag "Integration", "CollectionVariable", "Modify" {

    Context "Test Data Validation" {

        It "Should have test data defined in declarations.ps1" {
            # Assert
            $script:TestSetCollectionVariableData | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('Set-CMASCollectionVariable') | Should -Be $true
        }

        It "Should have required test data parameter sets" {
            # Assert
            $script:TestSetCollectionVariableData.ContainsKey('ByCollectionName') | Should -Be $true
            $script:TestSetCollectionVariableData.ContainsKey('ByCollectionId') | Should -Be $true
            $script:TestSetCollectionVariableData.ContainsKey('ChangeMaskedState') | Should -Be $true
            $script:TestSetCollectionVariableData.ContainsKey('EmptyValue') | Should -Be $true
        }

        It "Should output test data for verification" {
            # Output test data
            Write-Host "`n=== Test Data for Set-CMASCollectionVariable ===" -ForegroundColor Cyan
            Write-Host "ByCollectionName:" -ForegroundColor Yellow
            Write-Host "  CollectionName: $($script:TestSetCollectionVariableData.ByCollectionName.CollectionName)" -ForegroundColor White
            Write-Host "  VariableName: $($script:TestSetCollectionVariableData.ByCollectionName.VariableName)" -ForegroundColor White
            Write-Host "`nByCollectionId:" -ForegroundColor Yellow
            Write-Host "  CollectionId: $($script:TestSetCollectionVariableData.ByCollectionId.CollectionId)" -ForegroundColor White
            Write-Host "  VariableName: $($script:TestSetCollectionVariableData.ByCollectionId.VariableName)" -ForegroundColor White
        }
    }

    Context "Parameter Validation" {

        It "Should throw error when not connected to Admin Service" {
            # Arrange
            $savedConnection = $script:CMASConnection.SiteServer
            $script:CMASConnection.SiteServer = $null

            # Act & Assert
            { Set-CMASCollectionVariable -CollectionName "Test" -VariableName "TestVar" -VariableValue "TestValue" } |
                Should -Throw "*No active connection*"

            # Cleanup
            $script:CMASConnection.SiteServer = $savedConnection
        }

        It "Should throw error when neither CollectionName nor CollectionID is provided" {
            # Act & Assert
            { Set-CMASCollectionVariable -VariableName "TestVar" -VariableValue "TestValue" } |
                Should -Throw "*Either CollectionName or CollectionID must be specified*"
        }

        It "Should throw error when both IsMasked and IsNotMasked are specified" {
            # Arrange
            $testData = $script:TestSetCollectionVariableData.ByCollectionName

            # Act & Assert
            { Set-CMASCollectionVariable -CollectionName $testData.CollectionName -VariableName "TestVar" -VariableValue "Test" -IsMasked -IsNotMasked } |
                Should -Throw "*Cannot specify both*"
        }
    }

    Context "Modify Collection Variable by Collection Name" {

        It "Should modify a collection variable value using collection name" {
            # Arrange
            $testData = $script:TestSetCollectionVariableData.ByCollectionName
            $uniqueVarName = "$($testData.VariableName)_$(Get-Date -Format 'HHmmss')"

            # Create the variable first
            New-CMASCollectionVariable -CollectionName $testData.CollectionName -VariableName $uniqueVarName -VariableValue $testData.OriginalValue | Out-Null
            Start-Sleep -Seconds 2

            # Track for cleanup
            $script:TestVariables += @{ CollectionName = $testData.CollectionName; VariableName = $uniqueVarName }

            # Act
            $result = Set-CMASCollectionVariable -CollectionName $testData.CollectionName -VariableName $uniqueVarName -VariableValue $testData.NewValue -PassThru

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $uniqueVarName
            $result.Value | Should -Be $testData.NewValue
            $result.IsMasked | Should -Be $false
        }

        It "Should verify the modified variable value" {
            # Arrange
            $testData = $script:TestSetCollectionVariableData.ByCollectionName
            $uniqueVarName = "$($testData.VariableName)_Verify_$(Get-Date -Format 'HHmmss')"

            # Create the variable first
            New-CMASCollectionVariable -CollectionName $testData.CollectionName -VariableName $uniqueVarName -VariableValue $testData.OriginalValue | Out-Null
            Start-Sleep -Seconds 2

            # Track for cleanup
            $script:TestVariables += @{ CollectionName = $testData.CollectionName; VariableName = $uniqueVarName }

            # Modify the variable
            Set-CMASCollectionVariable -CollectionName $testData.CollectionName -VariableName $uniqueVarName -VariableValue $testData.NewValue
            Start-Sleep -Seconds 2

            # Act - Get the variable
            $retrievedVar = Get-CMASCollectionVariable -CollectionName $testData.CollectionName -VariableName $uniqueVarName

            # Assert
            $retrievedVar | Should -Not -BeNullOrEmpty
            $retrievedVar.Value | Should -Be $testData.NewValue
        }

        It "Should throw error for non-existent collection" {
            # Arrange
            $testData = $script:TestSetCollectionVariableData.NonExistentCollection

            # Act & Assert
            { Set-CMASCollectionVariable -CollectionName $testData.CollectionName -VariableName $testData.VariableName -VariableValue $testData.NewValue } |
                Should -Throw "*not found*"
        }

        It "Should throw error for non-existent variable" {
            # Arrange
            $testData = $script:TestSetCollectionVariableData.NonExistentVariable

            # Act & Assert
            { Set-CMASCollectionVariable -CollectionName $testData.CollectionName -VariableName $testData.VariableName -VariableValue $testData.NewValue } |
                Should -Throw "*not found*"
        }
    }

    Context "Modify Collection Variable by CollectionID" {

        It "Should modify a collection variable using CollectionID" {
            # Arrange
            $testData = $script:TestSetCollectionVariableData.ByCollectionId
            $uniqueVarName = "$($testData.VariableName)_$(Get-Date -Format 'HHmmss')"

            # Create the variable first
            New-CMASCollectionVariable -CollectionID $testData.CollectionId -VariableName $uniqueVarName -VariableValue $testData.OriginalValue | Out-Null
            Start-Sleep -Seconds 2

            # Track for cleanup
            $script:TestVariables += @{ CollectionId = $testData.CollectionId; VariableName = $uniqueVarName }

            # Act
            $result = Set-CMASCollectionVariable -CollectionID $testData.CollectionId -VariableName $uniqueVarName -VariableValue $testData.NewValue -PassThru

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $uniqueVarName
            $result.Value | Should -Be $testData.NewValue
            $result.CollectionID | Should -Be $testData.CollectionId
        }
    }

    Context "Modify Collection Variable Masked State" {

        It "Should mark a variable as masked" {
            # Arrange
            $testData = $script:TestSetCollectionVariableData.ChangeMaskedState
            $uniqueVarName = "$($testData.VariableName)_$(Get-Date -Format 'HHmmss')"

            # Create the variable first (not masked)
            New-CMASCollectionVariable -CollectionName $testData.CollectionName -VariableName $uniqueVarName -VariableValue $testData.OriginalValue | Out-Null
            Start-Sleep -Seconds 2

            # Track for cleanup
            $script:TestVariables += @{ CollectionName = $testData.CollectionName; VariableName = $uniqueVarName }

            # Act - Modify to masked
            $result = Set-CMASCollectionVariable -CollectionName $testData.CollectionName -VariableName $uniqueVarName -VariableValue $testData.NewValue -IsMasked -PassThru

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $uniqueVarName
            $result.IsMasked | Should -Be $true
        }

        It "Should unmask a masked variable" {
            # Arrange
            $testData = $script:TestSetCollectionVariableData.UnmaskVariable
            $uniqueVarName = "$($testData.VariableName)_$(Get-Date -Format 'HHmmss')"

            # Create the variable first (masked)
            New-CMASCollectionVariable -CollectionName $testData.CollectionName -VariableName $uniqueVarName -VariableValue $testData.OriginalValue -IsMasked | Out-Null
            Start-Sleep -Seconds 2

            # Track for cleanup
            $script:TestVariables += @{ CollectionName = $testData.CollectionName; VariableName = $uniqueVarName }

            # Act - Modify to not masked
            $result = Set-CMASCollectionVariable -CollectionName $testData.CollectionName -VariableName $uniqueVarName -VariableValue $testData.NewValue -IsNotMasked -PassThru

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $uniqueVarName
            $result.Value | Should -Be $testData.NewValue
            $result.IsMasked | Should -Be $false
        }
    }

    Context "Modify Variable with Special Values" {

        It "Should modify a variable to an empty value" {
            # Arrange
            $testData = $script:TestSetCollectionVariableData.EmptyValue
            $uniqueVarName = "$($testData.VariableName)_$(Get-Date -Format 'HHmmss')"

            # Create the variable first
            New-CMASCollectionVariable -CollectionName $testData.CollectionName -VariableName $uniqueVarName -VariableValue $testData.OriginalValue | Out-Null
            Start-Sleep -Seconds 2

            # Track for cleanup
            $script:TestVariables += @{ CollectionName = $testData.CollectionName; VariableName = $uniqueVarName }

            # Act
            $result = Set-CMASCollectionVariable -CollectionName $testData.CollectionName -VariableName $uniqueVarName -VariableValue "" -PassThru

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Value | Should -Be ""
        }
    }

    Context "Return Values and Types" {

        It "Should return object with PassThru parameter" {
            # Arrange
            $testData = $script:TestSetCollectionVariableData.ByCollectionName
            $uniqueVarName = "$($testData.VariableName)_PassThru_$(Get-Date -Format 'HHmmss')"

            # Create the variable first
            New-CMASCollectionVariable -CollectionName $testData.CollectionName -VariableName $uniqueVarName -VariableValue $testData.OriginalValue | Out-Null
            Start-Sleep -Seconds 2

            # Track for cleanup
            $script:TestVariables += @{ CollectionName = $testData.CollectionName; VariableName = $uniqueVarName }

            # Act
            $result = Set-CMASCollectionVariable -CollectionName $testData.CollectionName -VariableName $uniqueVarName -VariableValue $testData.NewValue -PassThru

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.PSObject.Properties.Name | Should -Contain 'Name'
            $result.PSObject.Properties.Name | Should -Contain 'Value'
            $result.PSObject.Properties.Name | Should -Contain 'CollectionID'
            $result.PSObject.Properties.Name | Should -Contain 'CollectionName'
        }
    }

    Context "WhatIf Support" {

        It "Should support WhatIf without making changes" {
            # Arrange
            $testData = $script:TestSetCollectionVariableData.ByCollectionName
            $uniqueVarName = "$($testData.VariableName)_WhatIf_$(Get-Date -Format 'HHmmss')"

            # Create the variable first
            New-CMASCollectionVariable -CollectionName $testData.CollectionName -VariableName $uniqueVarName -VariableValue $testData.OriginalValue | Out-Null
            Start-Sleep -Seconds 2

            # Track for cleanup
            $script:TestVariables += @{ CollectionName = $testData.CollectionName; VariableName = $uniqueVarName }

            # Act
            Set-CMASCollectionVariable -CollectionName $testData.CollectionName -VariableName $uniqueVarName -VariableValue $testData.NewValue -WhatIf
            Start-Sleep -Seconds 2

            # Assert - value should not change
            $result = Get-CMASCollectionVariable -CollectionName $testData.CollectionName -VariableName $uniqueVarName
            $result.Value | Should -Be $testData.OriginalValue
        }
    }
}

AfterAll {
    foreach ($varInfo in $script:TestVariables) {
        try {
            if ($varInfo.CollectionName) {
                Remove-CMASCollectionVariable -CollectionName $varInfo.CollectionName -VariableName $varInfo.VariableName -Force -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
            }
            elseif ($varInfo.CollectionId) {
                Remove-CMASCollectionVariable -CollectionID $varInfo.CollectionId -VariableName $varInfo.VariableName -Force -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
            }
        }
        catch {
            Write-Warning "Failed to cleanup collection variable '$($varInfo.VariableName)': $($_.Exception.Message)"
        }
    }

    Write-Verbose "Set-CMASCollectionVariable tests completed"
}

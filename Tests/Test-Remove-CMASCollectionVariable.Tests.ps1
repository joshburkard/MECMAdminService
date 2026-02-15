# Functional Tests for Remove-CMASCollectionVariable
# Tests the Remove-CMASCollectionVariable function behavior and return values

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
    $script:TestRemoveCollectionVariableData = $script:TestData['Remove-CMASCollectionVariable']

    # Create test variables that will be removed during tests
    $testCollection = $script:TestRemoveCollectionVariableData.ByCollectionName.CollectionName
    $timestamp = Get-Date -Format 'yyyyMMddHHmmss'

    # Create variables for removal tests
    $script:RemoveTestVarByName = "TestCollVar_Remove_$timestamp"
    $script:RemoveTestVarByID = "TestCollVar_RemoveByID_$timestamp"
    $script:RemoveWildcardVars = @(
        "TestCollVar_RemoveWildcard_${timestamp}_01"
        "TestCollVar_RemoveWildcard_${timestamp}_02"
        "TestCollVar_RemoveWildcard_${timestamp}_03"
    )

    try {
        # Create test variable for ByCollectionName tests
        New-CMASCollectionVariable -CollectionName $testCollection -VariableName $script:RemoveTestVarByName -VariableValue "ToBeRemoved" -ErrorAction SilentlyContinue | Out-Null

        # Create test variable for ByCollectionId tests
        $collectionId = $script:TestRemoveCollectionVariableData.ByCollectionId.CollectionId
        New-CMASCollectionVariable -CollectionID $collectionId -VariableName $script:RemoveTestVarByID -VariableValue "ToBeRemoved" -ErrorAction SilentlyContinue | Out-Null

        # Create test variables for wildcard removal tests
        foreach ($varName in $script:RemoveWildcardVars) {
            New-CMASCollectionVariable -CollectionName $testCollection -VariableName $varName -VariableValue "ToBeRemoved" -ErrorAction SilentlyContinue | Out-Null
        }
    }
    catch {
        Write-Warning "Failed to create test variables in BeforeAll: $($_.Exception.Message)"
    }
}

Describe "Remove-CMASCollectionVariable Function Tests" -Tag "Integration", "CollectionVariable", "Remove", "Delete" {

    Context "Test Data Validation" {

        It "Should have test data defined in declarations.ps1" {
            # Assert
            $script:TestRemoveCollectionVariableData | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('Remove-CMASCollectionVariable') | Should -Be $true
        }

        It "Should have required test data parameter sets" {
            # Assert
            $script:TestRemoveCollectionVariableData.ContainsKey('ByCollectionName') | Should -Be $true
            $script:TestRemoveCollectionVariableData.ContainsKey('ByCollectionId') | Should -Be $true
            $script:TestRemoveCollectionVariableData.ContainsKey('ByWildcard') | Should -Be $true
        }

        It "Should output test data for verification" {
            # Output test data
            Write-Host "`n=== Test Data for Remove-CMASCollectionVariable ===" -ForegroundColor Cyan
            Write-Host "ByCollectionName:" -ForegroundColor Yellow
            Write-Host "  CollectionName: $($script:TestRemoveCollectionVariableData.ByCollectionName.CollectionName)" -ForegroundColor White
            Write-Host "  Test Variable: $script:RemoveTestVarByName" -ForegroundColor White
            Write-Host "`nByCollectionId:" -ForegroundColor Yellow
            Write-Host "  CollectionId: $($script:TestRemoveCollectionVariableData.ByCollectionId.CollectionId)" -ForegroundColor White
            Write-Host "  Test Variable: $script:RemoveTestVarByID" -ForegroundColor White
            Write-Host "`nByWildcard:" -ForegroundColor Yellow
            Write-Host "  Pattern: TestCollVar_RemoveWildcard_*" -ForegroundColor White
            Write-Host "  Variables: $($script:RemoveWildcardVars -join ', ')" -ForegroundColor White
        }
    }

    Context "Parameter Validation" {

        It "Should throw error when not connected to Admin Service" {
            # Arrange
            $savedConnection = $script:CMASConnection.SiteServer
            $script:CMASConnection.SiteServer = $null

            # Act & Assert
            { Remove-CMASCollectionVariable -CollectionName "Test" -VariableName "TestVar" -Force -Confirm:$false } |
                Should -Throw "*No active connection*"

            # Cleanup
            $script:CMASConnection.SiteServer = $savedConnection
        }

        It "Should throw error when neither CollectionName nor CollectionID is provided" {
            # Act & Assert
            { Remove-CMASCollectionVariable -VariableName "TestVar" -Force -Confirm:$false -ErrorAction Stop } |
                Should -Throw "*Either CollectionName or CollectionID must be specified*"
        }
    }

    Context "Remove Collection Variable by Collection Name" {

        BeforeEach {
            # Ensure test variable exists before each test
            $testData = $script:TestRemoveCollectionVariableData.ByCollectionName
            $timestamp = Get-Date -Format 'yyyyMMddHHmmss'
            $script:CurrentTestVar = "TestCollVar_Remove_Context_$timestamp"

            try {
                New-CMASCollectionVariable -CollectionName $testData.CollectionName -VariableName $script:CurrentTestVar -VariableValue "ToBeRemoved" -ErrorAction Stop | Out-Null
            }
            catch {
                Write-Warning "Failed to create test variable: $($_.Exception.Message)"
            }
        }

        It "Should remove a single variable by collection name" {
            # Arrange
            $testData = $script:TestRemoveCollectionVariableData.ByCollectionName

            # Act
            Remove-CMASCollectionVariable -CollectionName $testData.CollectionName -VariableName $script:CurrentTestVar -Force -Confirm:$false

            # Assert - variable should not exist anymore
            $result = Get-CMASCollectionVariable -CollectionName $testData.CollectionName -VariableName $script:CurrentTestVar -ErrorAction SilentlyContinue
            $result | Should -BeNullOrEmpty
        }

        It "Should support WhatIf parameter" {
            # Arrange
            $testData = $script:TestRemoveCollectionVariableData.ByCollectionName

            # Act
            Remove-CMASCollectionVariable -CollectionName $testData.CollectionName -VariableName $script:CurrentTestVar -WhatIf

            # Assert - variable should still exist
            $result = Get-CMASCollectionVariable -CollectionName $testData.CollectionName -VariableName $script:CurrentTestVar
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $script:CurrentTestVar
        }

        It "Should return removed variable object" {
            # Arrange
            $testData = $script:TestRemoveCollectionVariableData.ByCollectionName

            # Act
            $result = Remove-CMASCollectionVariable -CollectionName $testData.CollectionName -VariableName $script:CurrentTestVar -Force -Confirm:$false

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $script:CurrentTestVar
        }
    }

    Context "Remove Collection Variable by CollectionID" {

        BeforeEach {
            # Ensure test variable exists before each test
            $testData = $script:TestRemoveCollectionVariableData.ByCollectionId
            $timestamp = Get-Date -Format 'yyyyMMddHHmmss'
            $script:CurrentTestVarByID = "TestCollVar_RemoveByID_Context_$timestamp"

            try {
                New-CMASCollectionVariable -CollectionID $testData.CollectionId -VariableName $script:CurrentTestVarByID -VariableValue "ToBeRemoved" -ErrorAction Stop | Out-Null
            }
            catch {
                Write-Warning "Failed to create test variable: $($_.Exception.Message)"
            }
        }

        It "Should remove a single variable by CollectionID" {
            # Arrange
            $testData = $script:TestRemoveCollectionVariableData.ByCollectionId

            # Act
            Remove-CMASCollectionVariable -CollectionID $testData.CollectionId -VariableName $script:CurrentTestVarByID -Force -Confirm:$false

            # Assert - variable should not exist anymore
            $result = Get-CMASCollectionVariable -CollectionID $testData.CollectionId -VariableName $script:CurrentTestVarByID -ErrorAction SilentlyContinue
            $result | Should -BeNullOrEmpty
        }

        It "Should return removed variable object when using CollectionID" {
            # Arrange
            $testData = $script:TestRemoveCollectionVariableData.ByCollectionId

            # Act
            $result = Remove-CMASCollectionVariable -CollectionID $testData.CollectionId -VariableName $script:CurrentTestVarByID -Force -Confirm:$false

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $script:CurrentTestVarByID
        }
    }

    Context "Remove Multiple Variables with Wildcard Pattern" {

        BeforeEach {
            # Create test variables for wildcard removal
            $testData = $script:TestRemoveCollectionVariableData.ByWildcard
            $timestamp = Get-Date -Format 'yyyyMMddHHmmss'
            $script:WildcardTestVars = @(
                "TestCollVar_WildcardBatch_${timestamp}_01"
                "TestCollVar_WildcardBatch_${timestamp}_02"
                "TestCollVar_WildcardBatch_${timestamp}_03"
            )

            try {
                foreach ($varName in $script:WildcardTestVars) {
                    New-CMASCollectionVariable -CollectionName $testData.CollectionName -VariableName $varName -VariableValue "ToBeRemoved" -ErrorAction Stop | Out-Null
                }
            }
            catch {
                Write-Warning "Failed to create wildcard test variables: $($_.Exception.Message)"
            }
        }

        It "Should remove multiple variables matching wildcard pattern" {
            # Arrange
            $testData = $script:TestRemoveCollectionVariableData.ByWildcard
            $pattern = "TestCollVar_WildcardBatch_*"

            # Act
            $result = Remove-CMASCollectionVariable -CollectionName $testData.CollectionName -VariableName $pattern -Force -Confirm:$false

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -BeGreaterOrEqual 3

            # Verify variables are actually removed
            $remaining = Get-CMASCollectionVariable -CollectionName $testData.CollectionName | Where-Object { $_.Name -like $pattern }
            $remaining | Should -BeNullOrEmpty
        }

        It "Should return all removed variables when using wildcard" {
            # Arrange
            $testData = $script:TestRemoveCollectionVariableData.ByWildcard
            $pattern = "TestCollVar_WildcardBatch_*"

            # Act
            $result = Remove-CMASCollectionVariable -CollectionName $testData.CollectionName -VariableName $pattern -Force -Confirm:$false

            # Assert
            $result | ForEach-Object {
                $_.Name | Should -Match "^TestCollVar_WildcardBatch_"
            }
        }
    }

    Context "Error Handling" {

        It "Should throw error for non-existent collection by name" {
            # Arrange
            $testData = $script:TestRemoveCollectionVariableData.NonExistentCollection

            # Act & Assert
            { Remove-CMASCollectionVariable -CollectionName $testData.CollectionName -VariableName $testData.VariableName -Force -ErrorAction Stop } |
                Should -Throw
        }

        It "Should handle non-existent variable gracefully" {
            # Arrange
            $testData = $script:TestRemoveCollectionVariableData.NonExistentVariable

            # Act & Assert
            # Should not throw, but should return nothing or warning
            $result = Remove-CMASCollectionVariable -CollectionName $testData.CollectionName -VariableName $testData.VariableName -Force -Confirm:$false -ErrorAction SilentlyContinue
            $result | Should -BeNullOrEmpty
        }

        It "Should handle invalid CollectionID" {
            # Act & Assert
            { Remove-CMASCollectionVariable -CollectionID "XXX99999" -VariableName "TestVar" -Force -Confirm:$false -ErrorAction Stop } |
                Should -Throw
        }
    }

    Context "Pipeline Support" {

        BeforeAll {
            # Create test variables for pipeline tests
            $testData = $script:TestRemoveCollectionVariableData.ByCollectionName
            $timestamp = Get-Date -Format 'yyyyMMddHHmmss'
            $script:PipelineTestVars = @(
                "TestCollVar_Pipeline_${timestamp}_01"
                "TestCollVar_Pipeline_${timestamp}_02"
            )

            try {
                foreach ($varName in $script:PipelineTestVars) {
                    New-CMASCollectionVariable -CollectionName $testData.CollectionName -VariableName $varName -VariableValue "ForPipeline" -ErrorAction Stop | Out-Null
                }
            }
            catch {
                Write-Warning "Failed to create pipeline test variables: $($_.Exception.Message)"
            }
        }

        It "Should accept collection object from pipeline (Get-CMASCollection)" {
            # Arrange
            $testData = $script:TestRemoveCollectionVariableData.ByCollectionName
            $varName = $script:PipelineTestVars[0]

            # Act
            $result = Get-CMASCollection -Name $testData.CollectionName | Remove-CMASCollectionVariable -VariableName $varName -Force -Confirm:$false

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $varName

            # Verify removal
            $check = Get-CMASCollectionVariable -CollectionName $testData.CollectionName -VariableName $varName -ErrorAction SilentlyContinue
            $check | Should -BeNullOrEmpty
        }

        It "Should accept variable object from pipeline (Get-CMASCollectionVariable)" {
            # Arrange
            $testData = $script:TestRemoveCollectionVariableData.ByCollectionName
            $varName = $script:PipelineTestVars[1]

            # Act
            $result = Get-CMASCollectionVariable -CollectionName $testData.CollectionName -VariableName $varName | Remove-CMASCollectionVariable -Force -Confirm:$false

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $varName

            # Verify removal
            $check = Get-CMASCollectionVariable -CollectionName $testData.CollectionName -VariableName $varName -ErrorAction SilentlyContinue
            $check | Should -BeNullOrEmpty
        }
    }

    Context "Force and Confirm Parameters" {

        BeforeEach {
            # Create test variable
            $testData = $script:TestRemoveCollectionVariableData.ByCollectionName
            $timestamp = Get-Date -Format 'yyyyMMddHHmmss'
            $script:ForceTestVar = "TestCollVar_Force_$timestamp"

            try {
                New-CMASCollectionVariable -CollectionName $testData.CollectionName -VariableName $script:ForceTestVar -VariableValue "ToTest" -ErrorAction Stop | Out-Null
            }
            catch {
                Write-Warning "Failed to create force test variable: $($_.Exception.Message)"
            }
        }

        It "Should remove variable when Force parameter is used" {
            # Arrange
            $testData = $script:TestRemoveCollectionVariableData.ByCollectionName

            # Act
            $result = Remove-CMASCollectionVariable -CollectionName $testData.CollectionName -VariableName $script:ForceTestVar -Force -Confirm:$false

            # Assert
            $result | Should -Not -BeNullOrEmpty

            # Verify removal
            $check = Get-CMASCollectionVariable -CollectionName $testData.CollectionName -VariableName $script:ForceTestVar -ErrorAction SilentlyContinue
            $check | Should -BeNullOrEmpty
        }
    }
}

AfterAll {
    # Clean up any remaining test variables
    $testCollection = $script:TestRemoveCollectionVariableData.ByCollectionName.CollectionName

    try {
        # Remove any leftover test variables
        $allTestVars = @(
            $script:RemoveTestVarByName
            $script:RemoveTestVarByID
        ) + $script:RemoveWildcardVars + $script:WildcardTestVars + $script:PipelineTestVars

        foreach ($varName in $allTestVars) {
            if ($varName) {
                Remove-CMASCollectionVariable -CollectionName $testCollection -VariableName $varName -Force -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
            }
        }

        # Also clean up any variables matching test patterns
        $patterns = @(
            "TestCollVar_Remove_*"
            "TestCollVar_RemoveByID_*"
            "TestCollVar_RemoveWildcard_*"
            "TestCollVar_WildcardBatch_*"
            "TestCollVar_Pipeline_*"
            "TestCollVar_Force_*"
        )

        foreach ($pattern in $patterns) {
            Remove-CMASCollectionVariable -CollectionName $testCollection -VariableName $pattern -Force -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
        }
    }
    catch {
        Write-Warning "Failed to clean up test variables in AfterAll: $($_.Exception.Message)"
    }
}

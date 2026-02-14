# Functional Tests for Remove-CMASDeviceVariable
# Tests the Remove-CMASDeviceVariable function behavior and return values

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
    $script:TestRemoveDeviceVariableData = $script:TestData['Remove-CMASDeviceVariable']

    # Create test variables that will be removed during tests
    $testDevice = $script:TestRemoveDeviceVariableData.ByDeviceName.DeviceName
    $timestamp = Get-Date -Format 'yyyyMMddHHmmss'

    # Create variables for removal tests
    $script:RemoveTestVarByName = "TestVar_Remove_$timestamp"
    $script:RemoveTestVarByID = "TestVar_RemoveByID_$timestamp"
    $script:RemoveWildcardVars = @(
        "TestVar_RemoveWildcard_${timestamp}_01"
        "TestVar_RemoveWildcard_${timestamp}_02"
        "TestVar_RemoveWildcard_${timestamp}_03"
    )

    try {
        # Create test variable for ByDeviceName tests
        New-CMASDeviceVariable -DeviceName $testDevice -VariableName $script:RemoveTestVarByName -VariableValue "ToBeRemoved" -ErrorAction SilentlyContinue | Out-Null

        # Create test variable for ByResourceId tests
        $resourceId = $script:TestRemoveDeviceVariableData.ByResourceId.ResourceId
        New-CMASDeviceVariable -ResourceID $resourceId -VariableName $script:RemoveTestVarByID -VariableValue "ToBeRemoved" -ErrorAction SilentlyContinue | Out-Null

        # Create test variables for wildcard removal tests
        foreach ($varName in $script:RemoveWildcardVars) {
            New-CMASDeviceVariable -DeviceName $testDevice -VariableName $varName -VariableValue "ToBeRemoved" -ErrorAction SilentlyContinue | Out-Null
        }
    }
    catch {
        Write-Warning "Failed to create test variables in BeforeAll: $($_.Exception.Message)"
    }
}

Describe "Remove-CMASDeviceVariable Function Tests" -Tag "Integration", "DeviceVariable", "Remove", "Delete" {

    Context "Test Data Validation" {

        It "Should have test data defined in declarations.ps1" {
            # Assert
            $script:TestRemoveDeviceVariableData | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('Remove-CMASDeviceVariable') | Should -Be $true
        }

        It "Should have required test data parameter sets" {
            # Assert
            $script:TestRemoveDeviceVariableData.ContainsKey('ByDeviceName') | Should -Be $true
            $script:TestRemoveDeviceVariableData.ContainsKey('ByResourceId') | Should -Be $true
            $script:TestRemoveDeviceVariableData.ContainsKey('ByWildcard') | Should -Be $true
        }

        It "Should output test data for verification" {
            # Output test data
            Write-Host "`n=== Test Data for Remove-CMASDeviceVariable ===" -ForegroundColor Cyan
            Write-Host "ByDeviceName:" -ForegroundColor Yellow
            Write-Host "  DeviceName: $($script:TestRemoveDeviceVariableData.ByDeviceName.DeviceName)" -ForegroundColor White
            Write-Host "  Test Variable: $script:RemoveTestVarByName" -ForegroundColor White
            Write-Host "`nByResourceId:" -ForegroundColor Yellow
            Write-Host "  ResourceId: $($script:TestRemoveDeviceVariableData.ByResourceId.ResourceId)" -ForegroundColor White
            Write-Host "  Test Variable: $script:RemoveTestVarByID" -ForegroundColor White
            Write-Host "`nByWildcard:" -ForegroundColor Yellow
            Write-Host "  Pattern: TestVar_RemoveWildcard_*" -ForegroundColor White
            Write-Host "  Variables: $($script:RemoveWildcardVars -join ', ')" -ForegroundColor White
        }
    }

    Context "Parameter Validation" {

        It "Should throw error when not connected to Admin Service" {
            # Arrange
            $savedConnection = $script:CMASConnection.SiteServer
            $script:CMASConnection.SiteServer = $null

            # Act & Assert
            { Remove-CMASDeviceVariable -DeviceName "Test" -VariableName "TestVar" -Force } |
                Should -Throw "*No active connection*"

            # Cleanup
            $script:CMASConnection.SiteServer = $savedConnection
        }

        It "Should throw error when neither DeviceName nor ResourceID is provided" {
            # Act & Assert
            { Remove-CMASDeviceVariable -VariableName "TestVar" -Force } |
                Should -Throw "*parameter set*"
        }
    }

    Context "Remove Device Variable by Device Name" {

        BeforeEach {
            # Ensure test variable exists before each test
            $testData = $script:TestRemoveDeviceVariableData.ByDeviceName
            $timestamp = Get-Date -Format 'yyyyMMddHHmmss'
            $script:CurrentTestVar = "TestVar_Remove_Context_$timestamp"

            try {
                New-CMASDeviceVariable -DeviceName $testData.DeviceName -VariableName $script:CurrentTestVar -VariableValue "ToBeRemoved" -ErrorAction Stop | Out-Null
            }
            catch {
                Write-Warning "Failed to create test variable: $($_.Exception.Message)"
            }
        }

        It "Should remove a single variable by device name" {
            # Arrange
            $testData = $script:TestRemoveDeviceVariableData.ByDeviceName

            # Act
            Remove-CMASDeviceVariable -DeviceName $testData.DeviceName -VariableName $script:CurrentTestVar -Force

            # Assert - variable should not exist anymore
            $result = Get-CMASDeviceVariable -DeviceName $testData.DeviceName -VariableName $script:CurrentTestVar -ErrorAction SilentlyContinue
            $result | Should -BeNullOrEmpty
        }

        It "Should support WhatIf parameter" {
            # Arrange
            $testData = $script:TestRemoveDeviceVariableData.ByDeviceName

            # Act
            Remove-CMASDeviceVariable -DeviceName $testData.DeviceName -VariableName $script:CurrentTestVar -WhatIf

            # Assert - variable should still exist
            $result = Get-CMASDeviceVariable -DeviceName $testData.DeviceName -VariableName $script:CurrentTestVar
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $script:CurrentTestVar
        }

        It "Should return removed variable object" {
            # Arrange
            $testData = $script:TestRemoveDeviceVariableData.ByDeviceName

            # Act
            $result = Remove-CMASDeviceVariable -DeviceName $testData.DeviceName -VariableName $script:CurrentTestVar -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $script:CurrentTestVar
        }
    }

    Context "Remove Device Variable by ResourceID" {

        BeforeEach {
            # Ensure test variable exists before each test
            $testData = $script:TestRemoveDeviceVariableData.ByResourceId
            $timestamp = Get-Date -Format 'yyyyMMddHHmmss'
            $script:CurrentTestVarByID = "TestVar_RemoveByID_Context_$timestamp"

            try {
                New-CMASDeviceVariable -ResourceID $testData.ResourceId -VariableName $script:CurrentTestVarByID -VariableValue "ToBeRemoved" -ErrorAction Stop | Out-Null
            }
            catch {
                Write-Warning "Failed to create test variable: $($_.Exception.Message)"
            }
        }

        It "Should remove a single variable by ResourceID" {
            # Arrange
            $testData = $script:TestRemoveDeviceVariableData.ByResourceId

            # Act
            Remove-CMASDeviceVariable -ResourceID $testData.ResourceId -VariableName $script:CurrentTestVarByID -Force

            # Assert - variable should not exist anymore
            $result = Get-CMASDeviceVariable -ResourceID $testData.ResourceId -VariableName $script:CurrentTestVarByID -ErrorAction SilentlyContinue
            $result | Should -BeNullOrEmpty
        }

        It "Should return removed variable object when using ResourceID" {
            # Arrange
            $testData = $script:TestRemoveDeviceVariableData.ByResourceId

            # Act
            $result = Remove-CMASDeviceVariable -ResourceID $testData.ResourceId -VariableName $script:CurrentTestVarByID -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $script:CurrentTestVarByID
        }
    }

    Context "Remove Multiple Variables with Wildcard Pattern" {

        BeforeEach {
            # Create test variables for wildcard removal
            $testData = $script:TestRemoveDeviceVariableData.ByWildcard
            $timestamp = Get-Date -Format 'yyyyMMddHHmmss'
            $script:WildcardTestVars = @(
                "TestVar_WildcardBatch_${timestamp}_01"
                "TestVar_WildcardBatch_${timestamp}_02"
                "TestVar_WildcardBatch_${timestamp}_03"
            )

            try {
                foreach ($varName in $script:WildcardTestVars) {
                    New-CMASDeviceVariable -DeviceName $testData.DeviceName -VariableName $varName -VariableValue "ToBeRemoved" -ErrorAction Stop | Out-Null
                }
            }
            catch {
                Write-Warning "Failed to create wildcard test variables: $($_.Exception.Message)"
            }
        }

        It "Should remove multiple variables matching wildcard pattern" {
            # Arrange
            $testData = $script:TestRemoveDeviceVariableData.ByWildcard
            $pattern = "TestVar_WildcardBatch_*"

            # Act
            $result = Remove-CMASDeviceVariable -DeviceName $testData.DeviceName -VariableName $pattern -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -BeGreaterOrEqual 3

            # Verify variables are actually removed
            $remaining = Get-CMASDeviceVariable -DeviceName $testData.DeviceName | Where-Object { $_.Name -like $pattern }
            $remaining | Should -BeNullOrEmpty
        }

        It "Should return all removed variables when using wildcard" {
            # Arrange
            $testData = $script:TestRemoveDeviceVariableData.ByWildcard
            $pattern = "TestVar_WildcardBatch_*"

            # Act
            $result = Remove-CMASDeviceVariable -DeviceName $testData.DeviceName -VariableName $pattern -Force

            # Assert
            $result | ForEach-Object {
                $_.Name | Should -Match "^TestVar_WildcardBatch_"
            }
        }
    }

    Context "Error Handling" {

        It "Should throw error for non-existent device by name" {
            # Arrange
            $testData = $script:TestRemoveDeviceVariableData.NonExistentDevice

            # Act & Assert
            { Remove-CMASDeviceVariable -DeviceName $testData.DeviceName -VariableName $testData.VariableName -Force -ErrorAction Stop } |
                Should -Throw
        }

        It "Should handle non-existent variable gracefully" {
            # Arrange
            $testData = $script:TestRemoveDeviceVariableData.NonExistentVariable

            # Act & Assert
            # Should not throw, but should return nothing or warning
            $result = Remove-CMASDeviceVariable -DeviceName $testData.DeviceName -VariableName $testData.VariableName -Force -ErrorAction SilentlyContinue
            $result | Should -BeNullOrEmpty
        }

        It "Should handle invalid ResourceID" {
            # Act & Assert
            { Remove-CMASDeviceVariable -ResourceID 999999999 -VariableName "TestVar" -Force -ErrorAction Stop } |
                Should -Throw
        }
    }

    Context "Pipeline Support" {

        BeforeAll {
            # Create test variables for pipeline tests
            $testData = $script:TestRemoveDeviceVariableData.ByDeviceName
            $timestamp = Get-Date -Format 'yyyyMMddHHmmss'
            $script:PipelineTestVars = @(
                "TestVar_Pipeline_${timestamp}_01"
                "TestVar_Pipeline_${timestamp}_02"
            )

            try {
                foreach ($varName in $script:PipelineTestVars) {
                    New-CMASDeviceVariable -DeviceName $testData.DeviceName -VariableName $varName -VariableValue "ForPipeline" -ErrorAction Stop | Out-Null
                }
            }
            catch {
                Write-Warning "Failed to create pipeline test variables: $($_.Exception.Message)"
            }
        }

        It "Should accept device object from pipeline (Get-CMASDevice)" {
            # Arrange
            $testData = $script:TestRemoveDeviceVariableData.ByDeviceName
            $varName = $script:PipelineTestVars[0]

            # Act
            $result = Get-CMASDevice -DeviceName $testData.DeviceName | Remove-CMASDeviceVariable -VariableName $varName -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $varName

            # Verify removal
            $check = Get-CMASDeviceVariable -DeviceName $testData.DeviceName -VariableName $varName -ErrorAction SilentlyContinue
            $check | Should -BeNullOrEmpty
        }

        It "Should accept variable object from pipeline (Get-CMASDeviceVariable)" {
            # Arrange
            $testData = $script:TestRemoveDeviceVariableData.ByDeviceName
            $varName = $script:PipelineTestVars[1]

            # Act
            $result = Get-CMASDeviceVariable -DeviceName $testData.DeviceName -VariableName $varName | Remove-CMASDeviceVariable -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $varName

            # Verify removal
            $check = Get-CMASDeviceVariable -DeviceName $testData.DeviceName -VariableName $varName -ErrorAction SilentlyContinue
            $check | Should -BeNullOrEmpty
        }
    }

    Context "Force and Confirm Parameters" {

        BeforeEach {
            # Create test variable
            $testData = $script:TestRemoveDeviceVariableData.ByDeviceName
            $timestamp = Get-Date -Format 'yyyyMMddHHmmss'
            $script:ForceTestVar = "TestVar_Force_$timestamp"

            try {
                New-CMASDeviceVariable -DeviceName $testData.DeviceName -VariableName $script:ForceTestVar -VariableValue "ToTest" -ErrorAction Stop | Out-Null
            }
            catch {
                Write-Warning "Failed to create force test variable: $($_.Exception.Message)"
            }
        }

        It "Should remove variable when Force parameter is used" {
            # Arrange
            $testData = $script:TestRemoveDeviceVariableData.ByDeviceName

            # Act
            $result = Remove-CMASDeviceVariable -DeviceName $testData.DeviceName -VariableName $script:ForceTestVar -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty

            # Verify removal
            $check = Get-CMASDeviceVariable -DeviceName $testData.DeviceName -VariableName $script:ForceTestVar -ErrorAction SilentlyContinue
            $check | Should -BeNullOrEmpty
        }
    }
}

AfterAll {
    # Clean up any remaining test variables
    $testDevice = $script:TestRemoveDeviceVariableData.ByDeviceName.DeviceName

    try {
        # Remove any leftover test variables
        $allTestVars = @(
            $script:RemoveTestVarByName
            $script:RemoveTestVarByID
        ) + $script:RemoveWildcardVars + $script:WildcardTestVars + $script:PipelineTestVars

        foreach ($varName in $allTestVars) {
            if ($varName) {
                Remove-CMASDeviceVariable -DeviceName $testDevice -VariableName $varName -Force -ErrorAction SilentlyContinue | Out-Null
            }
        }

        # Also clean up any variables matching test patterns
        $patterns = @(
            "TestVar_Remove_*"
            "TestVar_RemoveByID_*"
            "TestVar_RemoveWildcard_*"
            "TestVar_WildcardBatch_*"
            "TestVar_Pipeline_*"
            "TestVar_Force_*"
        )

        foreach ($pattern in $patterns) {
            Remove-CMASDeviceVariable -DeviceName $testDevice -VariableName $pattern -Force -ErrorAction SilentlyContinue | Out-Null
        }
    }
    catch {
        Write-Warning "Failed to clean up test variables in AfterAll: $($_.Exception.Message)"
    }
}

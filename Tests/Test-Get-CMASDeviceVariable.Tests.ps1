# Functional Tests for Get-CMASDeviceVariable
# Tests the Get-CMASDeviceVariable function behavior and return values

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
    $script:TestGetDeviceVariableData = $script:TestData['Get-CMASDeviceVariable']

    # Ensure at least one test variable exists for the tests
    $testDevice = $script:TestGetDeviceVariableData.ByDeviceName.DeviceName
    $testVarName = "TestVar_Get_$(Get-Date -Format 'yyyyMMdd')"

    try {
        # Try to create a test variable if it doesn't exist
        $existingVar = Get-CMASDeviceVariable -DeviceName $testDevice -VariableName $testVarName -ErrorAction SilentlyContinue
        if (-not $existingVar) {
            New-CMASDeviceVariable -DeviceName $testDevice -VariableName $testVarName -VariableValue "TestValue" -ErrorAction SilentlyContinue | Out-Null
        }
    }
    catch {
        # Ignore errors - variable might already exist or device might not exist
    }
}

Describe "Get-CMASDeviceVariable Function Tests" -Tag "Integration", "DeviceVariable", "Get" {

    Context "Test Data Validation" {

        It "Should have test data defined in declarations.ps1" {
            # Assert
            $script:TestGetDeviceVariableData | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('Get-CMASDeviceVariable') | Should -Be $true
        }

        It "Should have required test data parameter sets" {
            # Assert
            $script:TestGetDeviceVariableData.ContainsKey('ByDeviceName') | Should -Be $true
            $script:TestGetDeviceVariableData.ContainsKey('ByResourceId') | Should -Be $true
            $script:TestGetDeviceVariableData.ContainsKey('ByDeviceNameAndVariableName') | Should -Be $true
        }

        It "Should output test data for verification" {
            # Output test data
            Write-Host "`n=== Test Data for Get-CMASDeviceVariable ===" -ForegroundColor Cyan
            Write-Host "ByDeviceName:" -ForegroundColor Yellow
            Write-Host "  DeviceName: $($script:TestGetDeviceVariableData.ByDeviceName.DeviceName)" -ForegroundColor White
            Write-Host "`nByResourceId:" -ForegroundColor Yellow
            Write-Host "  ResourceId: $($script:TestGetDeviceVariableData.ByResourceId.ResourceId)" -ForegroundColor White
        }
    }

    Context "Parameter Validation" {

        It "Should throw error when not connected to Admin Service" {
            # Arrange
            $savedConnection = $script:CMASConnection.SiteServer
            $script:CMASConnection.SiteServer = $null

            # Act & Assert
            { Get-CMASDeviceVariable -DeviceName "Test" } |
                Should -Throw "*No active connection*"

            # Cleanup
            $script:CMASConnection.SiteServer = $savedConnection
        }

        It "Should throw error when neither DeviceName nor ResourceID is provided" {
            # Act & Assert
            { Get-CMASDeviceVariable } |
                Should -Throw "*DeviceName*ResourceID*"
        }
    }

    Context "Get Device Variables by Device Name" {

        It "Should get all variables for a device by name" {
            # Arrange
            $testData = $script:TestGetDeviceVariableData.ByDeviceName

            # Act
            $result = Get-CMASDeviceVariable -DeviceName $testData.DeviceName

            # Assert
            $result | Should -Not -BeNullOrEmpty
            @($result).Count | Should -BeGreaterOrEqual $testData.ExpectedMinCount
            $result[0].PSObject.Properties.Name | Should -Contain 'Name'
            $result[0].PSObject.Properties.Name | Should -Contain 'Value'
            $result[0].PSObject.Properties.Name | Should -Contain 'IsMasked'
        }

        It "Should get a specific variable by device name and variable name" {
            # Arrange
            $testData = $script:TestGetDeviceVariableData.ByDeviceNameAndVariableName

            # Act
            $result = Get-CMASDeviceVariable -DeviceName $testData.DeviceName -VariableName $testData.VariableName

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result[0].Name | Should -BeLike $testData.VariableName
        }

        It "Should return empty result for device without variables" {
            # Arrange
            $testData = $script:TestGetDeviceVariableData.DeviceWithoutVariables

            # Skip if no test device specified
            if (-not $testData.DeviceName) {
                Set-ItResult -Skipped -Because "No test device without variables specified in declarations.ps1"
                return
            }

            # Act
            $result = Get-CMASDeviceVariable -DeviceName $testData.DeviceName

            # Assert
            $result | Should -BeNullOrEmpty
        }

        It "Should throw error for non-existent device" {
            # Arrange
            $testData = $script:TestGetDeviceVariableData.NonExistentDevice

            # Act & Assert
            { Get-CMASDeviceVariable -DeviceName $testData.DeviceName } |
                Should -Throw "*not found*"
        }
    }

    Context "Get Device Variables by ResourceID" {

        It "Should get all variables for a device by ResourceID" {
            # Arrange
            $testData = $script:TestGetDeviceVariableData.ByResourceId

            # Act
            $result = Get-CMASDeviceVariable -ResourceID $testData.ResourceId

            # Assert
            $result | Should -Not -BeNullOrEmpty
            @($result).Count | Should -BeGreaterOrEqual $testData.ExpectedMinCount
        }

        It "Should get a specific variable by ResourceID and variable name" {
            # Arrange
            $testData = $script:TestGetDeviceVariableData.ByResourceIdAndVariableName

            # Act
            $result = Get-CMASDeviceVariable -ResourceID $testData.ResourceId -VariableName $testData.VariableName

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result[0].Name | Should -BeLike $testData.VariableName
        }
    }

    Context "Variable Filtering" {

        It "Should support wildcard patterns in variable name" {
            # Arrange
            $testData = $script:TestGetDeviceVariableData.ByDeviceNameAndVariableName

            # Act
            $result = Get-CMASDeviceVariable -DeviceName $testData.DeviceName -VariableName $testData.VariableName

            # Assert
            $result | Should -Not -BeNullOrEmpty
            # All returned variables should match the pattern
            foreach ($var in $result) {
                $var.Name | Should -BeLike $testData.VariableName
            }
        }

        It "Should return empty for non-existent variable name" {
            # Arrange
            $testData = $script:TestGetDeviceVariableData.NonExistentVariable

            # Act
            $result = Get-CMASDeviceVariable -DeviceName $testData.DeviceName -VariableName $testData.VariableName

            # Assert
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Output Properties" {

        It "Should include device information in output" {
            # Arrange
            $testData = $script:TestGetDeviceVariableData.ByDeviceName

            # Act
            $result = Get-CMASDeviceVariable -DeviceName $testData.DeviceName

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result[0].PSObject.Properties.Name | Should -Contain 'DeviceName'
            $result[0].PSObject.Properties.Name | Should -Contain 'ResourceID'
            $result[0].DeviceName | Should -Be $testData.DeviceName
        }

        It "Should not include OData metadata in output" {
            # Arrange
            $testData = $script:TestGetDeviceVariableData.ByDeviceName

            # Act
            $result = Get-CMASDeviceVariable -DeviceName $testData.DeviceName

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result[0].PSObject.Properties.Name | Should -Not -Contain '@odata.type'
            $result[0].PSObject.Properties.Name | Should -Not -Contain '@odata.context'
        }

        It "Should correctly identify masked variables" {
            # Arrange - First ensure a masked variable exists
            $testDevice = $script:TestGetDeviceVariableData.ByDeviceName.DeviceName
            $maskedVarName = "TestVar_Masked_Get_$(Get-Date -Format 'HHmmss')"

            try {
                New-CMASDeviceVariable -DeviceName $testDevice -VariableName $maskedVarName -VariableValue "Secret" -IsMasked -ErrorAction SilentlyContinue | Out-Null
            }
            catch {
                # Variable might already exist
            }

            # Act
            $result = Get-CMASDeviceVariable -DeviceName $testDevice -VariableName $maskedVarName

            # Assert
            if ($result) {
                $result.IsMasked | Should -Be $true
                # Masked variables have their values hidden (null or empty)
                # This is expected behavior for sensitive variables
                $result.PSObject.Properties.Name | Should -Contain 'Value'
            }
            else {
                Set-ItResult -Skipped -Because "Could not create masked variable for testing"
            }
        }
    }

    Context "Multiple Device Support" {

        It "Should handle devices with many variables efficiently" {
            # Arrange
            $testData = $script:TestGetDeviceVariableData.ByDeviceName

            # Act
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            $result = Get-CMASDeviceVariable -DeviceName $testData.DeviceName
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
    Write-Verbose "Get-CMASDeviceVariable tests completed"
}

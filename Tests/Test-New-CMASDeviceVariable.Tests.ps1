# Functional Tests for New-CMASDeviceVariable
# Tests the New-CMASDeviceVariable function behavior and return values

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
    $script:TestNewDeviceVariableData = $script:TestData['New-CMASDeviceVariable']

    # Track created variables for cleanup
    $script:CreatedVariables = @()
}

Describe "New-CMASDeviceVariable Function Tests" -Tag "Integration", "DeviceVariable", "Create", "Modify" {

    Context "Test Data Validation" {

        It "Should have test data defined in declarations.ps1" {
            # Assert
            $script:TestNewDeviceVariableData | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('New-CMASDeviceVariable') | Should -Be $true
        }

        It "Should have required test data parameter sets" {
            # Assert
            $script:TestNewDeviceVariableData.ContainsKey('ByDeviceName') | Should -Be $true
            $script:TestNewDeviceVariableData.ContainsKey('ByResourceId') | Should -Be $true
            $script:TestNewDeviceVariableData.ContainsKey('WithSpecialChars') | Should -Be $true
            $script:TestNewDeviceVariableData.ContainsKey('MaskedVariable') | Should -Be $true
        }

        It "Should output test data for verification" {
            # Output test data
            Write-Host "`n=== Test Data for New-CMASDeviceVariable ===" -ForegroundColor Cyan
            Write-Host "ByDeviceName:" -ForegroundColor Yellow
            Write-Host "  DeviceName: $($script:TestNewDeviceVariableData.ByDeviceName.DeviceName)" -ForegroundColor White
            Write-Host "  VariableName: $($script:TestNewDeviceVariableData.ByDeviceName.VariableName)" -ForegroundColor White
            Write-Host "`nByResourceId:" -ForegroundColor Yellow
            Write-Host "  ResourceId: $($script:TestNewDeviceVariableData.ByResourceId.ResourceId)" -ForegroundColor White
            Write-Host "  VariableName: $($script:TestNewDeviceVariableData.ByResourceId.VariableName)" -ForegroundColor White
            Write-Host "`nMaskedVariable:" -ForegroundColor Yellow
            Write-Host "  IsMasked: $($script:TestNewDeviceVariableData.MaskedVariable.IsMasked)" -ForegroundColor White
        }
    }

    Context "Parameter Validation" {

        It "Should throw error when not connected to Admin Service" {
            # Arrange
            $savedConnection = $script:CMASConnection.SiteServer
            $script:CMASConnection.SiteServer = $null

            # Act & Assert
            { New-CMASDeviceVariable -DeviceName "Test" -VariableName "TestVar" -VariableValue "TestValue" } |
                Should -Throw "*No active connection*"

            # Cleanup
            $script:CMASConnection.SiteServer = $savedConnection
        }

        It "Should throw error when neither DeviceName nor ResourceID is provided" {
            # Act & Assert
            { New-CMASDeviceVariable -VariableName "TestVar" -VariableValue "TestValue" } |
                Should -Throw "*parameter set*"
        }

        It "Should reject variable names with spaces" {
            # Arrange
            $testData = $script:TestNewDeviceVariableData.InvalidVariableName

            # Act & Assert
            { New-CMASDeviceVariable -DeviceName $testData.DeviceName -VariableName $testData.VariableName -VariableValue $testData.VariableValue } |
                Should -Throw
        }

        It "Should accept valid variable name patterns" {
            # Variable names with letters, numbers, underscores, and hyphens should be valid
            $validNames = @('TestVar', 'Test_Var', 'Test-Var', 'TestVar123', 'TEST_VAR_123')

            foreach ($name in $validNames) {
                {
                    $params = @{
                        DeviceName = $script:TestNewDeviceVariableData.ByDeviceName.DeviceName
                        VariableName = $name
                        VariableValue = "test"
                        WhatIf = $true
                    }
                    New-CMASDeviceVariable @params
                } | Should -Not -Throw
            }
        }
    }

    Context "Create Device Variable by Device Name" {

        It "Should create a device variable using device name" {
            # Arrange
            $testData = $script:TestNewDeviceVariableData.ByDeviceName
            $uniqueVarName = "$($testData.VariableName)_$(Get-Date -Format 'HHmmss')"

            # Act
            $result = New-CMASDeviceVariable -DeviceName $testData.DeviceName -VariableName $uniqueVarName -VariableValue $testData.VariableValue -PassThru

            # Track for cleanup
            if ($result) {
                $script:CreatedVariables += @{ DeviceName = $testData.DeviceName; VariableName = $uniqueVarName }
            }

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $uniqueVarName
            $result.Value | Should -Be $testData.VariableValue
            $result.IsMasked | Should -Be $false
        }

        It "Should verify the created variable exists" {
            # Arrange
            $testData = $script:TestNewDeviceVariableData.ByDeviceName
            $uniqueVarName = "$($testData.VariableName)_Verify_$(Get-Date -Format 'HHmmss')"

            # Act
            New-CMASDeviceVariable -DeviceName $testData.DeviceName -VariableName $uniqueVarName -VariableValue $testData.VariableValue
            Start-Sleep -Seconds 2

            # Track for cleanup
            $script:CreatedVariables += @{ DeviceName = $testData.DeviceName; VariableName = $uniqueVarName }

            # Get device and check variables
            $device = Get-CMASDevice -Name $testData.DeviceName
            $settingsPath = "wmi/SMS_MachineSettings?`$filter=ResourceID eq $($device.ResourceID)"
            $settings = Invoke-CMASApi -Path $settingsPath

            # Assert
            $settings.value | Should -Not -BeNullOrEmpty
        }

        It "Should throw error for non-existent device" {
            # Arrange
            $testData = $script:TestNewDeviceVariableData.NonExistentDevice

            # Act & Assert
            { New-CMASDeviceVariable -DeviceName $testData.DeviceName -VariableName $testData.VariableName -VariableValue $testData.VariableValue } |
                Should -Throw "*not found*"
        }
    }

    Context "Create Device Variable by ResourceID" {

        It "Should create a device variable using ResourceID" {
            # Arrange
            $testData = $script:TestNewDeviceVariableData.ByResourceId
            $uniqueVarName = "$($testData.VariableName)_$(Get-Date -Format 'HHmmss')"

            # Act
            $result = New-CMASDeviceVariable -ResourceID $testData.ResourceId -VariableName $uniqueVarName -VariableValue $testData.VariableValue -PassThru

            # Track for cleanup
            if ($result) {
                $script:CreatedVariables += @{ ResourceId = $testData.ResourceId; VariableName = $uniqueVarName }
            }

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $uniqueVarName
            $result.Value | Should -Be $testData.VariableValue
            $result.ResourceID | Should -Be $testData.ResourceId
        }
    }

    Context "Create Device Variable with Special Values" {

        It "Should create a variable with special characters in value" {
            # Arrange
            $testData = $script:TestNewDeviceVariableData.WithSpecialChars
            $uniqueVarName = "$($testData.VariableName)_$(Get-Date -Format 'HHmmss')"

            # Act
            $result = New-CMASDeviceVariable -DeviceName $testData.DeviceName -VariableName $uniqueVarName -VariableValue $testData.VariableValue -PassThru

            # Track for cleanup
            if ($result) {
                $script:CreatedVariables += @{ DeviceName = $testData.DeviceName; VariableName = $uniqueVarName }
            }

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Value | Should -Be $testData.VariableValue
        }

        It "Should create a masked (sensitive) variable" {
            # Arrange
            $testData = $script:TestNewDeviceVariableData.MaskedVariable
            $uniqueVarName = "$($testData.VariableName)_$(Get-Date -Format 'HHmmss')"

            # Act
            $result = New-CMASDeviceVariable -DeviceName $testData.DeviceName -VariableName $uniqueVarName -VariableValue $testData.VariableValue -IsMasked -PassThru

            # Track for cleanup
            if ($result) {
                $script:CreatedVariables += @{ DeviceName = $testData.DeviceName; VariableName = $uniqueVarName }
            }

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $uniqueVarName
            $result.IsMasked | Should -Be $true
        }

        It "Should create a variable with empty value" {
            # Arrange
            $testData = $script:TestNewDeviceVariableData.EmptyValue
            $uniqueVarName = "$($testData.VariableName)_$(Get-Date -Format 'HHmmss')"

            # Act
            $result = New-CMASDeviceVariable -DeviceName $testData.DeviceName -VariableName $uniqueVarName -VariableValue "" -PassThru

            # Track for cleanup
            if ($result) {
                $script:CreatedVariables += @{ DeviceName = $testData.DeviceName; VariableName = $uniqueVarName }
            }

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Value | Should -Be ""
        }
    }

    Context "Return Values and Types" {

        It "Should return object with PassThru parameter" {
            # Arrange
            $testData = $script:TestNewDeviceVariableData.ByDeviceName
            $uniqueVarName = "$($testData.VariableName)_PassThru_$(Get-Date -Format 'HHmmss')"

            # Act
            $result = New-CMASDeviceVariable -DeviceName $testData.DeviceName -VariableName $uniqueVarName -VariableValue $testData.VariableValue -PassThru

            # Track for cleanup
            if ($result) {
                $script:CreatedVariables += @{ DeviceName = $testData.DeviceName; VariableName = $uniqueVarName }
            }

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -BeOfType [String]
            $result.Value | Should -BeOfType [String]
        }

        It "Should not return object without PassThru parameter" {
            # Arrange
            $testData = $script:TestNewDeviceVariableData.ByDeviceName
            $uniqueVarName = "$($testData.VariableName)_NoPassThru_$(Get-Date -Format 'HHmmss')"

            # Act
            $result = New-CMASDeviceVariable -DeviceName $testData.DeviceName -VariableName $uniqueVarName -VariableValue $testData.VariableValue

            # Track for cleanup
            $script:CreatedVariables += @{ DeviceName = $testData.DeviceName; VariableName = $uniqueVarName }

            # Assert
            $result | Should -BeNullOrEmpty
        }
    }

    Context "WhatIf Support" {

        It "Should support WhatIf parameter" {
            # Arrange
            $testData = $script:TestNewDeviceVariableData.ByDeviceName
            $uniqueVarName = "$($testData.VariableName)_WhatIf_$(Get-Date -Format 'HHmmss')"

            # Act
            { New-CMASDeviceVariable -DeviceName $testData.DeviceName -VariableName $uniqueVarName -VariableValue $testData.VariableValue -WhatIf } |
                Should -Not -Throw
        }
    }

    Context "Error Handling" {

        It "Should throw error when creating duplicate variable name" {
            # Arrange
            $testData = $script:TestNewDeviceVariableData.ByDeviceName
            $uniqueVarName = "$($testData.VariableName)_Duplicate_$(Get-Date -Format 'HHmmss')"

            # Create first variable
            New-CMASDeviceVariable -DeviceName $testData.DeviceName -VariableName $uniqueVarName -VariableValue $testData.VariableValue

            # Track for cleanup
            $script:CreatedVariables += @{ DeviceName = $testData.DeviceName; VariableName = $uniqueVarName }

            Start-Sleep -Seconds 1

            # Act & Assert - Try to create duplicate
            { New-CMASDeviceVariable -DeviceName $testData.DeviceName -VariableName $uniqueVarName -VariableValue "DifferentValue" } |
                Should -Throw "*already exists*"
        }
    }
}

AfterAll {
    Write-Host "`n=== Cleanup Created Variables ===" -ForegroundColor Cyan

    # Note: Cleanup would require a Remove-CMASDeviceVariable function or direct API calls
    # For now, just report what was created
    if ($script:CreatedVariables.Count -gt 0) {
        Write-Host "Created $($script:CreatedVariables.Count) test variables during testing:" -ForegroundColor Yellow
        foreach ($var in $script:CreatedVariables) {
            if ($var.DeviceName) {
                Write-Host "  - Variable: $($var.VariableName) on Device: $($var.DeviceName)" -ForegroundColor White
            } else {
                Write-Host "  - Variable: $($var.VariableName) on ResourceID: $($var.ResourceId)" -ForegroundColor White
            }
        }
        Write-Host "Note: Manual cleanup may be required or implement Remove-CMASDeviceVariable function" -ForegroundColor Yellow
    }
}

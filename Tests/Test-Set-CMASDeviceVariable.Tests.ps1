# Functional Tests for Set-CMASDeviceVariable
# Tests the Set-CMASDeviceVariable function behavior and return values

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
    $script:TestSetDeviceVariableData = $script:TestData['Set-CMASDeviceVariable']

    # Track created variables for cleanup
    $script:TestVariables = @()
}

Describe "Set-CMASDeviceVariable Function Tests" -Tag "Integration", "DeviceVariable", "Modify" {

    Context "Test Data Validation" {

        It "Should have test data defined in declarations.ps1" {
            # Assert
            $script:TestSetDeviceVariableData | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('Set-CMASDeviceVariable') | Should -Be $true
        }

        It "Should have required test data parameter sets" {
            # Assert
            $script:TestSetDeviceVariableData.ContainsKey('ByDeviceName') | Should -Be $true
            $script:TestSetDeviceVariableData.ContainsKey('ByResourceId') | Should -Be $true
            $script:TestSetDeviceVariableData.ContainsKey('ChangeMaskedState') | Should -Be $true
            $script:TestSetDeviceVariableData.ContainsKey('EmptyValue') | Should -Be $true
        }

        It "Should output test data for verification" {
            # Output test data
            Write-Host "`n=== Test Data for Set-CMASDeviceVariable ===" -ForegroundColor Cyan
            Write-Host "ByDeviceName:" -ForegroundColor Yellow
            Write-Host "  DeviceName: $($script:TestSetDeviceVariableData.ByDeviceName.DeviceName)" -ForegroundColor White
            Write-Host "  VariableName: $($script:TestSetDeviceVariableData.ByDeviceName.VariableName)" -ForegroundColor White
            Write-Host "`nByResourceId:" -ForegroundColor Yellow
            Write-Host "  ResourceId: $($script:TestSetDeviceVariableData.ByResourceId.ResourceId)" -ForegroundColor White
            Write-Host "  VariableName: $($script:TestSetDeviceVariableData.ByResourceId.VariableName)" -ForegroundColor White
        }
    }

    Context "Parameter Validation" {

        It "Should throw error when not connected to Admin Service" {
            # Arrange
            $savedConnection = $script:CMASConnection.SiteServer
            $script:CMASConnection.SiteServer = $null

            # Act & Assert
            { Set-CMASDeviceVariable -DeviceName "Test" -VariableName "TestVar" -VariableValue "TestValue" } |
                Should -Throw "*No active connection*"

            # Cleanup
            $script:CMASConnection.SiteServer = $savedConnection
        }

        It "Should throw error when neither DeviceName nor ResourceID is provided" {
            # Act & Assert
            { Set-CMASDeviceVariable -VariableName "TestVar" -VariableValue "TestValue" } |
                Should -Throw "*Either DeviceName or ResourceID must be specified*"
        }

        It "Should throw error when both IsMasked and IsNotMasked are specified" {
            # Arrange
            $testData = $script:TestSetDeviceVariableData.ByDeviceName

            # Act & Assert
            { Set-CMASDeviceVariable -DeviceName $testData.DeviceName -VariableName "TestVar" -VariableValue "Test" -IsMasked -IsNotMasked } |
                Should -Throw "*Cannot specify both*"
        }
    }

    Context "Modify Device Variable by Device Name" {

        It "Should modify a device variable value using device name" {
            # Arrange
            $testData = $script:TestSetDeviceVariableData.ByDeviceName
            $uniqueVarName = "$($testData.VariableName)_$(Get-Date -Format 'HHmmss')"

            # Create the variable first
            New-CMASDeviceVariable -DeviceName $testData.DeviceName -VariableName $uniqueVarName -VariableValue $testData.OriginalValue | Out-Null
            Start-Sleep -Seconds 2

            # Track for cleanup
            $script:TestVariables += @{ DeviceName = $testData.DeviceName; VariableName = $uniqueVarName }

            # Act
            $result = Set-CMASDeviceVariable -DeviceName $testData.DeviceName -VariableName $uniqueVarName -VariableValue $testData.NewValue -PassThru

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $uniqueVarName
            $result.Value | Should -Be $testData.NewValue
            $result.IsMasked | Should -Be $false
        }

        It "Should verify the modified variable value" {
            # Arrange
            $testData = $script:TestSetDeviceVariableData.ByDeviceName
            $uniqueVarName = "$($testData.VariableName)_Verify_$(Get-Date -Format 'HHmmss')"

            # Create the variable first
            New-CMASDeviceVariable -DeviceName $testData.DeviceName -VariableName $uniqueVarName -VariableValue $testData.OriginalValue | Out-Null
            Start-Sleep -Seconds 2

            # Track for cleanup
            $script:TestVariables += @{ DeviceName = $testData.DeviceName; VariableName = $uniqueVarName }

            # Modify the variable
            Set-CMASDeviceVariable -DeviceName $testData.DeviceName -VariableName $uniqueVarName -VariableValue $testData.NewValue
            Start-Sleep -Seconds 2

            # Act - Get the variable
            $retrievedVar = Get-CMASDeviceVariable -DeviceName $testData.DeviceName -VariableName $uniqueVarName

            # Assert
            $retrievedVar | Should -Not -BeNullOrEmpty
            $retrievedVar.Value | Should -Be $testData.NewValue
        }

        It "Should throw error for non-existent device" {
            # Arrange
            $testData = $script:TestSetDeviceVariableData.NonExistentDevice

            # Act & Assert
            { Set-CMASDeviceVariable -DeviceName $testData.DeviceName -VariableName $testData.VariableName -VariableValue $testData.NewValue } |
                Should -Throw "*not found*"
        }

        It "Should throw error for non-existent variable" {
            # Arrange
            $testData = $script:TestSetDeviceVariableData.NonExistentVariable

            # Act & Assert
            { Set-CMASDeviceVariable -DeviceName $testData.DeviceName -VariableName $testData.VariableName -VariableValue $testData.NewValue } |
                Should -Throw "*not found*"
        }
    }

    Context "Modify Device Variable by ResourceID" {

        It "Should modify a device variable using ResourceID" {
            # Arrange
            $testData = $script:TestSetDeviceVariableData.ByResourceId
            $uniqueVarName = "$($testData.VariableName)_$(Get-Date -Format 'HHmmss')"

            # Create the variable first
            New-CMASDeviceVariable -ResourceID $testData.ResourceId -VariableName $uniqueVarName -VariableValue $testData.OriginalValue | Out-Null
            Start-Sleep -Seconds 2

            # Track for cleanup
            $script:TestVariables += @{ ResourceId = $testData.ResourceId; VariableName = $uniqueVarName }

            # Act
            $result = Set-CMASDeviceVariable -ResourceID $testData.ResourceId -VariableName $uniqueVarName -VariableValue $testData.NewValue -PassThru

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $uniqueVarName
            $result.Value | Should -Be $testData.NewValue
            $result.ResourceID | Should -Be $testData.ResourceId
        }
    }

    Context "Modify Device Variable Masked State" {

        It "Should mark a variable as masked" {
            # Arrange
            $testData = $script:TestSetDeviceVariableData.ChangeMaskedState
            $uniqueVarName = "$($testData.VariableName)_$(Get-Date -Format 'HHmmss')"

            # Create the variable first (not masked)
            New-CMASDeviceVariable -DeviceName $testData.DeviceName -VariableName $uniqueVarName -VariableValue $testData.OriginalValue | Out-Null
            Start-Sleep -Seconds 2

            # Track for cleanup
            $script:TestVariables += @{ DeviceName = $testData.DeviceName; VariableName = $uniqueVarName }

            # Act - Modify to masked
            $result = Set-CMASDeviceVariable -DeviceName $testData.DeviceName -VariableName $uniqueVarName -VariableValue $testData.NewValue -IsMasked -PassThru

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $uniqueVarName
            $result.IsMasked | Should -Be $true
        }

        It "Should unmask a masked variable" {
            # Arrange
            $testData = $script:TestSetDeviceVariableData.UnmaskVariable
            $uniqueVarName = "$($testData.VariableName)_$(Get-Date -Format 'HHmmss')"

            # Create the variable first (masked)
            New-CMASDeviceVariable -DeviceName $testData.DeviceName -VariableName $uniqueVarName -VariableValue $testData.OriginalValue -IsMasked | Out-Null
            Start-Sleep -Seconds 2

            # Track for cleanup
            $script:TestVariables += @{ DeviceName = $testData.DeviceName; VariableName = $uniqueVarName }

            # Act - Modify to not masked
            $result = Set-CMASDeviceVariable -DeviceName $testData.DeviceName -VariableName $uniqueVarName -VariableValue $testData.NewValue -IsNotMasked -PassThru

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
            $testData = $script:TestSetDeviceVariableData.EmptyValue
            $uniqueVarName = "$($testData.VariableName)_$(Get-Date -Format 'HHmmss')"

            # Create the variable first
            New-CMASDeviceVariable -DeviceName $testData.DeviceName -VariableName $uniqueVarName -VariableValue $testData.OriginalValue | Out-Null
            Start-Sleep -Seconds 2

            # Track for cleanup
            $script:TestVariables += @{ DeviceName = $testData.DeviceName; VariableName = $uniqueVarName }

            # Act
            $result = Set-CMASDeviceVariable -DeviceName $testData.DeviceName -VariableName $uniqueVarName -VariableValue "" -PassThru

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Value | Should -Be ""
        }
    }

    Context "Return Values and Types" {

        It "Should return object with PassThru parameter" {
            # Arrange
            $testData = $script:TestSetDeviceVariableData.ByDeviceName
            $uniqueVarName = "$($testData.VariableName)_PassThru_$(Get-Date -Format 'HHmmss')"

            # Create the variable first
            New-CMASDeviceVariable -DeviceName $testData.DeviceName -VariableName $uniqueVarName -VariableValue $testData.OriginalValue | Out-Null
            Start-Sleep -Seconds 2

            # Track for cleanup
            $script:TestVariables += @{ DeviceName = $testData.DeviceName; VariableName = $uniqueVarName }

            # Act
            $result = Set-CMASDeviceVariable -DeviceName $testData.DeviceName -VariableName $uniqueVarName -VariableValue $testData.NewValue -PassThru

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Not -BeNullOrEmpty
            $result.Value | Should -Not -BeNullOrEmpty
            $result | Should -BeOfType [PSCustomObject]
        }

        It "Should not return object without PassThru parameter" {
            # Arrange
            $testData = $script:TestSetDeviceVariableData.ByDeviceName
            $uniqueVarName = "$($testData.VariableName)_NoPassThru_$(Get-Date -Format 'HHmmss')"

            # Create the variable first
            New-CMASDeviceVariable -DeviceName $testData.DeviceName -VariableName $uniqueVarName -VariableValue $testData.OriginalValue | Out-Null
            Start-Sleep -Seconds 2

            # Track for cleanup
            $script:TestVariables += @{ DeviceName = $testData.DeviceName; VariableName = $uniqueVarName }

            # Act
            $result = Set-CMASDeviceVariable -DeviceName $testData.DeviceName -VariableName $uniqueVarName -VariableValue $testData.NewValue

            # Assert
            $result | Should -BeNullOrEmpty
        }

        It "Should have required properties on returned object" {
            # Arrange
            $testData = $script:TestSetDeviceVariableData.ByDeviceName
            $uniqueVarName = "$($testData.VariableName)_Props_$(Get-Date -Format 'HHmmss')"

            # Create the variable first
            New-CMASDeviceVariable -DeviceName $testData.DeviceName -VariableName $uniqueVarName -VariableValue $testData.OriginalValue | Out-Null
            Start-Sleep -Seconds 2

            # Track for cleanup
            $script:TestVariables += @{ DeviceName = $testData.DeviceName; VariableName = $uniqueVarName }

            # Act
            $result = Set-CMASDeviceVariable -DeviceName $testData.DeviceName -VariableName $uniqueVarName -VariableValue $testData.NewValue -PassThru

            # Assert
            $result.PSObject.Properties.Name | Should -Contain 'Name'
            $result.PSObject.Properties.Name | Should -Contain 'Value'
            $result.PSObject.Properties.Name | Should -Contain 'IsMasked'
            $result.PSObject.Properties.Name | Should -Contain 'ResourceID'
            $result.PSObject.Properties.Name | Should -Contain 'DeviceName'
        }
    }

    Context "WhatIf and Confirm Support" {

        It "Should support -WhatIf" {
            # Arrange
            $testData = $script:TestSetDeviceVariableData.ByDeviceName
            $uniqueVarName = "$($testData.VariableName)_WhatIf_$(Get-Date -Format 'HHmmss')"

            # Create the variable first
            New-CMASDeviceVariable -DeviceName $testData.DeviceName -VariableName $uniqueVarName -VariableValue $testData.OriginalValue | Out-Null
            Start-Sleep -Seconds 2

            # Track for cleanup
            $script:TestVariables += @{ DeviceName = $testData.DeviceName; VariableName = $uniqueVarName }

            # Act
            { Set-CMASDeviceVariable -DeviceName $testData.DeviceName -VariableName $uniqueVarName -VariableValue $testData.NewValue -WhatIf } |
                Should -Not -Throw

            # Verify variable was NOT changed
            Start-Sleep -Seconds 2
            $checkVar = Get-CMASDeviceVariable -DeviceName $testData.DeviceName -VariableName $uniqueVarName
            $checkVar.Value | Should -Be $testData.OriginalValue
        }
    }

    Context "Pipeline Support" {

        It "Should accept pipeline input from Get-CMASDeviceVariable" {
            # Arrange
            $testData = $script:TestSetDeviceVariableData.ByDeviceName
            $uniqueVarName = "$($testData.VariableName)_Pipeline_$(Get-Date -Format 'HHmmss')"

            # Create the variable first
            New-CMASDeviceVariable -DeviceName $testData.DeviceName -VariableName $uniqueVarName -VariableValue $testData.OriginalValue | Out-Null
            Start-Sleep -Seconds 2

            # Track for cleanup
            $script:TestVariables += @{ DeviceName = $testData.DeviceName; VariableName = $uniqueVarName }

            # Act - Use pipeline
            $result = Get-CMASDeviceVariable -DeviceName $testData.DeviceName -VariableName $uniqueVarName |
                Set-CMASDeviceVariable -VariableValue $testData.NewValue -PassThru

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Value | Should -Be $testData.NewValue
        }
    }
}

AfterAll {
    # Cleanup: Remove test variables
    Write-Host "`nCleaning up test variables..." -ForegroundColor Cyan

    foreach ($var in $script:TestVariables) {
        try {
            Write-Verbose "Removing variable: $($var.VariableName)"
            if ($var.DeviceName) {
                Remove-CMASDeviceVariable -DeviceName $var.DeviceName -VariableName $var.VariableName -Force -ErrorAction SilentlyContinue -Confirm:$false
            }
            elseif ($var.ResourceId) {
                Remove-CMASDeviceVariable -ResourceID $var.ResourceId -VariableName $var.VariableName -Force -ErrorAction SilentlyContinue -Confirm:$false
            }
        }
        catch {
            Write-Warning "Failed to remove test variable: $($var.VariableName)"
        }
    }

    Write-Host "Test cleanup complete." -ForegroundColor Green
}

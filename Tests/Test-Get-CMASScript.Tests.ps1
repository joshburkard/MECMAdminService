# Functional Tests for Get-CMASScript
# Tests the Get-CMASScript function behavior and return values

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
    $script:TestScriptData = $script:TestData['Get-CMASScript']
}

Describe "Get-CMASScript Function Tests" -Tag "Integration", "Script" {

    Context "Test Data Validation" {

        It "Should have test data defined in declarations.ps1" {
            # Assert
            $script:TestScriptData | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('Get-CMASScript') | Should -Be $true
        }

        It "Should have required test data parameter sets" {
            # Assert
            $script:TestScriptData.ContainsKey('ByName') | Should -Be $true
            $script:TestScriptData.ContainsKey('ByGuid') | Should -Be $true
            $script:TestScriptData.ContainsKey('NonExistent') | Should -Be $true
            $script:TestScriptData.ContainsKey('All') | Should -Be $true
        }

        It "Should output test data for verification" {
            # Output test data
            Write-Host "`n=== Test Data for Get-CMASScript ===" -ForegroundColor Cyan
            Write-Host "ByName:" -ForegroundColor Yellow
            Write-Host "  ScriptName: $($script:TestScriptData.ByName.ScriptName)" -ForegroundColor White
            Write-Host "  ExpectedCount: $($script:TestScriptData.ByName.ExpectedCount)" -ForegroundColor White

            Write-Host "ByGuid:" -ForegroundColor Yellow
            Write-Host "  ScriptGuid: $($script:TestScriptData.ByGuid.ScriptGuid)" -ForegroundColor White
            Write-Host "  ExpectedCount: $($script:TestScriptData.ByGuid.ExpectedCount)" -ForegroundColor White

            Write-Host "NonExistent:" -ForegroundColor Yellow
            Write-Host "  ScriptName: $($script:TestScriptData.NonExistent.ScriptName)" -ForegroundColor White
            Write-Host "  ExpectedCount: $($script:TestScriptData.NonExistent.ExpectedCount)" -ForegroundColor White

            Write-Host "All:" -ForegroundColor Yellow
            Write-Host "  ExpectedMinCount: $($script:TestScriptData.All.ExpectedMinCount)" -ForegroundColor White
            Write-Host "============================================================`n" -ForegroundColor Cyan

            # This test always passes, it's just for output
            $true | Should -Be $true
        }
    }

    Context "Script Retrieval by Name" {

        It "Should return script when valid name is provided" -Skip:($script:TestScriptName -eq "Test-Script") {
            # Arrange & Act
            $result = Get-CMASScript -Name $script:TestScriptName

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.ScriptName | Should -Be $script:TestScriptName
        }

        It "Should return script with expected properties" -Skip:($script:TestScriptName -eq "Test-Script") {
            # Arrange & Act
            $result = Get-CMASScript -Name $script:TestScriptName

            # Assert
            $result | Should -Not -BeNullOrEmpty
            Assert-PropertyExists -Object $result -PropertyName "ScriptName"
            Assert-PropertyExists -Object $result -PropertyName "ScriptGUID"
            Assert-PropertyExists -Object $result -PropertyName "Script"
        }

        It "Should exclude WMI and OData metadata properties" -Skip:($script:TestScriptName -eq "Test-Script") {
            # Arrange & Act
            $result = Get-CMASScript -Name $script:TestScriptName

            # Assert
            $result | Should -Not -BeNullOrEmpty
            Assert-NoMetadataProperties -Object $result
        }

        It "Should return null or empty when script doesn't exist" {
            # Arrange & Act
            $result = Get-CMASScript -Name "NonExistentScript-XYZ123"

            # Assert
            $result | Should -BeNullOrEmpty
        }

        It "Should return valid GUID format for ScriptGUID" -Skip:($script:TestScriptName -eq "Test-Script") {
            # Arrange & Act
            $result = Get-CMASScript -Name $script:TestScriptName

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.ScriptGUID | Should -Match "^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$"
        }
    }

    Context "Query All Scripts" {

        It "Should return multiple scripts when no filter is specified" {
            # Arrange & Act
            $result = Get-CMASScript

            # Assert
            $result | Should -Not -BeNullOrEmpty
            @($result).Count | Should -BeGreaterThan 0
        }

        It "Should return scripts with consistent properties" {
            # Arrange & Act
            $result = Get-CMASScript | Select-Object -First 1

            # Assert
            $result | Should -Not -BeNullOrEmpty
            Assert-PropertyExists -Object $result -PropertyName "ScriptName"
            Assert-PropertyExists -Object $result -PropertyName "ScriptGUID"
        }

        It "Should return Script content as base64 encoded string" {
            # Arrange & Act
            $result = Get-CMASScript | Where-Object { $_.Script } | Select-Object -First 1

            # Assert
            if($result){
                $result.Script | Should -BeOfType [string]
                # Base64 strings have length divisible by 4 (with padding)
                $result.Script.Length % 4 | Should -Be 0
            }
        }
    }

    Context "Error Handling" {

        It "Should handle API errors gracefully" {
            # Arrange - Use invalid characters
            $invalidName = "Script`$`$Invalid"

            # Act & Assert
            { Get-CMASScript -Name $invalidName -ErrorAction SilentlyContinue } | Should -Not -Throw
        }
    }
}

Describe "Get-CMASScript Parameter Validation" -Tag "Unit" {

    Context "Parameter Metadata" {

        It "Should accept string for Name parameter" {
            # Get the command metadata
            $command = Get-Command Get-CMASScript
            $param = $command.Parameters['Name']

            # Assert
            $param.ParameterType.Name | Should -Be "String"
        }

        It "Should have Name parameter as optional" {
            # Get the command metadata
            $command = Get-Command Get-CMASScript

            # Assert
            $command.Parameters['Name'].Attributes.Mandatory | Should -Not -Contain $true
        }
    }
}

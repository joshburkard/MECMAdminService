# Functional Tests for Connect-CMAS
# Tests the Connect-CMAS function behavior and return values

BeforeAll {
    # Load test declarations
    . (Join-Path $PSScriptRoot "declarations.ps1")

    # Load all functions
    $CodePath = Join-Path (Get-Item $PSScriptRoot).Parent.FullName "Code"
    Get-ChildItem -Path (Join-Path $CodePath "Private") -Filter "*.ps1" | ForEach-Object { . $_.FullName }
    Get-ChildItem -Path (Join-Path $CodePath "Public") -Filter "*.ps1" | ForEach-Object { . $_.FullName }

    # Get test data for this function
    $script:TestConnectData = $script:TestData['Connect-CMAS']
}

Describe "Connect-CMAS Function Tests" -Tag "Integration", "Connection" {

    Context "Test Data Validation" {

        It "Should have test data defined in declarations.ps1" {
            # Assert
            $script:TestConnectData | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('Connect-CMAS') | Should -Be $true
        }

        It "Should have required test data parameter sets" {
            # Assert
            $script:TestConnectData.ContainsKey('Valid') | Should -Be $true
            $script:TestConnectData.ContainsKey('Invalid') | Should -Be $true
        }

        It "Should output test data for verification" {
            # Output test data
            Write-Host "`n=== Test Data for Connect-CMAS ===" -ForegroundColor Cyan
            Write-Host "Valid:" -ForegroundColor Yellow
            Write-Host "  SiteServer: $($script:TestConnectData.Valid.SiteServer)" -ForegroundColor White
            Write-Host "  SkipCertificateCheck: $($script:TestConnectData.Valid.SkipCertificateCheck)" -ForegroundColor White
            Write-Host "  Credential: $(if($script:TestConnectData.Valid.Credential){'Configured'}else{'Not Configured'})" -ForegroundColor White

            Write-Host "Invalid:" -ForegroundColor Yellow
            Write-Host "  SiteServer: $($script:TestConnectData.Invalid.SiteServer)" -ForegroundColor White
            Write-Host "============================================================`n" -ForegroundColor Cyan

            # This test always passes, it's just for output
            $true | Should -Be $true
        }
    }

    Context "Connection Establishment" {

        It "Should connect successfully with valid site server" {
            # Arrange
            $params = @{
                SiteServer = $script:TestSiteServer
            }
            if($script:TestSkipCertificateCheck){
                $params.SkipCertificateCheck = $true
            }

            # Act & Assert
            { Connect-CMAS @params } | Should -Not -Throw
        }

        It "Should store connection details in script variables" {
            # Arrange & Act
            Connect-CMAS -SiteServer $script:TestSiteServer -SkipCertificateCheck:$script:TestSkipCertificateCheck

            # Assert
            $script:CMASConnection.SiteServer | Should -Be $script:TestSiteServer
            $script:CMASConnection.SiteCode | Should -Not -BeNullOrEmpty
        }

        It "Should fail with invalid site server" {
            # Arrange
            $invalidServer = "invalid-server-name-that-does-not-exist.local"

            # Act & Assert
            { Connect-CMAS -SiteServer $invalidServer -ErrorAction Stop } | Should -Throw
        }
    }

    Context "Credential Handling" {

        It "Should accept PSCredential parameter" {
            # Arrange
            $params = @{
                SiteServer = $script:TestSiteServer
                SkipCertificateCheck = $script:TestSkipCertificateCheck
            }
            if($null -ne $script:TestCredential){
                $params.Credential = $script:TestCredential
            }

            # Act & Assert
            { Connect-CMAS @params } | Should -Not -Throw
        }

        It "Should work with current user credentials when Credential not specified" {
            # Arrange & Act & Assert
            { Connect-CMAS -SiteServer $script:TestSiteServer -SkipCertificateCheck:$script:TestSkipCertificateCheck } | Should -Not -Throw
        }
    }

    Context "Certificate Handling" {

        It "Should accept SkipCertificateCheck parameter" {
            # Arrange & Act & Assert
            { Connect-CMAS -SiteServer $script:TestSiteServer -SkipCertificateCheck } | Should -Not -Throw
        }

        It "Should set certificate skip in script variable when specified" {
            # Arrange & Act
            Connect-CMAS -SiteServer $script:TestSiteServer -SkipCertificateCheck

            # Assert
            $script:CMASConnection.SkipCertificateCheck | Should -Be $true
        }
    }
}

Describe "Connect-CMAS Parameter Validation" -Tag "Unit" {

    Context "Parameter Metadata" {

        It "Should require SiteServer parameter" {
            # Get the command metadata
            $command = Get-Command Connect-CMAS
            $param = $command.Parameters['SiteServer']

            # Assert
            $param.Attributes.Mandatory | Should -Contain $true
        }

        It "Should accept string for SiteServer parameter" {
            # Get the command metadata
            $command = Get-Command Connect-CMAS
            $param = $command.Parameters['SiteServer']

            # Assert
            $param.ParameterType.Name | Should -Be "String"
        }

        It "Should have optional Credential parameter" {
            # Get the command metadata
            $command = Get-Command Connect-CMAS
            $param = $command.Parameters['Credential']

            # Assert
            $param | Should -Not -BeNullOrEmpty
            $param.Attributes.Mandatory | Should -Not -Contain $true
        }

        It "Should accept PSCredential for Credential parameter" {
            # Get the command metadata
            $command = Get-Command Connect-CMAS
            $param = $command.Parameters['Credential']

            # Assert
            $param.ParameterType.Name | Should -Be "PSCredential"
        }
    }
}

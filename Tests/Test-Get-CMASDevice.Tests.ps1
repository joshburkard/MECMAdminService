# Functional Tests for Get-CMASDevice
# Tests the Get-CMASDevice function behavior and return values

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
}

Describe "Get-CMASDevice Function Tests" -Tag "Integration", "Device" {

    Context "Device Retrieval by Name" {

        It "Should return device when valid name is provided" {
            # Arrange & Act
            $result = Get-CMASDevice -Name $script:TestDeviceName

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $script:TestDeviceName
        }

        It "Should return correct properties for device" {
            # Arrange & Act
            $result = Get-CMASDevice -Name $script:TestDeviceName

            # Assert
            $result | Should -Not -BeNullOrEmpty
            Assert-PropertyExists -Object $result -PropertyName "Name"
            Assert-PropertyExists -Object $result -PropertyName "ResourceID"
        }

        It "Should exclude WMI and OData metadata properties" {
            # Arrange & Act
            $result = Get-CMASDevice -Name $script:TestDeviceName

            # Assert
            $result | Should -Not -BeNullOrEmpty
            Assert-NoMetadataProperties -Object $result
        }

        It "Should return null or empty when device doesn't exist" {
            # Arrange & Act
            $result = Get-CMASDevice -Name $script:TestNonExistentDeviceName

            # Assert
            $result | Should -BeNullOrEmpty
        }

        It "Should return expected count of devices" {
            # Arrange & Act
            $result = Get-CMASDevice -Name $script:TestDeviceName

            # Assert
            if($null -ne $result){
                @($result).Count | Should -Be $script:ExpectedDeviceCount
            }
        }
    }

    Context "Device Retrieval by ResourceID" {

        BeforeAll {
            # Get a valid ResourceID from existing device
            $testDevice = Get-CMASDevice -Name $script:TestDeviceName
            $script:ValidResourceID = $testDevice.ResourceID
        }

        It "Should return device when valid ResourceID is provided" {
            # Arrange & Act
            $result = Get-CMASDevice -ResourceID $script:ValidResourceID

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.ResourceID | Should -Be $script:ValidResourceID
        }

        It "Should return correct data type for ResourceID" {
            # Arrange & Act
            $result = Get-CMASDevice -ResourceID $script:ValidResourceID

            # Assert
            # SCCM API returns ResourceID as Int64/long, not Int32
            $result.ResourceID | Should -BeOfType [long]
        }

        It "Should return all expected properties" {
            # Arrange & Act
            $result = Get-CMASDevice -ResourceID $script:ValidResourceID

            # Assert
            $result | Should -Not -BeNullOrEmpty
            Assert-PropertyExists -Object $result -PropertyName "Name"
            Assert-PropertyExists -Object $result -PropertyName "ResourceID"
            # Add more property checks as needed based on your requirements
        }
    }

    Context "Query All Devices" {

        It "Should return multiple devices when no filter is specified" {
            # Arrange & Act
            $result = Get-CMASDevice

            # Assert
            $result | Should -Not -BeNullOrEmpty
            @($result).Count | Should -BeGreaterThan 0
        }
    }

    Context "Error Handling" {

        It "Should handle API errors gracefully" {
            # Arrange
            $invalidResourceID = -1

            # Act & Assert
            # Should not throw, but might return empty result
            { Get-CMASDevice -ResourceID $invalidResourceID -ErrorAction SilentlyContinue } | Should -Not -Throw
        }
    }
}

Describe "Get-CMASDevice Parameter Validation" -Tag "Unit" {

    Context "Parameter Metadata" {

        It "Should accept string for Name parameter" {
            # Get the command metadata
            $command = Get-Command Get-CMASDevice
            $param = $command.Parameters['Name']

            # Assert
            $param.ParameterType.Name | Should -Be "String"
        }

        It "Should accept int for ResourceID parameter" {
            # Get the command metadata
            $command = Get-Command Get-CMASDevice
            $param = $command.Parameters['ResourceID']

            # Assert
            $param.ParameterType.Name | Should -Match "Int"
        }

        It "Should have both parameters as optional" {
            # Get the command metadata
            $command = Get-Command Get-CMASDevice

            # Assert
            $command.Parameters['Name'].Attributes.Mandatory | Should -Not -Contain $true
            $command.Parameters['ResourceID'].Attributes.Mandatory | Should -Not -Contain $true
        }
    }
}

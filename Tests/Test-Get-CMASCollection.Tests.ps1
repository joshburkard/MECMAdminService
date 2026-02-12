# Functional Tests for Get-CMASCollection
# Tests the Get-CMASCollection function behavior and return values

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

Describe "Get-CMASCollection Function Tests" -Tag "Integration", "Collection" {

    Context "Collection Retrieval by ID" {

        It "Should return collection when valid CollectionID is provided" {
            # Arrange & Act
            $result = Get-CMASCollection -CollectionID $script:TestCollectionID

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.CollectionID | Should -Be $script:TestCollectionID
        }

        It "Should return collection with expected properties" {
            # Arrange & Act
            $result = Get-CMASCollection -CollectionID $script:TestCollectionID

            # Assert
            $result | Should -Not -BeNullOrEmpty
            Assert-PropertyExists -Object $result -PropertyName "CollectionID"
            Assert-PropertyExists -Object $result -PropertyName "Name"
            Assert-PropertyExists -Object $result -PropertyName "CollectionType"
        }

        It "Should return null or empty when collection doesn't exist" {
            # Arrange & Act
            $result = Get-CMASCollection -CollectionID $script:TestNonExistentCollectionID

            # Assert
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Collection Retrieval by Name" {

        It "Should return collection when valid name is provided" {
            # Arrange & Act
            $result = Get-CMASCollection -Name $script:TestCollectionName

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $script:TestCollectionName
        }

        It "Should return correct CollectionType" {
            # Arrange & Act
            $result = Get-CMASCollection -Name $script:TestCollectionName

            # Assert
            $result | Should -Not -BeNullOrEmpty
            # CollectionType: 0 = Other, 1 = User, 2 = Device
            # SCCM API returns numeric values as Int64/long
            $result.CollectionType | Should -BeOfType [long]
        }
    }

    Context "Query All Collections" {

        It "Should return multiple collections when no filter is specified" {
            # Arrange & Act
            $result = Get-CMASCollection

            # Assert
            $result | Should -Not -BeNullOrEmpty
            @($result).Count | Should -BeGreaterThan 0
        }

        It "Should return collections with consistent properties" {
            # Arrange & Act
            $result = Get-CMASCollection | Select-Object -First 1

            # Assert
            $result | Should -Not -BeNullOrEmpty
            Assert-PropertyExists -Object $result -PropertyName "CollectionID"
            Assert-PropertyExists -Object $result -PropertyName "Name"
        }
    }

    Context "Error Handling" {

        It "Should handle API errors gracefully" {
            # Arrange - Use invalid characters that might cause API issues
            $invalidName = "Collection`$`$Invalid"

            # Act & Assert
            # Should not throw, but might return empty result
            { Get-CMASCollection -Name $invalidName -ErrorAction SilentlyContinue } | Should -Not -Throw
        }
    }
}

Describe "Get-CMASCollection Parameter Validation" -Tag "Unit" {

    Context "Parameter Metadata" {

        It "Should accept string for Name parameter" {
            # Get the command metadata
            $command = Get-Command Get-CMASCollection
            $param = $command.Parameters['Name']

            # Assert
            $param.ParameterType.Name | Should -Be "String"
        }

        It "Should accept string for CollectionID parameter" {
            # Get the command metadata
            $command = Get-Command Get-CMASCollection
            $param = $command.Parameters['CollectionID']

            # Assert
            $param.ParameterType.Name | Should -Be "String"
        }

        It "Should have both parameters as optional" {
            # Get the command metadata
            $command = Get-Command Get-CMASCollection

            # Assert
            $command.Parameters['Name'].Attributes.Mandatory | Should -Not -Contain $true
            $command.Parameters['CollectionID'].Attributes.Mandatory | Should -Not -Contain $true
        }
    }
}

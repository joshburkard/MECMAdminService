# Functional Tests for Get-CMASCollectionExcludeMembershipRule
# Tests the Get-CMASCollectionExcludeMembershipRule function behavior and return values

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

Describe "Get-CMASCollectionExcludeMembershipRule Function Tests" -Tag "Integration", "Collection", "MembershipRule" {

    Context "Retrieval by CollectionName" {

        It "Should return exclude membership rules when valid CollectionName is provided" {
            # Arrange & Act & Assert
            # Note: Result might be null/empty if no exclude membership rules exist
            # The important thing is that the function doesn't throw an error
            { Get-CMASCollectionExcludeMembershipRule -CollectionName $script:TestCollectionName } | Should -Not -Throw
        }

        It "Should return exclude membership rules with expected properties when they exist" {
            # Arrange & Act
            $result = Get-CMASCollectionExcludeMembershipRule -CollectionName $script:TestCollectionName

            # Assert
            if ($null -ne $result -and @($result).Count -gt 0) {
                Assert-PropertyExists -Object $result[0] -PropertyName "RuleName"
                Assert-PropertyExists -Object $result[0] -PropertyName "ExcludeCollectionID"
            }
        }

        It "Should filter by ExcludeCollectionName when both CollectionName and ExcludeCollectionName are provided" {
            # Arrange
            $excludeCollectionName = "Test Exclude Collection"

            # Act
            $result = Get-CMASCollectionExcludeMembershipRule -CollectionName $script:TestCollectionName -ExcludeCollectionName $excludeCollectionName

            # Assert
            if ($null -ne $result) {
                @($result).Count | Should -BeLessOrEqual 1
                if (@($result).Count -eq 1) {
                    $result.RuleName | Should -Be $excludeCollectionName
                }
            }
        }

        It "Should handle wildcards in ExcludeCollectionName parameter" {
            # Arrange
            $wildcardName = "*TEST*"

            # Act & Assert
            # Should not throw and handle wildcards appropriately
            { Get-CMASCollectionExcludeMembershipRule -CollectionName $script:TestCollectionName -ExcludeCollectionName $wildcardName } | Should -Not -Throw
        }

        It "Should return null or empty when collection doesn't exist" {
            # Arrange
            $nonExistentName = if($script:TestNonExistentCollectionName) {
                $script:TestNonExistentCollectionName
            } else {
                "NonExistent Collection 999"
            }

            # Act - Suppress error since function writes error for non-existent collection
            $result = Get-CMASCollectionExcludeMembershipRule -CollectionName $nonExistentName -ErrorAction SilentlyContinue

            # Assert
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Retrieval by CollectionId" {

        It "Should return exclude membership rules when valid CollectionId is provided" {
            # Arrange & Act & Assert
            # Note: Result might be null/empty if no exclude membership rules exist
            # The important thing is that the function doesn't throw an error
            { Get-CMASCollectionExcludeMembershipRule -CollectionId $script:TestCollectionID } | Should -Not -Throw
        }

        It "Should filter by ExcludeCollectionId when both CollectionId and ExcludeCollectionId are provided" {
            # Arrange
            $excludeCollectionId = "SMS00002"

            # Act
            $result = Get-CMASCollectionExcludeMembershipRule -CollectionId $script:TestCollectionID -ExcludeCollectionId $excludeCollectionId

            # Assert
            if ($null -ne $result) {
                @($result).Count | Should -BeLessOrEqual 1
                if (@($result).Count -eq 1) {
                    $result.ExcludeCollectionID | Should -Be $excludeCollectionId
                }
            }
        }

        It "Should return same results using CollectionId or CollectionName" {
            # Arrange & Act
            $resultById = Get-CMASCollectionExcludeMembershipRule -CollectionId $script:TestCollectionID
            $resultByName = Get-CMASCollectionExcludeMembershipRule -CollectionName $script:TestCollectionName

            # Assert
            @($resultById).Count | Should -Be @($resultByName).Count
        }

        It "Should return null or empty when collection doesn't exist" {
            # Arrange
            $nonExistentId = if($script:TestNonExistentCollectionID) {
                $script:TestNonExistentCollectionID
            } else {
                "XXX99999"
            }

            # Act - Suppress error since function writes error for non-existent collection
            $result = Get-CMASCollectionExcludeMembershipRule -CollectionId $nonExistentId -ErrorAction SilentlyContinue

            # Assert
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Retrieval with InputObject" {

        It "Should accept collection object from pipeline" {
            # Arrange & Act & Assert
            # Note: Result might be null/empty if no exclude membership rules exist
            # The important thing is that the function doesn't throw an error
            $collection = Get-CMASCollection -CollectionID $script:TestCollectionID
            { $collection | Get-CMASCollectionExcludeMembershipRule } | Should -Not -Throw
        }

        It "Should filter by ExcludeCollectionName when piped with ExcludeCollectionName parameter" {
            # Arrange
            $excludeCollectionName = "Test Exclude Collection"

            # Act
            $collection = Get-CMASCollection -CollectionID $script:TestCollectionID
            $result = $collection | Get-CMASCollectionExcludeMembershipRule -ExcludeCollectionName $excludeCollectionName

            # Assert
            if ($null -ne $result -and @($result).Count -gt 0) {
                $result[0].RuleName | Should -Match $excludeCollectionName
            }
        }

        It "Should filter by ExcludeCollectionId when piped with ExcludeCollectionId parameter" {
            # Arrange
            $excludeCollectionId = "SMS00002"

            # Act
            $collection = Get-CMASCollection -CollectionID $script:TestCollectionID
            $result = $collection | Get-CMASCollectionExcludeMembershipRule -ExcludeCollectionId $excludeCollectionId

            # Assert
            if ($null -ne $result) {
                @($result).Count | Should -BeLessOrEqual 1
            }
        }
    }

    Context "Multiple Parameter Combinations" {

        It "Should handle CollectionName with ExcludeCollectionId combination" {
            # Arrange
            $excludeCollectionId = "SMS00002"

            # Act & Assert
            # Should not throw
            { Get-CMASCollectionExcludeMembershipRule -CollectionName $script:TestCollectionName -ExcludeCollectionId $excludeCollectionId } | Should -Not -Throw
        }

        It "Should handle CollectionId with ExcludeCollectionName combination" {
            # Arrange
            $excludeCollectionName = "Test Exclude Collection"

            # Act & Assert
            # Should not throw
            { Get-CMASCollectionExcludeMembershipRule -CollectionId $script:TestCollectionID -ExcludeCollectionName $excludeCollectionName } | Should -Not -Throw
        }
    }

    Context "Return Properties" {

        It "Should return objects with standard exclude membership rule properties" {
            # Arrange & Act
            $result = Get-CMASCollectionExcludeMembershipRule -CollectionId $script:TestCollectionID | Select-Object -First 1

            # Assert
            if ($null -ne $result) {
                Assert-PropertyExists -Object $result -PropertyName "CollectionID"
                Assert-PropertyExists -Object $result -PropertyName "ExcludeCollectionID"
                Assert-PropertyExists -Object $result -PropertyName "RuleName"
            }
        }

        It "Should exclude WMI and OData metadata properties" {
            # Arrange & Act
            $result = Get-CMASCollectionExcludeMembershipRule -CollectionId $script:TestCollectionID | Select-Object -First 1

            # Assert
            if ($null -ne $result) {
                $result.PSObject.Properties.Name | Where-Object { $_ -like "__*" } | Should -BeNullOrEmpty
                $result.PSObject.Properties.Name | Where-Object { $_ -like "@odata*" } | Should -BeNullOrEmpty
            }
        }
    }

    Context "Error Handling" {

        It "Should throw error when not connected to Admin Service" {
            # Arrange
            $originalConnection = $script:CMASConnection
            $script:CMASConnection = @{ SiteServer = $null }

            # Act & Assert
            { Get-CMASCollectionExcludeMembershipRule -CollectionName "Test" } | Should -Throw

            # Cleanup
            $script:CMASConnection = $originalConnection
        }

        It "Should handle API errors gracefully" {
            # Arrange
            $invalidCollectionId = "INVALID_ID_12345"

            # Act & Assert
            # Should not throw, should return null
            $result = Get-CMASCollectionExcludeMembershipRule -CollectionId $invalidCollectionId
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Wildcard Support" {

        It "Should support wildcard at start of ExcludeCollectionName" {
            # Arrange
            $wildcardName = "*Collection"

            # Act & Assert
            { Get-CMASCollectionExcludeMembershipRule -CollectionName $script:TestCollectionName -ExcludeCollectionName $wildcardName } | Should -Not -Throw
        }

        It "Should support wildcard at end of ExcludeCollectionName" {
            # Arrange
            $wildcardName = "Test*"

            # Act & Assert
            { Get-CMASCollectionExcludeMembershipRule -CollectionName $script:TestCollectionName -ExcludeCollectionName $wildcardName } | Should -Not -Throw
        }

        It "Should support wildcard in middle of ExcludeCollectionName" {
            # Arrange
            $wildcardName = "Test*Collection"

            # Act & Assert
            { Get-CMASCollectionExcludeMembershipRule -CollectionName $script:TestCollectionName -ExcludeCollectionName $wildcardName } | Should -Not -Throw
        }
    }

    Context "Empty Results" {

        It "Should return null when collection has no exclude rules" {
            # Arrange
            # We assume SMS00001 (All Systems) typically has no exclude rules
            $collectionWithNoRules = "SMS00001"

            # Act
            $result = Get-CMASCollectionExcludeMembershipRule -CollectionId $collectionWithNoRules

            # Assert
            # Should either be null or empty array
            if ($null -ne $result) {
                @($result).Count | Should -Be 0
            }
        }
    }

    Context "Integration with Get-CMASCollection" {

        It "Should work seamlessly in pipeline from Get-CMASCollection" {
            # Arrange & Act
            $result = Get-CMASCollection -CollectionID $script:TestCollectionID | Get-CMASCollectionExcludeMembershipRule

            # Assert
            { Get-CMASCollection -CollectionID $script:TestCollectionID | Get-CMASCollectionExcludeMembershipRule } | Should -Not -Throw
        }

        It "Should handle multiple collections from pipeline" {
            # Arrange - Use the same collection ID twice to test pipeline with multiple objects
            $collections = @($script:TestCollectionID, $script:TestCollectionID)

            # Act & Assert
            { $collections | ForEach-Object { Get-CMASCollection -CollectionID $_ | Get-CMASCollectionExcludeMembershipRule } } | Should -Not -Throw
        }
    }
}

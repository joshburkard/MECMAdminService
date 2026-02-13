# Functional Tests for Get-CMASCollectionIncludeMembershipRule
# Tests the Get-CMASCollectionIncludeMembershipRule function behavior and return values

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
    $script:TestIncludeData = $script:TestData['Get-CMASCollectionIncludeMembershipRule']
}

Describe "Get-CMASCollectionIncludeMembershipRule Function Tests" -Tag "Integration", "Collection", "MembershipRule" {

    Context "Test Data Validation" {

        It "Should have test data defined in declarations.ps1" {
            # Assert
            $script:TestIncludeData | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('Get-CMASCollectionIncludeMembershipRule') | Should -Be $true
        }

        It "Should have required test data parameter sets" {
            # Assert
            $script:TestIncludeData.ContainsKey('ByCollectionName') | Should -Be $true
            $script:TestIncludeData.ContainsKey('ByCollectionId') | Should -Be $true
            $script:TestIncludeData.ContainsKey('ByCollectionNameAndIncludeName') | Should -Be $true
            $script:TestIncludeData.ContainsKey('ByCollectionIdAndIncludeId') | Should -Be $true
            $script:TestIncludeData.ContainsKey('WithWildcard') | Should -Be $true
            $script:TestIncludeData.ContainsKey('NonExistent') | Should -Be $true
        }

        It "Should output test data for verification" {
            # Output test data
            Write-Host "`n=== Test Data for Get-CMASCollectionIncludeMembershipRule ===" -ForegroundColor Cyan
            Write-Host "ByCollectionName:" -ForegroundColor Yellow
            Write-Host "  CollectionName: $($script:TestIncludeData.ByCollectionName.CollectionName)" -ForegroundColor White

            Write-Host "ByCollectionId:" -ForegroundColor Yellow
            Write-Host "  CollectionId: $($script:TestIncludeData.ByCollectionId.CollectionId)" -ForegroundColor White

            Write-Host "ByCollectionNameAndIncludeName:" -ForegroundColor Yellow
            Write-Host "  CollectionName: $($script:TestIncludeData.ByCollectionNameAndIncludeName.CollectionName)" -ForegroundColor White
            Write-Host "  IncludeCollectionName: $($script:TestIncludeData.ByCollectionNameAndIncludeName.IncludeCollectionName)" -ForegroundColor White

            Write-Host "ByCollectionIdAndIncludeId:" -ForegroundColor Yellow
            Write-Host "  CollectionId: $($script:TestIncludeData.ByCollectionIdAndIncludeId.CollectionId)" -ForegroundColor White
            Write-Host "  IncludeCollectionId: $($script:TestIncludeData.ByCollectionIdAndIncludeId.IncludeCollectionId)" -ForegroundColor White

            Write-Host "WithWildcard:" -ForegroundColor Yellow
            Write-Host "  CollectionName: $($script:TestIncludeData.WithWildcard.CollectionName)" -ForegroundColor White
            Write-Host "  IncludeCollectionName: $($script:TestIncludeData.WithWildcard.IncludeCollectionName)" -ForegroundColor White

            Write-Host "NonExistent:" -ForegroundColor Yellow
            Write-Host "  CollectionName: $($script:TestIncludeData.NonExistent.CollectionName)" -ForegroundColor White
            Write-Host "  CollectionId: $($script:TestIncludeData.NonExistent.CollectionId)" -ForegroundColor White
            Write-Host "============================================================`n" -ForegroundColor Cyan

            # This test always passes, it's just for output
            $true | Should -Be $true
        }
    }

    Context "Retrieval by CollectionName" {

        It "Should return include membership rules when valid CollectionName is provided" {
            # Arrange & Act & Assert
            # Note: Result might be null/empty if no include membership rules exist
            # The important thing is that the function doesn't throw an error
            { Get-CMASCollectionIncludeMembershipRule -CollectionName $script:TestIncludeData.ByCollectionName.CollectionName } | Should -Not -Throw
        }

        It "Should return include membership rules with expected properties when they exist" {
            # Arrange & Act
            $result = Get-CMASCollectionIncludeMembershipRule -CollectionName $script:TestIncludeData.ByCollectionName.CollectionName

            # Assert
            if ($null -ne $result -and @($result).Count -gt 0) {
                Assert-PropertyExists -Object $result[0] -PropertyName "RuleName"
                Assert-PropertyExists -Object $result[0] -PropertyName "IncludeCollectionID"
            }
        }

        It "Should filter by IncludeCollectionName when both CollectionName and IncludeCollectionName are provided" {
            # Arrange
            $includeCollectionName = $script:TestIncludeData.ByCollectionNameAndIncludeName.IncludeCollectionName

            # Act
            $result = Get-CMASCollectionIncludeMembershipRule -CollectionName $script:TestIncludeData.ByCollectionNameAndIncludeName.CollectionName -IncludeCollectionName $includeCollectionName

            # Assert
            if ($null -ne $result) {
                @($result).Count | Should -BeLessOrEqual 1
                if (@($result).Count -eq 1) {
                    $result.RuleName | Should -Be $includeCollectionName
                }
            }
        }

        It "Should handle wildcards in IncludeCollectionName parameter" {
            # Arrange
            $wildcardName = $script:TestIncludeData.WithWildcard.IncludeCollectionName

            # Act & Assert
            # Should not throw and handle wildcards appropriately
            { Get-CMASCollectionIncludeMembershipRule -CollectionName $script:TestIncludeData.WithWildcard.CollectionName -IncludeCollectionName $wildcardName } | Should -Not -Throw
        }

        It "Should return null or empty when collection doesn't exist" {
            # Arrange
            $nonExistentName = $script:TestIncludeData.NonExistent.CollectionName

            # Act - Suppress error since function writes error for non-existent collection
            $result = Get-CMASCollectionIncludeMembershipRule -CollectionName $nonExistentName -ErrorAction SilentlyContinue

            # Assert
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Retrieval by CollectionId" {

        It "Should return include membership rules when valid CollectionId is provided" {
            # Arrange & Act & Assert
            # Note: Result might be null/empty if no include membership rules exist
            # The important thing is that the function doesn't throw an error
            { Get-CMASCollectionIncludeMembershipRule -CollectionId $script:TestIncludeData.ByCollectionId.CollectionId } | Should -Not -Throw
        }

        It "Should filter by IncludeCollectionId when both CollectionId and IncludeCollectionId are provided" {
            # Arrange
            $includeCollectionId = $script:TestIncludeData.ByCollectionIdAndIncludeId.IncludeCollectionId

            # Act
            $result = Get-CMASCollectionIncludeMembershipRule -CollectionId $script:TestIncludeData.ByCollectionIdAndIncludeId.CollectionId -IncludeCollectionId $includeCollectionId

            # Assert
            if ($null -ne $result) {
                @($result).Count | Should -BeLessOrEqual 1
                if (@($result).Count -eq 1) {
                    $result.IncludeCollectionID | Should -Be $includeCollectionId
                }
            }
        }

        It "Should return same results using CollectionId or CollectionName" {
            # Arrange & Act
            $resultById = Get-CMASCollectionIncludeMembershipRule -CollectionId $script:TestIncludeData.ByCollectionId.CollectionId
            $resultByName = Get-CMASCollectionIncludeMembershipRule -CollectionName $script:TestIncludeData.ByCollectionName.CollectionName

            # Assert
            @($resultById).Count | Should -Be @($resultByName).Count
        }

        It "Should return null or empty when collection doesn't exist" {
            # Arrange
            $nonExistentId = $script:TestIncludeData.NonExistent.CollectionId

            # Act - Suppress error since function writes error for non-existent collection
            $result = Get-CMASCollectionIncludeMembershipRule -CollectionId $nonExistentId -ErrorAction SilentlyContinue

            # Assert
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Retrieval with InputObject" {

        It "Should accept collection object from pipeline" {
            # Arrange & Act & Assert
            # Note: Result might be null/empty if no include membership rules exist
            # The important thing is that the function doesn't throw an error
            $collection = Get-CMASCollection -CollectionID $script:TestIncludeData.ByCollectionId.CollectionId
            { $collection | Get-CMASCollectionIncludeMembershipRule } | Should -Not -Throw
        }

        It "Should filter by IncludeCollectionName when piped with IncludeCollectionName parameter" {
            # Arrange
            $includeCollectionName = $script:TestIncludeData.ByCollectionNameAndIncludeName.IncludeCollectionName

            # Act
            $collection = Get-CMASCollection -CollectionID $script:TestIncludeData.ByCollectionId.CollectionId
            $result = $collection | Get-CMASCollectionIncludeMembershipRule -IncludeCollectionName $includeCollectionName

            # Assert
            if ($null -ne $result -and @($result).Count -gt 0) {
                $result[0].RuleName | Should -Match $includeCollectionName
            }
        }

        It "Should filter by IncludeCollectionId when piped with IncludeCollectionId parameter" {
            # Arrange
            $includeCollectionId = $script:TestIncludeData.ByCollectionIdAndIncludeId.IncludeCollectionId

            # Act
            $collection = Get-CMASCollection -CollectionID $script:TestIncludeData.ByCollectionId.CollectionId
            $result = $collection | Get-CMASCollectionIncludeMembershipRule -IncludeCollectionId $includeCollectionId

            # Assert
            if ($null -ne $result) {
                @($result).Count | Should -BeLessOrEqual 1
            }
        }
    }

    Context "Multiple Parameter Combinations" {

        It "Should handle CollectionName with IncludeCollectionId combination" {
            # Arrange
            $includeCollectionId = $script:TestIncludeData.ByCollectionIdAndIncludeId.IncludeCollectionId

            # Act & Assert
            # Should not throw
            { Get-CMASCollectionIncludeMembershipRule -CollectionName $script:TestIncludeData.ByCollectionName.CollectionName -IncludeCollectionId $includeCollectionId } | Should -Not -Throw
        }

        It "Should handle CollectionId with IncludeCollectionName combination" {
            # Arrange
            $includeCollectionName = $script:TestIncludeData.ByCollectionNameAndIncludeName.IncludeCollectionName

            # Act & Assert
            # Should not throw
            { Get-CMASCollectionIncludeMembershipRule -CollectionId $script:TestIncludeData.ByCollectionId.CollectionId -IncludeCollectionName $includeCollectionName } | Should -Not -Throw
        }
    }

    Context "Return Properties" {

        It "Should return objects with standard include membership rule properties" {
            # Arrange & Act
            $result = Get-CMASCollectionIncludeMembershipRule -CollectionId $script:TestIncludeData.ByCollectionId.CollectionId | Select-Object -First 1

            # Assert
            if ($null -ne $result) {
                Assert-PropertyExists -Object $result -PropertyName "CollectionID"
                Assert-PropertyExists -Object $result -PropertyName "IncludeCollectionID"
                Assert-PropertyExists -Object $result -PropertyName "RuleName"
            }
        }

        It "Should exclude WMI and OData metadata properties" {
            # Arrange & Act
            $result = Get-CMASCollectionIncludeMembershipRule -CollectionId $script:TestIncludeData.ByCollectionId.CollectionId | Select-Object -First 1

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
            { Get-CMASCollectionIncludeMembershipRule -CollectionName "Test" } | Should -Throw

            # Cleanup
            $script:CMASConnection = $originalConnection
        }

        It "Should handle API errors gracefully" {
            # Arrange
            $invalidCollectionId = "INVALID_ID_12345"

            # Act & Assert
            # Should not throw, should return null
            $result = Get-CMASCollectionIncludeMembershipRule -CollectionId $invalidCollectionId
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Wildcard Support" {

        It "Should support wildcard at start of IncludeCollectionName" {
            # Arrange
            $wildcardName = "*Collection"

            # Act & Assert
            { Get-CMASCollectionIncludeMembershipRule -CollectionName $script:TestIncludeData.ByCollectionName.CollectionName -IncludeCollectionName $wildcardName } | Should -Not -Throw
        }

        It "Should support wildcard at end of IncludeCollectionName" {
            # Arrange
            $wildcardName = "Test*"

            # Act & Assert
            { Get-CMASCollectionIncludeMembershipRule -CollectionName $script:TestIncludeData.ByCollectionName.CollectionName -IncludeCollectionName $wildcardName } | Should -Not -Throw
        }

        It "Should support wildcard in middle of IncludeCollectionName" {
            # Arrange
            $wildcardName = "Test*Collection"

            # Act & Assert
            { Get-CMASCollectionIncludeMembershipRule -CollectionName $script:TestIncludeData.ByCollectionName.CollectionName -IncludeCollectionName $wildcardName } | Should -Not -Throw
        }
    }

    Context "Empty Results" {

        It "Should return null when collection has no include rules" {
            # Arrange
            # We assume SMS00001 (All Systems) typically has no include rules
            $collectionWithNoRules = "SMS00001"

            # Act
            $result = Get-CMASCollectionIncludeMembershipRule -CollectionId $collectionWithNoRules

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
            $result = Get-CMASCollection -CollectionID $script:TestIncludeData.ByCollectionId.CollectionId | Get-CMASCollectionIncludeMembershipRule

            # Assert
            { Get-CMASCollection -CollectionID $script:TestIncludeData.ByCollectionId.CollectionId | Get-CMASCollectionIncludeMembershipRule } | Should -Not -Throw
        }

        It "Should handle multiple collections from pipeline" {
            # Arrange - Use the same collection ID twice to test pipeline with multiple objects
            $collections = @($script:TestIncludeData.ByCollectionId.CollectionId, $script:TestIncludeData.ByCollectionId.CollectionId)

            # Act & Assert
            { $collections | ForEach-Object { Get-CMASCollection -CollectionID $_ | Get-CMASCollectionIncludeMembershipRule } } | Should -Not -Throw
        }
    }

    Context "Parameter Set Validation" {

        It "Should accept CollectionName parameter" {
            # Act & Assert
            { Get-CMASCollectionIncludeMembershipRule -CollectionName $script:TestIncludeData.ByCollectionName.CollectionName } | Should -Not -Throw
        }

        It "Should accept CollectionId parameter" {
            # Act & Assert
            { Get-CMASCollectionIncludeMembershipRule -CollectionId $script:TestIncludeData.ByCollectionId.CollectionId } | Should -Not -Throw
        }

        It "Should accept InputObject parameter from pipeline" {
            # Act & Assert
            { Get-CMASCollection -CollectionID $script:TestIncludeData.ByCollectionId.CollectionId | Get-CMASCollectionIncludeMembershipRule } | Should -Not -Throw
        }

        It "Should accept CollectionName with IncludeCollectionName" {
            # Act & Assert
            { Get-CMASCollectionIncludeMembershipRule -CollectionName $script:TestIncludeData.ByCollectionName.CollectionName -IncludeCollectionName "Test" } | Should -Not -Throw
        }

        It "Should accept CollectionName with IncludeCollectionId" {
            # Act & Assert
            { Get-CMASCollectionIncludeMembershipRule -CollectionName $script:TestIncludeData.ByCollectionName.CollectionName -IncludeCollectionId "SMS00001" } | Should -Not -Throw
        }

        It "Should accept CollectionId with IncludeCollectionName" {
            # Act & Assert
            { Get-CMASCollectionIncludeMembershipRule -CollectionId $script:TestIncludeData.ByCollectionId.CollectionId -IncludeCollectionName "Test" } | Should -Not -Throw
        }

        It "Should accept CollectionId with IncludeCollectionId" {
            # Act & Assert
            { Get-CMASCollectionIncludeMembershipRule -CollectionId $script:TestIncludeData.ByCollectionId.CollectionId -IncludeCollectionId "SMS00001" } | Should -Not -Throw
        }

        It "Should accept InputObject with IncludeCollectionName from pipeline" {
            # Act & Assert
            { Get-CMASCollection -CollectionID $script:TestIncludeData.ByCollectionId.CollectionId | Get-CMASCollectionIncludeMembershipRule -IncludeCollectionName "Test" } | Should -Not -Throw
        }

        It "Should accept InputObject with IncludeCollectionId from pipeline" {
            # Act & Assert
            { Get-CMASCollection -CollectionID $script:TestIncludeData.ByCollectionId.CollectionId | Get-CMASCollectionIncludeMembershipRule -IncludeCollectionId "SMS00001" } | Should -Not -Throw
        }
    }

    Context "Verbose Output" {

        It "Should provide verbose output when -Verbose is specified" {
            # Arrange & Act
            $verboseOutput = Get-CMASCollectionIncludeMembershipRule -CollectionId $script:TestIncludeData.ByCollectionId.CollectionId -Verbose 4>&1

            # Assert
            $verboseOutput | Should -Not -BeNullOrEmpty
        }
    }
}

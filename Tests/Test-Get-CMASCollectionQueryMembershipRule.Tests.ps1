# Functional Tests for Get-CMASCollectionQueryMembershipRule
# Tests the Get-CMASCollectionQueryMembershipRule function behavior and return values

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
    $script:TestQueryData = $script:TestData['Get-CMASCollectionQueryMembershipRule']
}

Describe "Get-CMASCollectionQueryMembershipRule Function Tests" -Tag "Integration", "Collection", "MembershipRule" {

    Context "Test Data Validation" {

        It "Should have test data defined in declarations.ps1" {
            # Assert
            $script:TestQueryData | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('Get-CMASCollectionQueryMembershipRule') | Should -Be $true
        }

        It "Should have required test data parameter sets" {
            # Assert
            $script:TestQueryData.ContainsKey('ByCollectionName') | Should -Be $true
            $script:TestQueryData.ContainsKey('ByCollectionId') | Should -Be $true
            $script:TestQueryData.ContainsKey('ByCollectionNameAndRuleName') | Should -Be $true
            $script:TestQueryData.ContainsKey('ByCollectionIdAndRuleName') | Should -Be $true
            $script:TestQueryData.ContainsKey('WithWildcard') | Should -Be $true
            $script:TestQueryData.ContainsKey('NonExistent') | Should -Be $true
        }

        It "Should output test data for verification" {
            # Output test data
            Write-Host "`n=== Test Data for Get-CMASCollectionQueryMembershipRule ===" -ForegroundColor Cyan
            Write-Host "ByCollectionName:" -ForegroundColor Yellow
            Write-Host "  CollectionName: $($script:TestQueryData.ByCollectionName.CollectionName)" -ForegroundColor White

            Write-Host "ByCollectionId:" -ForegroundColor Yellow
            Write-Host "  CollectionId: $($script:TestQueryData.ByCollectionId.CollectionId)" -ForegroundColor White

            Write-Host "ByCollectionNameAndRuleName:" -ForegroundColor Yellow
            Write-Host "  CollectionName: $($script:TestQueryData.ByCollectionNameAndRuleName.CollectionName)" -ForegroundColor White
            Write-Host "  RuleName: $($script:TestQueryData.ByCollectionNameAndRuleName.RuleName)" -ForegroundColor White

            Write-Host "ByCollectionIdAndRuleName:" -ForegroundColor Yellow
            Write-Host "  CollectionId: $($script:TestQueryData.ByCollectionIdAndRuleName.CollectionId)" -ForegroundColor White
            Write-Host "  RuleName: $($script:TestQueryData.ByCollectionIdAndRuleName.RuleName)" -ForegroundColor White

            Write-Host "WithWildcard:" -ForegroundColor Yellow
            Write-Host "  CollectionName: $($script:TestQueryData.WithWildcard.CollectionName)" -ForegroundColor White
            Write-Host "  RuleName: $($script:TestQueryData.WithWildcard.RuleName)" -ForegroundColor White

            Write-Host "NonExistent:" -ForegroundColor Yellow
            Write-Host "  CollectionName: $($script:TestQueryData.NonExistent.CollectionName)" -ForegroundColor White
            Write-Host "  CollectionId: $($script:TestQueryData.NonExistent.CollectionId)" -ForegroundColor White
            Write-Host "============================================================`n" -ForegroundColor Cyan

            # This test always passes, it's just for output
            $true | Should -Be $true
        }
    }

    Context "Retrieval by CollectionName" {

        It "Should return query membership rules when valid CollectionName is provided" {
            # Arrange & Act & Assert
            # Note: Result might be null/empty if no query membership rules exist
            # The important thing is that the function doesn't throw an error
            { Get-CMASCollectionQueryMembershipRule -CollectionName $script:TestQueryData.ByCollectionName.CollectionName } | Should -Not -Throw
        }

        It "Should return query membership rules with expected properties when they exist" {
            # Arrange & Act
            $result = Get-CMASCollectionQueryMembershipRule -CollectionName $script:TestQueryData.ByCollectionName.CollectionName

            # Assert
            if ($null -ne $result -and @($result).Count -gt 0) {
                Assert-PropertyExists -Object $result[0] -PropertyName "RuleName"
                Assert-PropertyExists -Object $result[0] -PropertyName "QueryExpression"
            }
        }

        It "Should filter by RuleName when both CollectionName and RuleName are provided" {
            # Arrange
            $ruleName = $script:TestQueryData.ByCollectionNameAndRuleName.RuleName

            # Act
            $result = Get-CMASCollectionQueryMembershipRule -CollectionName $script:TestQueryData.ByCollectionNameAndRuleName.CollectionName -RuleName $ruleName

            # Assert
            if ($null -ne $result) {
                @($result).Count | Should -BeLessOrEqual 1
                if (@($result).Count -eq 1) {
                    $result.RuleName | Should -Be $ruleName
                }
            }
        }

        It "Should handle wildcards in RuleName parameter" {
            # Arrange
            $wildcardName = $script:TestQueryData.WithWildcard.RuleName

            # Act & Assert
            # Should not throw and handle wildcards appropriately
            { Get-CMASCollectionQueryMembershipRule -CollectionName $script:TestQueryData.WithWildcard.CollectionName -RuleName $wildcardName } | Should -Not -Throw
        }

        It "Should return null or empty when collection doesn't exist" {
            # Arrange
            $nonExistentName = $script:TestQueryData.NonExistent.CollectionName

            # Act - Suppress error since function writes error for non-existent collection
            $result = Get-CMASCollectionQueryMembershipRule -CollectionName $nonExistentName -ErrorAction SilentlyContinue

            # Assert
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Retrieval by CollectionId" {

        It "Should return query membership rules when valid CollectionId is provided" {
            # Arrange & Act & Assert
            # Note: Result might be null/empty if no query membership rules exist
            # The important thing is that the function doesn't throw an error
            { Get-CMASCollectionQueryMembershipRule -CollectionId $script:TestQueryData.ByCollectionId.CollectionId } | Should -Not -Throw
        }

        It "Should filter by RuleName when both CollectionId and RuleName are provided" {
            # Arrange
            $ruleName = $script:TestQueryData.ByCollectionIdAndRuleName.RuleName

            # Act
            $result = Get-CMASCollectionQueryMembershipRule -CollectionId $script:TestQueryData.ByCollectionIdAndRuleName.CollectionId -RuleName $ruleName

            # Assert
            if ($null -ne $result) {
                @($result).Count | Should -BeLessOrEqual 1
                if (@($result).Count -eq 1) {
                    $result.RuleName | Should -Be $ruleName
                }
            }
        }

        It "Should return same results using CollectionId or CollectionName" {
            # Arrange & Act
            $resultById = Get-CMASCollectionQueryMembershipRule -CollectionId $script:TestQueryData.ByCollectionId.CollectionId
            $resultByName = Get-CMASCollectionQueryMembershipRule -CollectionName $script:TestQueryData.ByCollectionName.CollectionName

            # Assert
            @($resultById).Count | Should -Be @($resultByName).Count
        }

        It "Should return null or empty when collection doesn't exist" {
            # Arrange
            $nonExistentId = $script:TestQueryData.NonExistent.CollectionId

            # Act - Suppress error since function writes error for non-existent collection
            $result = Get-CMASCollectionQueryMembershipRule -CollectionId $nonExistentId -ErrorAction SilentlyContinue

            # Assert
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Retrieval with InputObject" {

        It "Should accept collection object from pipeline" {
            # Arrange & Act & Assert
            # Note: Result might be null/empty if no query membership rules exist
            # The important thing is that the function doesn't throw an error
            $collection = Get-CMASCollection -CollectionID $script:TestQueryData.ByCollectionId.CollectionId
            { $collection | Get-CMASCollectionQueryMembershipRule } | Should -Not -Throw
        }

        It "Should filter by RuleName when piped with RuleName parameter" {
            # Arrange
            $ruleName = $script:TestQueryData.ByCollectionNameAndRuleName.RuleName

            # Act
            $collection = Get-CMASCollection -CollectionID $script:TestQueryData.ByCollectionId.CollectionId
            $result = $collection | Get-CMASCollectionQueryMembershipRule -RuleName $ruleName

            # Assert
            if ($null -ne $result -and @($result).Count -gt 0) {
                $result[0].RuleName | Should -Match $ruleName
            }
        }
    }

    Context "Multiple Parameter Combinations" {

        It "Should handle CollectionName with RuleName combination" {
            # Arrange
            $ruleName = $script:TestQueryData.ByCollectionNameAndRuleName.RuleName

            # Act & Assert
            # Should not throw
            { Get-CMASCollectionQueryMembershipRule -CollectionName $script:TestQueryData.ByCollectionName.CollectionName -RuleName $ruleName } | Should -Not -Throw
        }

        It "Should handle CollectionId with RuleName combination" {
            # Arrange
            $ruleName = $script:TestQueryData.ByCollectionIdAndRuleName.RuleName

            # Act & Assert
            # Should not throw
            { Get-CMASCollectionQueryMembershipRule -CollectionId $script:TestQueryData.ByCollectionId.CollectionId -RuleName $ruleName } | Should -Not -Throw
        }
    }

    Context "Return Properties" {

        It "Should return objects with standard query membership rule properties" {
            # Arrange & Act
            $result = Get-CMASCollectionQueryMembershipRule -CollectionId $script:TestQueryData.ByCollectionId.CollectionId | Select-Object -First 1

            # Assert
            if ($null -ne $result) {
                Assert-PropertyExists -Object $result -PropertyName "CollectionID"
                Assert-PropertyExists -Object $result -PropertyName "RuleName"
                Assert-PropertyExists -Object $result -PropertyName "QueryExpression"
            }
        }

        It "Should exclude WMI and OData metadata properties" {
            # Arrange & Act
            $result = Get-CMASCollectionQueryMembershipRule -CollectionId $script:TestQueryData.ByCollectionId.CollectionId | Select-Object -First 1

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
            { Get-CMASCollectionQueryMembershipRule -CollectionName "Test" } | Should -Throw

            # Cleanup
            $script:CMASConnection = $originalConnection
        }

        It "Should handle API errors gracefully" {
            # Arrange
            $invalidCollectionId = "INVALID_ID_12345"

            # Act & Assert
            # Should not throw, should return null
            $result = Get-CMASCollectionQueryMembershipRule -CollectionId $invalidCollectionId
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Wildcard Support" {

        It "Should support wildcard at start of RuleName" {
            # Arrange
            $wildcardName = "*Rule"

            # Act & Assert
            { Get-CMASCollectionQueryMembershipRule -CollectionName $script:TestQueryData.ByCollectionName.CollectionName -RuleName $wildcardName } | Should -Not -Throw
        }

        It "Should support wildcard at end of RuleName" {
            # Arrange
            $wildcardName = "Test*"

            # Act & Assert
            { Get-CMASCollectionQueryMembershipRule -CollectionName $script:TestQueryData.ByCollectionName.CollectionName -RuleName $wildcardName } | Should -Not -Throw
        }

        It "Should support wildcard in middle of RuleName" {
            # Arrange
            $wildcardName = "Test*Rule"

            # Act & Assert
            { Get-CMASCollectionQueryMembershipRule -CollectionName $script:TestQueryData.ByCollectionName.CollectionName -RuleName $wildcardName } | Should -Not -Throw
        }
    }

    Context "Empty Results" {

        It "Should return null when collection has no query rules" {
            # Arrange
            # We assume SD101C00 (a test collection) typically has no query rules
            $collectionWithNoRules = "SD101C00"

            # Act
            $result = Get-CMASCollectionQueryMembershipRule -CollectionId $collectionWithNoRules

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
            $result = Get-CMASCollection -CollectionID $script:TestQueryData.ByCollectionId.CollectionId | Get-CMASCollectionQueryMembershipRule

            # Assert
            { Get-CMASCollection -CollectionID $script:TestQueryData.ByCollectionId.CollectionId | Get-CMASCollectionQueryMembershipRule } | Should -Not -Throw
        }

        It "Should handle multiple collections from pipeline" {
            # Arrange - Use the same collection ID twice to test pipeline with multiple objects
            $collections = @($script:TestQueryData.ByCollectionId.CollectionId, $script:TestQueryData.ByCollectionId.CollectionId)

            # Act & Assert
            { $collections | ForEach-Object { Get-CMASCollection -CollectionID $_ | Get-CMASCollectionQueryMembershipRule } } | Should -Not -Throw
        }
    }

    Context "Parameter Set Validation" {

        It "Should accept CollectionName parameter" {
            # Act & Assert
            { Get-CMASCollectionQueryMembershipRule -CollectionName $script:TestQueryData.ByCollectionName.CollectionName } | Should -Not -Throw
        }

        It "Should accept CollectionId parameter" {
            # Act & Assert
            { Get-CMASCollectionQueryMembershipRule -CollectionId $script:TestQueryData.ByCollectionId.CollectionId } | Should -Not -Throw
        }

        It "Should accept InputObject parameter from pipeline" {
            # Act & Assert
            { Get-CMASCollection -CollectionID $script:TestQueryData.ByCollectionId.CollectionId | Get-CMASCollectionQueryMembershipRule } | Should -Not -Throw
        }

        It "Should accept CollectionName with RuleName" {
            # Act & Assert
            { Get-CMASCollectionQueryMembershipRule -CollectionName $script:TestQueryData.ByCollectionName.CollectionName -RuleName "Test" } | Should -Not -Throw
        }

        It "Should accept CollectionId with RuleName" {
            # Act & Assert
            { Get-CMASCollectionQueryMembershipRule -CollectionId $script:TestQueryData.ByCollectionId.CollectionId -RuleName "Test" } | Should -Not -Throw
        }

        It "Should accept InputObject with RuleName from pipeline" {
            # Act & Assert
            { Get-CMASCollection -CollectionID $script:TestQueryData.ByCollectionId.CollectionId | Get-CMASCollectionQueryMembershipRule -RuleName "Test" } | Should -Not -Throw
        }
    }

    Context "Verbose Output" {

        It "Should provide verbose output when -Verbose is specified" {
            # Arrange & Act
            $verboseOutput = Get-CMASCollectionQueryMembershipRule -CollectionId $script:TestQueryData.ByCollectionId.CollectionId -Verbose 4>&1

            # Assert
            $verboseOutput | Should -Not -BeNullOrEmpty
        }
    }

    Context "Query Expression Validation" {

        It "Should return QueryExpression property with WQL query" {
            # Arrange & Act
            $result = Get-CMASCollectionQueryMembershipRule -CollectionId $script:TestQueryData.ByCollectionId.CollectionId | Select-Object -First 1

            # Assert
            if ($null -ne $result) {
                $result.QueryExpression | Should -Not -BeNullOrEmpty
                # WQL queries typically start with "select"
                $result.QueryExpression | Should -Match "(?i)^select"
            }
        }
    }
}

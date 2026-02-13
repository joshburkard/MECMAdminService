# Functional Tests for Add-CMASCollectionMembershipRule
# Tests the Add-CMASCollectionMembershipRule function behavior and return values

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
    $script:TestAddRuleData = $script:TestData['Add-CMASCollectionMembershipRule']
}

Describe "Add-CMASCollectionMembershipRule Function Tests" -Tag "Integration", "Collection", "MembershipRule", "Modify" {

    Context "Test Data Validation" {

        It "Should have test data defined in declarations.ps1" {
            # Assert
            $script:TestAddRuleData | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('Add-CMASCollectionMembershipRule') | Should -Be $true
        }

        It "Should have required test data parameter sets" {
            # Assert
            $script:TestAddRuleData.ContainsKey('DirectByCollectionNameAndResourceId') | Should -Be $true
            $script:TestAddRuleData.ContainsKey('DirectByCollectionIdAndResourceName') | Should -Be $true
            $script:TestAddRuleData.ContainsKey('QueryByCollectionName') | Should -Be $true
            $script:TestAddRuleData.ContainsKey('IncludeByCollectionName') | Should -Be $true
            $script:TestAddRuleData.ContainsKey('ExcludeByCollectionName') | Should -Be $true
            $script:TestAddRuleData.ContainsKey('TestCollection') | Should -Be $true
        }

        It "Should output test data for verification" {
            # Output test data
            Write-Host "`n=== Test Data for Add-CMASCollectionMembershipRule ===" -ForegroundColor Cyan
            Write-Host "TestCollection:" -ForegroundColor Yellow
            Write-Host "  CollectionName: $($script:TestAddRuleData.TestCollection.CollectionName)" -ForegroundColor White
            Write-Host "  CollectionId: $($script:TestAddRuleData.TestCollection.CollectionId)" -ForegroundColor White

            Write-Host "DirectByCollectionNameAndResourceId:" -ForegroundColor Yellow
            Write-Host "  CollectionName: $($script:TestAddRuleData.DirectByCollectionNameAndResourceId.CollectionName)" -ForegroundColor White
            Write-Host "  ResourceId: $($script:TestAddRuleData.DirectByCollectionNameAndResourceId.ResourceId)" -ForegroundColor White

            Write-Host "DirectByCollectionIdAndResourceName:" -ForegroundColor Yellow
            Write-Host "  CollectionId: $($script:TestAddRuleData.DirectByCollectionIdAndResourceName.CollectionId)" -ForegroundColor White
            Write-Host "  ResourceName: $($script:TestAddRuleData.DirectByCollectionIdAndResourceName.ResourceName)" -ForegroundColor White

            Write-Host "QueryByCollectionName:" -ForegroundColor Yellow
            Write-Host "  CollectionName: $($script:TestAddRuleData.QueryByCollectionName.CollectionName)" -ForegroundColor White
            Write-Host "  RuleName: $($script:TestAddRuleData.QueryByCollectionName.RuleName)" -ForegroundColor White
            Write-Host "  QueryExpression: $($script:TestAddRuleData.QueryByCollectionName.QueryExpression)" -ForegroundColor White

            Write-Host "IncludeByCollectionName:" -ForegroundColor Yellow
            Write-Host "  CollectionName: $($script:TestAddRuleData.IncludeByCollectionName.CollectionName)" -ForegroundColor White
            Write-Host "  IncludeCollectionName: $($script:TestAddRuleData.IncludeByCollectionName.IncludeCollectionName)" -ForegroundColor White

            Write-Host "ExcludeByCollectionName:" -ForegroundColor Yellow
            Write-Host "  CollectionName: $($script:TestAddRuleData.ExcludeByCollectionName.CollectionName)" -ForegroundColor White
            Write-Host "  ExcludeCollectionName: $($script:TestAddRuleData.ExcludeByCollectionName.ExcludeCollectionName)" -ForegroundColor White
            Write-Host "============================================================`n" -ForegroundColor Cyan

            # This test always passes, it's just for output
            $true | Should -Be $true
        }
    }

    Context "Adding Direct Membership Rules" {

        It "Should add a direct membership rule by CollectionName and ResourceId without errors" {
            # Arrange
            $collectionName = $script:TestAddRuleData.DirectByCollectionNameAndResourceId.CollectionName
            $resourceId = $script:TestAddRuleData.DirectByCollectionNameAndResourceId.ResourceId

            # Act & Assert
            { Add-CMASCollectionMembershipRule -CollectionName $collectionName -RuleType Direct -ResourceId $resourceId -Confirm:$false } | Should -Not -Throw
        }

        It "Should add a direct membership rule by CollectionId and ResourceName without errors" {
            # Arrange
            $collectionId = $script:TestAddRuleData.DirectByCollectionIdAndResourceName.CollectionId
            $resourceName = $script:TestAddRuleData.DirectByCollectionIdAndResourceName.ResourceName

            # Act & Assert
            { Add-CMASCollectionMembershipRule -CollectionId $collectionId -RuleType Direct -ResourceName $resourceName -Confirm:$false } | Should -Not -Throw
        }

        It "Should verify direct membership rule was added successfully" {
            # Arrange
            $collectionName = $script:TestAddRuleData.DirectByCollectionNameAndResourceId.CollectionName
            $resourceId = $script:TestAddRuleData.DirectByCollectionNameAndResourceId.ResourceId

            # Act
            $rules = Get-CMASCollectionDirectMembershipRule -CollectionName $collectionName -ResourceId $resourceId

            # Assert
            $rules | Should -Not -BeNullOrEmpty
            $rules.ResourceID | Should -Contain $resourceId
        }

        It "Should handle duplicate direct membership rule gracefully" {
            # Arrange
            $collectionName = $script:TestAddRuleData.DirectByCollectionNameAndResourceId.CollectionName
            $resourceId = $script:TestAddRuleData.DirectByCollectionNameAndResourceId.ResourceId

            # Act - Try to add the same rule again, should not throw but should warn
            { Add-CMASCollectionMembershipRule -CollectionName $collectionName -RuleType Direct -ResourceId $resourceId -Confirm:$false -WarningAction SilentlyContinue } | Should -Not -Throw
        }

        It "Should add multiple direct membership rules with ResourceId array" {
            # Arrange
            $collectionName = $script:TestAddRuleData.DirectByCollectionNameAndResourceId.CollectionName
            $resourceIds = $script:TestAddRuleData.DirectByCollectionNameAndResourceId.ResourceIdArray

            # Skip if no array provided
            if (-not $resourceIds) {
                Set-ItResult -Skipped -Because "No ResourceIdArray provided in test data"
                return
            }

            # Act & Assert
            { Add-CMASCollectionMembershipRule -CollectionName $collectionName -RuleType Direct -ResourceId $resourceIds -Confirm:$false } | Should -Not -Throw
        }

        It "Should add direct membership rule via pipeline input" {
            # Arrange
            $collectionName = $script:TestAddRuleData.TestCollection.CollectionName
            $resourceId = $script:TestAddRuleData.DirectByCollectionNameAndResourceId.ResourceId

            # Act & Assert
            { Get-CMASCollection -Name $collectionName | Add-CMASCollectionMembershipRule -RuleType Direct -ResourceId $resourceId -Confirm:$false } | Should -Not -Throw
        }

        It "Should throw error when ResourceId and ResourceName are both missing for Direct rule" {
            # Arrange
            $collectionName = $script:TestAddRuleData.TestCollection.CollectionName

            # Act & Assert
            { Add-CMASCollectionMembershipRule -CollectionName $collectionName -RuleType Direct -Confirm:$false } | Should -Throw
        }
    }

    Context "Adding Query Membership Rules" {

        It "Should add a query membership rule by CollectionName without errors" {
            # Arrange
            $collectionName = $script:TestAddRuleData.QueryByCollectionName.CollectionName
            $ruleName = $script:TestAddRuleData.QueryByCollectionName.RuleName
            $queryExpression = $script:TestAddRuleData.QueryByCollectionName.QueryExpression

            # Act & Assert
            { Add-CMASCollectionMembershipRule -CollectionName $collectionName -RuleType Query -RuleName $ruleName -QueryExpression $queryExpression -Confirm:$false } | Should -Not -Throw
        }

        It "Should verify query membership rule was added successfully" {
            # Arrange
            $collectionName = $script:TestAddRuleData.QueryByCollectionName.CollectionName
            $ruleName = $script:TestAddRuleData.QueryByCollectionName.RuleName

            # Act
            $rules = Get-CMASCollectionQueryMembershipRule -CollectionName $collectionName -RuleName $ruleName

            # Assert
            $rules | Should -Not -BeNullOrEmpty
            $rules[0].RuleName | Should -Be $ruleName
        }

        It "Should handle duplicate query membership rule gracefully" {
            # Arrange
            $collectionName = $script:TestAddRuleData.QueryByCollectionName.CollectionName
            $ruleName = $script:TestAddRuleData.QueryByCollectionName.RuleName
            $queryExpression = $script:TestAddRuleData.QueryByCollectionName.QueryExpression

            # Act - Try to add the same rule again, should not throw but should warn
            { Add-CMASCollectionMembershipRule -CollectionName $collectionName -RuleType Query -RuleName $ruleName -QueryExpression $queryExpression -Confirm:$false -WarningAction SilentlyContinue } | Should -Not -Throw
        }

        It "Should throw error when RuleName is missing for Query rule" {
            # Arrange
            $collectionName = $script:TestAddRuleData.QueryByCollectionName.CollectionName
            $queryExpression = $script:TestAddRuleData.QueryByCollectionName.QueryExpression

            # Act & Assert
            { Add-CMASCollectionMembershipRule -CollectionName $collectionName -RuleType Query -QueryExpression $queryExpression -Confirm:$false } | Should -Throw
        }

        It "Should throw error when QueryExpression is missing for Query rule" {
            # Arrange
            $collectionName = $script:TestAddRuleData.QueryByCollectionName.CollectionName
            $ruleName = $script:TestAddRuleData.QueryByCollectionName.RuleName

            # Act & Assert
            { Add-CMASCollectionMembershipRule -CollectionName $collectionName -RuleType Query -RuleName $ruleName -Confirm:$false } | Should -Throw
        }
    }

    Context "Adding Include Membership Rules" {

        It "Should add an include membership rule by CollectionName without errors" {
            # Arrange
            $collectionName = $script:TestAddRuleData.IncludeByCollectionName.CollectionName
            $includeCollectionName = $script:TestAddRuleData.IncludeByCollectionName.IncludeCollectionName

            # Act & Assert
            { Add-CMASCollectionMembershipRule -CollectionName $collectionName -RuleType Include -IncludeCollectionName $includeCollectionName -Confirm:$false } | Should -Not -Throw
        }

        It "Should verify include membership rule was added successfully" {
            # Arrange
            $collectionName = $script:TestAddRuleData.IncludeByCollectionName.CollectionName
            $includeCollectionName = $script:TestAddRuleData.IncludeByCollectionName.IncludeCollectionName

            # Act
            $rules = Get-CMASCollectionIncludeMembershipRule -CollectionName $collectionName -IncludeCollectionName $includeCollectionName

            # Assert
            $rules | Should -Not -BeNullOrEmpty
        }

        It "Should handle duplicate include membership rule gracefully" {
            # Arrange
            $collectionName = $script:TestAddRuleData.IncludeByCollectionName.CollectionName
            $includeCollectionName = $script:TestAddRuleData.IncludeByCollectionName.IncludeCollectionName

            # Act - Try to add the same rule again, should not throw but should warn
            { Add-CMASCollectionMembershipRule -CollectionName $collectionName -RuleType Include -IncludeCollectionName $includeCollectionName -Confirm:$false -WarningAction SilentlyContinue } | Should -Not -Throw
        }

        It "Should add include membership rule by CollectionId" {
            # Arrange
            $collectionId = $script:TestAddRuleData.IncludeByCollectionName.CollectionId
            $includeCollectionId = $script:TestAddRuleData.IncludeByCollectionName.IncludeCollectionId

            # Skip if no CollectionId provided
            if (-not $collectionId -or -not $includeCollectionId) {
                Set-ItResult -Skipped -Because "No CollectionId or IncludeCollectionId provided in test data"
                return
            }

            # Act & Assert
            { Add-CMASCollectionMembershipRule -CollectionId $collectionId -RuleType Include -IncludeCollectionId $includeCollectionId -Confirm:$false } | Should -Not -Throw
        }

        It "Should throw error when IncludeCollectionName is not found" {
            # Arrange
            $collectionName = $script:TestAddRuleData.TestCollection.CollectionName
            $includeCollectionName = "NonExistent-Collection-999"

            # Act & Assert
            { Add-CMASCollectionMembershipRule -CollectionName $collectionName -RuleType Include -IncludeCollectionName $includeCollectionName -Confirm:$false -ErrorAction Stop } | Should -Throw
        }
    }

    Context "Adding Exclude Membership Rules" {

        It "Should add an exclude membership rule by CollectionName without errors" {
            # Arrange
            $collectionName = $script:TestAddRuleData.ExcludeByCollectionName.CollectionName
            $excludeCollectionName = $script:TestAddRuleData.ExcludeByCollectionName.ExcludeCollectionName

            # Act & Assert
            { Add-CMASCollectionMembershipRule -CollectionName $collectionName -RuleType Exclude -ExcludeCollectionName $excludeCollectionName -Confirm:$false } | Should -Not -Throw
        }

        It "Should verify exclude membership rule was added successfully" {
            # Arrange
            $collectionName = $script:TestAddRuleData.ExcludeByCollectionName.CollectionName
            $excludeCollectionName = $script:TestAddRuleData.ExcludeByCollectionName.ExcludeCollectionName

            # Act
            $rules = Get-CMASCollectionExcludeMembershipRule -CollectionName $collectionName -ExcludeCollectionName $excludeCollectionName

            # Assert
            $rules | Should -Not -BeNullOrEmpty
        }

        It "Should handle duplicate exclude membership rule gracefully" {
            # Arrange
            $collectionName = $script:TestAddRuleData.ExcludeByCollectionName.CollectionName
            $excludeCollectionName = $script:TestAddRuleData.ExcludeByCollectionName.ExcludeCollectionName

            # Act - Try to add the same rule again, should not throw but should warn
            { Add-CMASCollectionMembershipRule -CollectionName $collectionName -RuleType Exclude -ExcludeCollectionName $excludeCollectionName -Confirm:$false -WarningAction SilentlyContinue } | Should -Not -Throw
        }

        It "Should add exclude membership rule by CollectionId" {
            # Arrange
            $collectionId = $script:TestAddRuleData.ExcludeByCollectionName.CollectionId
            $excludeCollectionId = $script:TestAddRuleData.ExcludeByCollectionName.ExcludeCollectionId

            # Skip if no CollectionId provided
            if (-not $collectionId -or -not $excludeCollectionId) {
                Set-ItResult -Skipped -Because "No CollectionId or ExcludeCollectionId provided in test data"
                return
            }

            # Act & Assert
            { Add-CMASCollectionMembershipRule -CollectionId $collectionId -RuleType Exclude -ExcludeCollectionId $excludeCollectionId -Confirm:$false } | Should -Not -Throw
        }
    }

    Context "Parameter Validation and Error Handling" {

        It "Should throw error for non-existent collection name" {
            # Arrange
            $collectionName = "NonExistent-Collection-999"
            $resourceId = 16777220

            # Act & Assert
            { Add-CMASCollectionMembershipRule -CollectionName $collectionName -RuleType Direct -ResourceId $resourceId -Confirm:$false -ErrorAction Stop } | Should -Throw
        }

        It "Should throw error for non-existent collection ID" {
            # Arrange
            $collectionId = "XXX99999"
            $resourceId = 16777220

            # Act & Assert
            { Add-CMASCollectionMembershipRule -CollectionId $collectionId -RuleType Direct -ResourceId $resourceId -Confirm:$false -ErrorAction Stop } | Should -Throw
        }

        It "Should throw error for non-existent resource name" {
            # Arrange
            $collectionName = $script:TestAddRuleData.TestCollection.CollectionName
            $resourceName = "NonExistent-Device-999"

            # Act & Assert
            { Add-CMASCollectionMembershipRule -CollectionName $collectionName -RuleType Direct -ResourceName $resourceName -Confirm:$false -ErrorAction Stop } | Should -Throw
        }

        It "Should support WhatIf parameter" {
            # Arrange
            $collectionName = $script:TestAddRuleData.TestCollection.CollectionName
            $resourceId = 16777220

            # Act & Assert - WhatIf should not throw and should not add rule
            { Add-CMASCollectionMembershipRule -CollectionName $collectionName -RuleType Direct -ResourceId $resourceId -WhatIf } | Should -Not -Throw
        }

        It "Should return updated collection object with PassThru parameter" {
            # Arrange
            $collectionName = $script:TestAddRuleData.TestCollection.CollectionName
            $resourceId = $script:TestAddRuleData.DirectByCollectionNameAndResourceId.ResourceId

            # Act
            $result = Add-CMASCollectionMembershipRule -CollectionName $collectionName -RuleType Direct -ResourceId $resourceId -PassThru -Confirm:$false

            # Assert
            if ($result) {
                $result.CollectionID | Should -Not -BeNullOrEmpty
                Assert-PropertyExists -Object $result -PropertyName "CollectionID"
            }
        }
    }

    Context "Integration with Get-CMASCollection*MembershipRule Functions" {

        It "Should be able to add and retrieve Direct membership rules" {
            # Arrange
            $collectionName = $script:TestAddRuleData.TestCollection.CollectionName
            $resourceId = $script:TestAddRuleData.DirectByCollectionNameAndResourceId.ResourceId

            # Act - Add rule
            Add-CMASCollectionMembershipRule -CollectionName $collectionName -RuleType Direct -ResourceId $resourceId -Confirm:$false

            # Act - Retrieve rule
            $rules = Get-CMASCollectionDirectMembershipRule -CollectionName $collectionName -ResourceId $resourceId

            # Assert
            $rules | Should -Not -BeNullOrEmpty
            $rules.ResourceID | Should -Contain $resourceId
        }

        It "Should be able to add and retrieve Query membership rules" {
            # Arrange
            $collectionName = $script:TestAddRuleData.TestCollection.CollectionName
            $ruleName = "Test-Query-Rule-$((Get-Date).Ticks)"
            $queryExpression = "select SMS_R_SYSTEM.ResourceID from SMS_R_System where SMS_R_System.Name like 'TEST-%'"

            # Act - Add rule
            Add-CMASCollectionMembershipRule -CollectionName $collectionName -RuleType Query -RuleName $ruleName -QueryExpression $queryExpression -Confirm:$false

            # Act - Retrieve rule
            $rules = Get-CMASCollectionQueryMembershipRule -CollectionName $collectionName -RuleName $ruleName

            # Assert
            $rules | Should -Not -BeNullOrEmpty
            $rules[0].RuleName | Should -Be $ruleName
        }
    }
}

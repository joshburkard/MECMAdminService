# Functional Tests for Remove-CMASCollectionMembershipRule
# Tests the Remove-CMASCollectionMembershipRule function behavior and return values
# Test flow: Clean existing rules -> Add rules -> Remove rules

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
    $script:TestRemoveRuleData = $script:TestData['Remove-CMASCollectionMembershipRule']
    $script:TestAddRuleData = $script:TestData['Add-CMASCollectionMembershipRule']
}

Describe "Remove-CMASCollectionMembershipRule Function Tests - Full Workflow" -Tag "Integration", "Collection", "MembershipRule", "Modify" {

    Context "Test Data Validation" {

        It "Should have test data defined in declarations.ps1" {
            # Assert
            $script:TestRemoveRuleData | Should -Not -BeNullOrEmpty
            $script:TestAddRuleData | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('Remove-CMASCollectionMembershipRule') | Should -Be $true
            $script:TestData.ContainsKey('Add-CMASCollectionMembershipRule') | Should -Be $true
        }

        It "Should have required test data parameter sets for Remove" {
            # Assert
            $script:TestRemoveRuleData.ContainsKey('DirectByCollectionNameAndResourceId') | Should -Be $true
            $script:TestRemoveRuleData.ContainsKey('DirectByCollectionIdAndResourceName') | Should -Be $true
            $script:TestRemoveRuleData.ContainsKey('DirectByWildcard') | Should -Be $true
            $script:TestRemoveRuleData.ContainsKey('QueryByCollectionName') | Should -Be $true
            $script:TestRemoveRuleData.ContainsKey('QueryByWildcard') | Should -Be $true
            $script:TestRemoveRuleData.ContainsKey('IncludeByCollectionName') | Should -Be $true
            $script:TestRemoveRuleData.ContainsKey('ExcludeByCollectionName') | Should -Be $true
            $script:TestRemoveRuleData.ContainsKey('TestCollection') | Should -Be $true
        }

        It "Should output test data for verification" {
            # Output test data
            Write-Host "`n=== Test Data for Remove-CMASCollectionMembershipRule ===" -ForegroundColor Cyan
            Write-Host "TestCollection:" -ForegroundColor Yellow
            Write-Host "  CollectionName: $($script:TestRemoveRuleData.TestCollection.CollectionName)" -ForegroundColor White
            Write-Host "  CollectionId: $($script:TestRemoveRuleData.TestCollection.CollectionId)" -ForegroundColor White

            Write-Host "DirectByCollectionNameAndResourceId:" -ForegroundColor Yellow
            Write-Host "  CollectionName: $($script:TestRemoveRuleData.DirectByCollectionNameAndResourceId.CollectionName)" -ForegroundColor White
            Write-Host "  ResourceId: $($script:TestRemoveRuleData.DirectByCollectionNameAndResourceId.ResourceId)" -ForegroundColor White

            Write-Host "DirectByWildcard:" -ForegroundColor Yellow
            Write-Host "  CollectionName: $($script:TestRemoveRuleData.DirectByWildcard.CollectionName)" -ForegroundColor White
            Write-Host "  ResourceName: $($script:TestRemoveRuleData.DirectByWildcard.ResourceName)" -ForegroundColor White

            Write-Host "QueryByCollectionName:" -ForegroundColor Yellow
            Write-Host "  CollectionName: $($script:TestRemoveRuleData.QueryByCollectionName.CollectionName)" -ForegroundColor White
            Write-Host "  RuleName: $($script:TestRemoveRuleData.QueryByCollectionName.RuleName)" -ForegroundColor White

            Write-Host "IncludeByCollectionName:" -ForegroundColor Yellow
            Write-Host "  CollectionName: $($script:TestRemoveRuleData.IncludeByCollectionName.CollectionName)" -ForegroundColor White
            Write-Host "  IncludeCollectionName: $($script:TestRemoveRuleData.IncludeByCollectionName.IncludeCollectionName)" -ForegroundColor White

            Write-Host "ExcludeByCollectionName:" -ForegroundColor Yellow
            Write-Host "  CollectionName: $($script:TestRemoveRuleData.ExcludeByCollectionName.CollectionName)" -ForegroundColor White
            Write-Host "  ExcludeCollectionName: $($script:TestRemoveRuleData.ExcludeByCollectionName.ExcludeCollectionName)" -ForegroundColor White
            Write-Host "============================================================`n" -ForegroundColor Cyan

            # This test always passes, it's just for output
            $true | Should -Be $true
        }
    }

    Context "Step 1: Cleanup - Remove All Existing Membership Rules" {

        It "Should remove all existing direct membership rules from test collection" {
            # Arrange
            $collectionName = $script:TestRemoveRuleData.TestCollection.CollectionName
            $collectionId = $script:TestRemoveRuleData.TestCollection.CollectionId

            # Act - Get all direct rules
            $existingRules = Get-CMASCollectionDirectMembershipRule -CollectionId $collectionId

            if ($existingRules) {
                Write-Host "Found $(@($existingRules).Count) existing direct membership rules. Removing..." -ForegroundColor Yellow
                foreach ($rule in $existingRules) {
                    { Remove-CMASCollectionMembershipRule -CollectionId $collectionId -RuleType Direct -ResourceId $rule.ResourceID -Force -Confirm:$false } | Should -Not -Throw
                }
            } else {
                Write-Host "No existing direct membership rules found." -ForegroundColor Green
            }

            # Assert - Verify all removed
            $remainingRules = Get-CMASCollectionDirectMembershipRule -CollectionId $collectionId
            $remainingRules | Should -BeNullOrEmpty
        }

        It "Should remove all existing query membership rules from test collection" {
            # Arrange
            $collectionId = $script:TestRemoveRuleData.TestCollection.CollectionId

            # Act - Get all query rules
            $existingRules = Get-CMASCollectionQueryMembershipRule -CollectionId $collectionId

            if ($existingRules) {
                Write-Host "Found $(@($existingRules).Count) existing query membership rules. Removing..." -ForegroundColor Yellow
                foreach ($rule in $existingRules) {
                    { Remove-CMASCollectionMembershipRule -CollectionId $collectionId -RuleType Query -RuleName $rule.RuleName -Force -Confirm:$false } | Should -Not -Throw
                }
            } else {
                Write-Host "No existing query membership rules found." -ForegroundColor Green
            }

            # Assert - Verify all removed
            $remainingRules = Get-CMASCollectionQueryMembershipRule -CollectionId $collectionId
            $remainingRules | Should -BeNullOrEmpty
        }

        It "Should remove all existing include membership rules from test collection" {
            # Arrange
            $collectionId = $script:TestRemoveRuleData.TestCollection.CollectionId

            # Act - Get all include rules
            $existingRules = Get-CMASCollectionIncludeMembershipRule -CollectionId $collectionId

            if ($existingRules) {
                Write-Host "Found $(@($existingRules).Count) existing include membership rules. Removing..." -ForegroundColor Yellow
                foreach ($rule in $existingRules) {
                    { Remove-CMASCollectionMembershipRule -CollectionId $collectionId -RuleType Include -IncludeCollectionId $rule.IncludeCollectionID -Force -Confirm:$false } | Should -Not -Throw
                }
            } else {
                Write-Host "No existing include membership rules found." -ForegroundColor Green
            }

            # Assert - Verify all removed
            $remainingRules = Get-CMASCollectionIncludeMembershipRule -CollectionId $collectionId
            $remainingRules | Should -BeNullOrEmpty
        }

        It "Should remove all existing exclude membership rules from test collection" {
            # Arrange
            $collectionId = $script:TestRemoveRuleData.TestCollection.CollectionId

            # Act - Get all exclude rules
            $existingRules = Get-CMASCollectionExcludeMembershipRule -CollectionId $collectionId

            if ($existingRules) {
                Write-Host "Found $(@($existingRules).Count) existing exclude membership rules. Removing..." -ForegroundColor Yellow
                foreach ($rule in $existingRules) {
                    { Remove-CMASCollectionMembershipRule -CollectionId $collectionId -RuleType Exclude -ExcludeCollectionId $rule.ExcludeCollectionID -Force -Confirm:$false } | Should -Not -Throw
                }
            } else {
                Write-Host "No existing exclude membership rules found." -ForegroundColor Green
            }

            # Assert - Verify all removed
            $remainingRules = Get-CMASCollectionExcludeMembershipRule -CollectionId $collectionId
            $remainingRules | Should -BeNullOrEmpty
        }
    }

    Context "Step 2: Add Membership Rules (Execute Add Tests)" {

        It "Should add a direct membership rule by CollectionName and ResourceId" {
            # Arrange
            $collectionName = $script:TestAddRuleData.DirectByCollectionNameAndResourceId.CollectionName
            $resourceId = $script:TestAddRuleData.DirectByCollectionNameAndResourceId.ResourceId

            # Act & Assert
            { Add-CMASCollectionMembershipRule -CollectionName $collectionName -RuleType Direct -ResourceId $resourceId -Confirm:$false } | Should -Not -Throw
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

        It "Should add a direct membership rule by CollectionId and ResourceName" {
            # Arrange
            $collectionId = $script:TestAddRuleData.DirectByCollectionIdAndResourceName.CollectionId
            $resourceName = $script:TestAddRuleData.DirectByCollectionIdAndResourceName.ResourceName

            # Act & Assert
            { Add-CMASCollectionMembershipRule -CollectionId $collectionId -RuleType Direct -ResourceName $resourceName -Confirm:$false } | Should -Not -Throw
        }

        It "Should add multiple direct membership rules with ResourceId array" {
            # Arrange
            $collectionName = $script:TestAddRuleData.DirectByCollectionNameAndResourceId.CollectionName
            $resourceIds = $script:TestAddRuleData.DirectByCollectionNameAndResourceId.ResourceIdArray

            # Skip if no array provided
            if (-not $resourceIds -or $resourceIds.Count -le 1) {
                Set-ItResult -Skipped -Because "No ResourceIdArray with multiple items provided in test data"
                return
            }

            # Act & Assert
            { Add-CMASCollectionMembershipRule -CollectionName $collectionName -RuleType Direct -ResourceId $resourceIds -Confirm:$false } | Should -Not -Throw
        }

        It "Should add a query membership rule by CollectionName" {
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

        It "Should add an include membership rule by CollectionName" {
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

        It "Should add an exclude membership rule by CollectionName" {
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
    }

    Context "Step 3: Remove Direct Membership Rules" {

        It "Should remove a direct membership rule by CollectionName and ResourceId" {
            # Arrange
            $collectionName = $script:TestRemoveRuleData.DirectByCollectionNameAndResourceId.CollectionName
            $resourceId = $script:TestRemoveRuleData.DirectByCollectionNameAndResourceId.ResourceId

            # Act & Assert
            { Remove-CMASCollectionMembershipRule -CollectionName $collectionName -RuleType Direct -ResourceId $resourceId -Force -Confirm:$false } | Should -Not -Throw
        }

        It "Should verify direct membership rule was removed successfully" {
            # Arrange
            $collectionName = $script:TestRemoveRuleData.DirectByCollectionNameAndResourceId.CollectionName
            $resourceId = $script:TestRemoveRuleData.DirectByCollectionNameAndResourceId.ResourceId

            # Act
            $rules = Get-CMASCollectionDirectMembershipRule -CollectionName $collectionName -ResourceId $resourceId

            # Assert
            $rules | Should -BeNullOrEmpty
        }

        It "Should remove a direct membership rule by CollectionId and ResourceName" {
            # Arrange
            $collectionId = $script:TestRemoveRuleData.DirectByCollectionIdAndResourceName.CollectionId
            $resourceName = $script:TestRemoveRuleData.DirectByCollectionIdAndResourceName.ResourceName

            # Act & Assert
            { Remove-CMASCollectionMembershipRule -CollectionId $collectionId -RuleType Direct -ResourceName $resourceName -Force -Confirm:$false } | Should -Not -Throw
        }

        It "Should verify direct membership rule was removed by ResourceName" {
            # Arrange
            $collectionId = $script:TestRemoveRuleData.DirectByCollectionIdAndResourceName.CollectionId
            $resourceName = $script:TestRemoveRuleData.DirectByCollectionIdAndResourceName.ResourceName

            # Act
            $rules = Get-CMASCollectionDirectMembershipRule -CollectionId $collectionId -ResourceName $resourceName

            # Assert
            $rules | Should -BeNullOrEmpty
        }

        It "Should remove multiple direct membership rules with ResourceId array" {
            # Arrange
            $collectionName = $script:TestRemoveRuleData.DirectByCollectionNameAndResourceId.CollectionName
            $resourceIds = $script:TestRemoveRuleData.DirectByCollectionNameAndResourceId.ResourceIdArray

            # Skip if no array provided or only one resource
            if (-not $resourceIds -or $resourceIds.Count -le 1) {
                Set-ItResult -Skipped -Because "No ResourceIdArray with multiple items provided in test data"
                return
            }

            # Act & Assert
            { Remove-CMASCollectionMembershipRule -CollectionName $collectionName -RuleType Direct -ResourceId $resourceIds -Force -Confirm:$false } | Should -Not -Throw
        }

        It "Should handle removing non-existent direct membership rule gracefully" {
            # Arrange
            $collectionName = $script:TestRemoveRuleData.TestCollection.CollectionName
            $nonExistentResourceId = 99999999

            # Act & Assert - Should not throw, but should warn
            { Remove-CMASCollectionMembershipRule -CollectionName $collectionName -RuleType Direct -ResourceId $nonExistentResourceId -Force -Confirm:$false -WarningAction SilentlyContinue } | Should -Not -Throw
        }

        It "Should remove direct membership rules via pipeline input" {
            # Arrange
            $collectionName = $script:TestRemoveRuleData.TestCollection.CollectionName
            $resourceId = $script:TestRemoveRuleData.DirectByCollectionNameAndResourceId.ResourceId

            # Add a rule first
            Add-CMASCollectionMembershipRule -CollectionName $collectionName -RuleType Direct -ResourceId $resourceId -Confirm:$false -WarningAction SilentlyContinue

            # Act & Assert
            { Get-CMASCollection -Name $collectionName | Remove-CMASCollectionMembershipRule -RuleType Direct -ResourceId $resourceId -Force -Confirm:$false } | Should -Not -Throw
        }
    }

    Context "Step 4: Remove Query Membership Rules" {

        It "Should remove a query membership rule by CollectionName and RuleName" {
            # Arrange
            $collectionName = $script:TestRemoveRuleData.QueryByCollectionName.CollectionName
            $ruleName = $script:TestRemoveRuleData.QueryByCollectionName.RuleName

            # Act & Assert
            { Remove-CMASCollectionMembershipRule -CollectionName $collectionName -RuleType Query -RuleName $ruleName -Force -Confirm:$false } | Should -Not -Throw
        }

        It "Should verify query membership rule was removed successfully" {
            # Arrange
            $collectionName = $script:TestRemoveRuleData.QueryByCollectionName.CollectionName
            $ruleName = $script:TestRemoveRuleData.QueryByCollectionName.RuleName

            # Act
            $rules = Get-CMASCollectionQueryMembershipRule -CollectionName $collectionName -RuleName $ruleName

            # Assert
            $rules | Should -BeNullOrEmpty
        }

        It "Should remove query membership rules using wildcard pattern" {
            # Arrange
            $collectionName = $script:TestRemoveRuleData.QueryByWildcard.CollectionName
            $ruleNamePattern = $script:TestRemoveRuleData.QueryByWildcard.RuleName

            # First add some query rules for testing
            $testRuleName1 = "Test-Query-1-$((Get-Date).Ticks)"
            $testRuleName2 = "Test-Query-2-$((Get-Date).Ticks)"
            $queryExpression = "select SMS_R_SYSTEM.ResourceID from SMS_R_System where SMS_R_System.Name like 'TEST-%'"

            Add-CMASCollectionMembershipRule -CollectionName $collectionName -RuleType Query -RuleName $testRuleName1 -QueryExpression $queryExpression -Confirm:$false -WarningAction SilentlyContinue
            Add-CMASCollectionMembershipRule -CollectionName $collectionName -RuleType Query -RuleName $testRuleName2 -QueryExpression $queryExpression -Confirm:$false -WarningAction SilentlyContinue

            # Act & Assert - Remove using wildcard
            { Remove-CMASCollectionMembershipRule -CollectionName $collectionName -RuleType Query -RuleName "Test-Query-*" -Force -Confirm:$false } | Should -Not -Throw

            # Verify removal
            $remainingRules = Get-CMASCollectionQueryMembershipRule -CollectionName $collectionName -RuleName "Test-Query-*"
            $remainingRules | Should -BeNullOrEmpty
        }

        It "Should handle removing non-existent query membership rule gracefully" {
            # Arrange
            $collectionName = $script:TestRemoveRuleData.TestCollection.CollectionName
            $nonExistentRuleName = "NonExistent-Query-Rule-999"

            # Act & Assert - Should not throw, but should warn
            { Remove-CMASCollectionMembershipRule -CollectionName $collectionName -RuleType Query -RuleName $nonExistentRuleName -Force -Confirm:$false -WarningAction SilentlyContinue } | Should -Not -Throw
        }
    }

    Context "Step 5: Remove Include Membership Rules" {

        It "Should remove an include membership rule by CollectionName" {
            # Arrange
            $collectionName = $script:TestRemoveRuleData.IncludeByCollectionName.CollectionName
            $includeCollectionName = $script:TestRemoveRuleData.IncludeByCollectionName.IncludeCollectionName

            # Act & Assert
            { Remove-CMASCollectionMembershipRule -CollectionName $collectionName -RuleType Include -IncludeCollectionName $includeCollectionName -Force -Confirm:$false } | Should -Not -Throw
        }

        It "Should verify include membership rule was removed successfully" {
            # Arrange
            $collectionName = $script:TestRemoveRuleData.IncludeByCollectionName.CollectionName
            $includeCollectionName = $script:TestRemoveRuleData.IncludeByCollectionName.IncludeCollectionName

            # Act
            $rules = Get-CMASCollectionIncludeMembershipRule -CollectionName $collectionName -IncludeCollectionName $includeCollectionName

            # Assert
            $rules | Should -BeNullOrEmpty
        }

        It "Should remove include membership rule by CollectionId" {
            # Arrange
            $collectionId = $script:TestRemoveRuleData.IncludeByCollectionName.CollectionId
            $includeCollectionId = $script:TestRemoveRuleData.IncludeByCollectionName.IncludeCollectionId

            # Skip if no CollectionId provided
            if (-not $collectionId -or -not $includeCollectionId) {
                Set-ItResult -Skipped -Because "No CollectionId or IncludeCollectionId provided in test data"
                return
            }

            # Add the rule first
            Add-CMASCollectionMembershipRule -CollectionId $collectionId -RuleType Include -IncludeCollectionId $includeCollectionId -Confirm:$false -WarningAction SilentlyContinue

            # Act & Assert
            { Remove-CMASCollectionMembershipRule -CollectionId $collectionId -RuleType Include -IncludeCollectionId $includeCollectionId -Force -Confirm:$false } | Should -Not -Throw
        }

        It "Should handle removing non-existent include membership rule gracefully" {
            # Arrange
            $collectionName = $script:TestRemoveRuleData.TestCollection.CollectionName
            $nonExistentCollectionId = "XXX99999"

            # Act & Assert - Should not throw, but should warn
            { Remove-CMASCollectionMembershipRule -CollectionName $collectionName -RuleType Include -IncludeCollectionId $nonExistentCollectionId -Force -Confirm:$false -WarningAction SilentlyContinue -ErrorAction SilentlyContinue } | Should -Not -Throw
        }
    }

    Context "Step 6: Remove Exclude Membership Rules" {

        It "Should remove an exclude membership rule by CollectionName" {
            # Arrange
            $collectionName = $script:TestRemoveRuleData.ExcludeByCollectionName.CollectionName
            $excludeCollectionName = $script:TestRemoveRuleData.ExcludeByCollectionName.ExcludeCollectionName

            # Act & Assert
            { Remove-CMASCollectionMembershipRule -CollectionName $collectionName -RuleType Exclude -ExcludeCollectionName $excludeCollectionName -Force -Confirm:$false } | Should -Not -Throw
        }

        It "Should verify exclude membership rule was removed successfully" {
            # Arrange
            $collectionName = $script:TestRemoveRuleData.ExcludeByCollectionName.CollectionName
            $excludeCollectionName = $script:TestRemoveRuleData.ExcludeByCollectionName.ExcludeCollectionName

            # Act
            $rules = Get-CMASCollectionExcludeMembershipRule -CollectionName $collectionName -ExcludeCollectionName $excludeCollectionName

            # Assert
            $rules | Should -BeNullOrEmpty
        }

        It "Should remove exclude membership rule by CollectionId" {
            # Arrange
            $collectionId = $script:TestRemoveRuleData.ExcludeByCollectionName.CollectionId
            $excludeCollectionId = $script:TestRemoveRuleData.ExcludeByCollectionName.ExcludeCollectionId

            # Skip if no CollectionId provided
            if (-not $collectionId -or -not $excludeCollectionId) {
                Set-ItResult -Skipped -Because "No CollectionId or ExcludeCollectionId provided in test data"
                return
            }

            # Add the rule first
            Add-CMASCollectionMembershipRule -CollectionId $collectionId -RuleType Exclude -ExcludeCollectionId $excludeCollectionId -Confirm:$false -WarningAction SilentlyContinue

            # Act & Assert
            { Remove-CMASCollectionMembershipRule -CollectionId $collectionId -RuleType Exclude -ExcludeCollectionId $excludeCollectionId -Force -Confirm:$false } | Should -Not -Throw
        }
    }

    Context "Parameter Validation and Error Handling" {

        It "Should throw error for non-existent collection name" {
            # Arrange
            $collectionName = "NonExistent-Collection-999"
            $resourceId = 16777220

            # Act & Assert
            { Remove-CMASCollectionMembershipRule -CollectionName $collectionName -RuleType Direct -ResourceId $resourceId -Force -Confirm:$false -ErrorAction Stop } | Should -Throw
        }

        It "Should throw error for non-existent collection ID" {
            # Arrange
            $collectionId = "XXX99999"
            $resourceId = 16777220

            # Act & Assert
            { Remove-CMASCollectionMembershipRule -CollectionId $collectionId -RuleType Direct -ResourceId $resourceId -Force -Confirm:$false -ErrorAction Stop } | Should -Throw
        }

        It "Should throw error when ResourceId and ResourceName are both missing for Direct rule" {
            # Arrange
            $collectionName = $script:TestRemoveRuleData.TestCollection.CollectionName

            # Act & Assert
            { Remove-CMASCollectionMembershipRule -CollectionName $collectionName -RuleType Direct -Force -Confirm:$false } | Should -Throw
        }

        It "Should throw error when RuleName is missing for Query rule" {
            # Arrange
            $collectionName = $script:TestRemoveRuleData.TestCollection.CollectionName

            # Act & Assert
            { Remove-CMASCollectionMembershipRule -CollectionName $collectionName -RuleType Query -Force -Confirm:$false } | Should -Throw
        }

        It "Should support WhatIf parameter" {
            # Arrange
            $collectionName = $script:TestRemoveRuleData.TestCollection.CollectionName
            $resourceId = $script:TestRemoveRuleData.DirectByCollectionNameAndResourceId.ResourceId

            # Add a rule first
            Add-CMASCollectionMembershipRule -CollectionName $collectionName -RuleType Direct -ResourceId $resourceId -Confirm:$false -WarningAction SilentlyContinue

            # Act & Assert - WhatIf should not throw and should not remove rule
            { Remove-CMASCollectionMembershipRule -CollectionName $collectionName -RuleType Direct -ResourceId $resourceId -WhatIf } | Should -Not -Throw

            # Verify rule still exists
            $rules = Get-CMASCollectionDirectMembershipRule -CollectionName $collectionName -ResourceId $resourceId
            $rules | Should -Not -BeNullOrEmpty
        }

        It "Should return updated collection object with PassThru parameter" {
            # Arrange
            $collectionName = $script:TestRemoveRuleData.TestCollection.CollectionName
            $resourceId = $script:TestRemoveRuleData.DirectByCollectionNameAndResourceId.ResourceId

            # Add a rule first
            Add-CMASCollectionMembershipRule -CollectionName $collectionName -RuleType Direct -ResourceId $resourceId -Confirm:$false -WarningAction SilentlyContinue

            # Act
            $result = Remove-CMASCollectionMembershipRule -CollectionName $collectionName -RuleType Direct -ResourceId $resourceId -PassThru -Force -Confirm:$false

            # Assert
            if ($result) {
                $result.CollectionID | Should -Not -BeNullOrEmpty
                Assert-PropertyExists -Object $result -PropertyName "CollectionID"
            }
        }
    }

    Context "Integration and Workflow Tests" {

        It "Should successfully add and remove the same direct membership rule" {
            # Arrange
            $collectionName = $script:TestRemoveRuleData.TestCollection.CollectionName
            $resourceId = $script:TestRemoveRuleData.DirectByCollectionNameAndResourceId.ResourceId

            # Act - Add rule
            Add-CMASCollectionMembershipRule -CollectionName $collectionName -RuleType Direct -ResourceId $resourceId -Confirm:$false -WarningAction SilentlyContinue

            # Verify it was added
            $rules = Get-CMASCollectionDirectMembershipRule -CollectionName $collectionName -ResourceId $resourceId
            $rules | Should -Not -BeNullOrEmpty

            # Act - Remove rule
            Remove-CMASCollectionMembershipRule -CollectionName $collectionName -RuleType Direct -ResourceId $resourceId -Force -Confirm:$false

            # Assert - Verify it was removed
            $rules = Get-CMASCollectionDirectMembershipRule -CollectionName $collectionName -ResourceId $resourceId
            $rules | Should -BeNullOrEmpty
        }

        It "Should successfully add and remove the same query membership rule" {
            # Arrange
            $collectionName = $script:TestRemoveRuleData.TestCollection.CollectionName
            $ruleName = "Test-Query-Rule-$((Get-Date).Ticks)"
            $queryExpression = "select SMS_R_SYSTEM.ResourceID from SMS_R_System where SMS_R_System.Name like 'TEST-%'"

            # Act - Add rule
            Add-CMASCollectionMembershipRule -CollectionName $collectionName -RuleType Query -RuleName $ruleName -QueryExpression $queryExpression -Confirm:$false -WarningAction SilentlyContinue

            # Verify it was added
            $rules = Get-CMASCollectionQueryMembershipRule -CollectionName $collectionName -RuleName $ruleName
            $rules | Should -Not -BeNullOrEmpty

            # Act - Remove rule
            Remove-CMASCollectionMembershipRule -CollectionName $collectionName -RuleType Query -RuleName $ruleName -Force -Confirm:$false

            # Assert - Verify it was removed
            $rules = Get-CMASCollectionQueryMembershipRule -CollectionName $collectionName -RuleName $ruleName
            $rules | Should -BeNullOrEmpty
        }
    }
}

# Functional Tests for Get-CMASCollectionDirectMembershipRule
# Tests the Get-CMASCollectionDirectMembershipRule function behavior and return values

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

Describe "Get-CMASCollectionDirectMembershipRule Function Tests" -Tag "Integration", "Collection", "MembershipRule" {

    Context "Retrieval by CollectionName" {

        It "Should return membership rules when valid CollectionName is provided" {
            # Arrange & Act & Assert
            # Note: Result might be null/empty if no direct membership rules exist
            # The important thing is that the function doesn't throw an error
            { Get-CMASCollectionDirectMembershipRule -CollectionName $script:TestCollectionName } | Should -Not -Throw
        }

        It "Should return membership rules with expected properties when they exist" {
            # Arrange & Act
            $result = Get-CMASCollectionDirectMembershipRule -CollectionName $script:TestCollectionName

            # Assert
            if ($null -ne $result -and @($result).Count -gt 0) {
                Assert-PropertyExists -Object $result[0] -PropertyName "RuleName"
                Assert-PropertyExists -Object $result[0] -PropertyName "ResourceID"
            }
        }

        It "Should filter by ResourceName when both CollectionName and ResourceName are provided" {
            # Arrange & Act
            $result = Get-CMASCollectionDirectMembershipRule -CollectionName $script:TestCollectionName -ResourceName $script:TestDeviceName

            # Assert
            if ($null -ne $result) {
                @($result).Count | Should -BeLessOrEqual 1
                if (@($result).Count -eq 1) {
                    $result.RuleName | Should -Be $script:TestDeviceName
                }
            }
        }

        It "Should handle wildcards in ResourceName parameter" {
            # Arrange
            $wildcardName = "*TEST*"

            # Act
            $result = Get-CMASCollectionDirectMembershipRule -CollectionName $script:TestCollectionName -ResourceName $wildcardName

            # Assert
            # Should not throw and handle wildcards appropriately
            { Get-CMASCollectionDirectMembershipRule -CollectionName $script:TestCollectionName -ResourceName $wildcardName } | Should -Not -Throw
        }

        It "Should return null or empty when collection doesn't exist" {
            # Arrange
            $nonExistentName = if($script:TestNonExistentCollectionName) {
                $script:TestNonExistentCollectionName
            } else {
                "NonExistent Collection 999"
            }

            # Act - Suppress error since function writes error for non-existent collection
            $result = Get-CMASCollectionDirectMembershipRule -CollectionName $nonExistentName -ErrorAction SilentlyContinue

            # Assert
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Retrieval by CollectionId" {

        It "Should return membership rules when valid CollectionId is provided" {
            # Arrange & Act & Assert
            # Note: Result might be null/empty if no direct membership rules exist
            # The important thing is that the function doesn't throw an error
            { Get-CMASCollectionDirectMembershipRule -CollectionId $script:TestCollectionID } | Should -Not -Throw
        }

        It "Should filter by ResourceId when both CollectionId and ResourceId are provided" {
            # Arrange & Act
            $result = Get-CMASCollectionDirectMembershipRule -CollectionId $script:TestCollectionID -ResourceId $script:TestDeviceResourceID

            # Assert
            if ($null -ne $result) {
                @($result).Count | Should -BeLessOrEqual 1
                if (@($result).Count -eq 1) {
                    $result.ResourceID | Should -Be $script:TestDeviceResourceID
                }
            }
        }

        It "Should return same results using CollectionId or CollectionName" {
            # Arrange & Act
            $resultById = Get-CMASCollectionDirectMembershipRule -CollectionId $script:TestCollectionID
            $resultByName = Get-CMASCollectionDirectMembershipRule -CollectionName $script:TestCollectionName

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
            $result = Get-CMASCollectionDirectMembershipRule -CollectionId $nonExistentId -ErrorAction SilentlyContinue

            # Assert
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Retrieval with InputObject" {

        It "Should accept collection object from pipeline" {
            # Arrange & Act & Assert
            # Note: Result might be null/empty if no direct membership rules exist
            # The important thing is that the function doesn't throw an error
            $collection = Get-CMASCollection -CollectionID $script:TestCollectionID
            { $collection | Get-CMASCollectionDirectMembershipRule } | Should -Not -Throw
        }

        It "Should filter by ResourceName when piped with ResourceName parameter" {
            # Arrange & Act
            $collection = Get-CMASCollection -CollectionID $script:TestCollectionID
            $result = $collection | Get-CMASCollectionDirectMembershipRule -ResourceName $script:TestDeviceName

            # Assert
            if ($null -ne $result -and @($result).Count -gt 0) {
                $result[0].RuleName | Should -Match $script:TestDeviceName
            }
        }

        It "Should filter by ResourceId when piped with ResourceId parameter" {
            # Arrange & Act
            $collection = Get-CMASCollection -CollectionID $script:TestCollectionID
            $result = $collection | Get-CMASCollectionDirectMembershipRule -ResourceId $script:TestDeviceResourceID

            # Assert
            if ($null -ne $result) {
                @($result).Count | Should -BeLessOrEqual 1
            }
        }
    }

    Context "Multiple Parameter Combinations" {

        It "Should handle CollectionName with ResourceId combination" {
            # Arrange & Act
            $result = Get-CMASCollectionDirectMembershipRule -CollectionName $script:TestCollectionName -ResourceId $script:TestDeviceResourceID

            # Assert
            # Should not throw
            { Get-CMASCollectionDirectMembershipRule -CollectionName $script:TestCollectionName -ResourceId $script:TestDeviceResourceID } | Should -Not -Throw
        }

        It "Should handle CollectionId with ResourceName combination" {
            # Arrange & Act
            $result = Get-CMASCollectionDirectMembershipRule -CollectionId $script:TestCollectionID -ResourceName $script:TestDeviceName

            # Assert
            # Should not throw
            { Get-CMASCollectionDirectMembershipRule -CollectionId $script:TestCollectionID -ResourceName $script:TestDeviceName } | Should -Not -Throw
        }
    }

    Context "Return Properties" {

        It "Should return objects with standard membership rule properties" {
            # Arrange & Act
            $result = Get-CMASCollectionDirectMembershipRule -CollectionId $script:TestCollectionID | Select-Object -First 1

            # Assert
            if ($null -ne $result) {
                Assert-PropertyExists -Object $result -PropertyName "CollectionID"
                Assert-PropertyExists -Object $result -PropertyName "ResourceID"
                Assert-PropertyExists -Object $result -PropertyName "RuleName"
            }
        }

        It "Should exclude WMI and OData metadata properties" {
            # Arrange & Act
            $result = Get-CMASCollectionDirectMembershipRule -CollectionId $script:TestCollectionID | Select-Object -First 1

            # Assert
            if ($null -ne $result) {
                $result.PSObject.Properties.Name | Where-Object { $_ -like "__*" } | Should -BeNullOrEmpty
                $result.PSObject.Properties.Name | Where-Object { $_ -like "@odata*" } | Should -BeNullOrEmpty
            }
        }
    }

    Context "Error Handling" {

        It "Should handle API errors gracefully" {
            # Arrange - Use invalid characters that might cause API issues
            $invalidName = "Collection`$`$Invalid"

            # Act & Assert
            # Should not throw, but might return empty result
            { Get-CMASCollectionDirectMembershipRule -CollectionName $invalidName -ErrorAction SilentlyContinue } | Should -Not -Throw
        }
    }
}

Describe "Get-CMASCollectionDirectMembershipRule Parameter Validation" -Tag "Unit" {

    Context "Parameter Metadata" {

        It "Should have CollectionName parameter of type String" {
            # Get the command metadata
            $command = Get-Command Get-CMASCollectionDirectMembershipRule
            $param = $command.Parameters['CollectionName']

            # Assert
            $param.ParameterType.Name | Should -Be "String"
        }

        It "Should have CollectionId parameter of type String" {
            # Get the command metadata
            $command = Get-Command Get-CMASCollectionDirectMembershipRule
            $param = $command.Parameters['CollectionId']

            # Assert
            $param.ParameterType.Name | Should -Be "String"
        }

        It "Should have ResourceName parameter of type String" {
            # Get the command metadata
            $command = Get-Command Get-CMASCollectionDirectMembershipRule
            $param = $command.Parameters['ResourceName']

            # Assert
            $param.ParameterType.Name | Should -Be "String"
        }

        It "Should have ResourceId parameter of type Int64" {
            # Get the command metadata
            $command = Get-Command Get-CMASCollectionDirectMembershipRule
            $param = $command.Parameters['ResourceId']

            # Assert
            $param.ParameterType.Name | Should -Be "Int64"
        }

        It "Should accept pipeline input for InputObject parameter" {
            # Get the command metadata
            $command = Get-Command Get-CMASCollectionDirectMembershipRule
            $param = $command.Parameters['InputObject']

            # Assert
            $param.Attributes | Where-Object { $_.ValueFromPipeline } | Should -Not -BeNullOrEmpty
        }

        It "Should have mutually exclusive parameter sets" {
            # Get the command metadata
            $command = Get-Command Get-CMASCollectionDirectMembershipRule
            $parameterSets = $command.ParameterSets

            # Assert - Should have multiple parameter sets for different collection identifier combinations
            $parameterSets.Count | Should -BeGreaterThan 1
        }

        It "Should not support WhatIf parameter (read-only Get function)" {
            # Get the command metadata
            $command = Get-Command Get-CMASCollectionDirectMembershipRule

            # Assert - Get functions are read-only and don't need WhatIf
            $command.Parameters.ContainsKey('WhatIf') | Should -Be $false
        }
    }

    Context "Parameter Set Validation" {

        It "Should not allow CollectionName and CollectionId together" {
            # This should be enforced by parameter sets
            $command = Get-Command Get-CMASCollectionDirectMembershipRule
            $hasConflict = $false

            foreach ($paramSet in $command.ParameterSets) {
                $hasCollectionName = $paramSet.Parameters | Where-Object { $_.Name -eq 'CollectionName' -and $_.IsMandatory }
                $hasCollectionId = $paramSet.Parameters | Where-Object { $_.Name -eq 'CollectionId' -and $_.IsMandatory }

                if ($hasCollectionName -and $hasCollectionId) {
                    $hasConflict = $true
                }
            }

            # Assert - Should not have a parameter set where both are mandatory simultaneously
            $hasConflict | Should -Be $false
        }
    }
}

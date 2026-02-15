# Functional Tests for Get-CMASCollectionMember
# Tests the Get-CMASCollectionMember function behavior and return values

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
    $script:TestCollectionMemberData = $script:TestData['Get-CMASCollectionMember']
}

Describe "Get-CMASCollectionMember Function Tests" -Tag "Integration", "CollectionMember", "Get" {

    Context "Test Data Validation" {

        It "Should have test data defined in declarations.ps1" {
            $script:TestCollectionMemberData | Should -Not -BeNullOrEmpty
            $script:TestData.ContainsKey('Get-CMASCollectionMember') | Should -Be $true
        }

        It "Should have required test data parameter sets" {
            $script:TestCollectionMemberData.ContainsKey('ByCollectionName') | Should -Be $true
            $script:TestCollectionMemberData.ContainsKey('ByCollectionId') | Should -Be $true
            $script:TestCollectionMemberData.ContainsKey('NonExistent') | Should -Be $true
        }

        It "Should output test data for verification" {
            Write-Host "`n=== Test Data for Get-CMASCollectionMember ===" -ForegroundColor Cyan
            Write-Host "ByCollectionName:" -ForegroundColor Yellow
            Write-Host "  CollectionName: $($script:TestCollectionMemberData.ByCollectionName.CollectionName)" -ForegroundColor White
            Write-Host "ByCollectionId:" -ForegroundColor Yellow
            Write-Host "  CollectionId: $($script:TestCollectionMemberData.ByCollectionId.CollectionId)" -ForegroundColor White
            $true | Should -Be $true
        }
    }

    Context "Parameter Validation" {

        It "Should throw error when not connected to Admin Service" {
            $savedConnection = $script:CMASConnection.SiteServer
            $script:CMASConnection.SiteServer = $null

            { Get-CMASCollectionMember -CollectionName "Test" } |
                Should -Throw "*No active connection*"

            $script:CMASConnection.SiteServer = $savedConnection
        }

        It "Should throw error when neither CollectionName nor CollectionId is provided" {
            { Get-CMASCollectionMember } |
                Should -Throw "*CollectionName*CollectionId*InputObject*"
        }
    }

    Context "Get Collection Members by Collection Name" {

        It "Should get members for a collection by name" {
            $testData = $script:TestCollectionMemberData.ByCollectionName

            $result = Get-CMASCollectionMember -CollectionName $testData.CollectionName

            $result | Should -Not -BeNullOrEmpty
            if ($testData.ExpectedMinCount) {
                @($result).Count | Should -BeGreaterOrEqual $testData.ExpectedMinCount
            }
            Assert-PropertyExists -Object $result[0] -PropertyName "CollectionID"
            Assert-PropertyExists -Object $result[0] -PropertyName "ResourceID"
            Assert-PropertyExists -Object $result[0] -PropertyName "Name"
        }

        It "Should add CollectionName to output" {
            $testData = $script:TestCollectionMemberData.ByCollectionName

            $result = Get-CMASCollectionMember -CollectionName $testData.CollectionName

            $result | Should -Not -BeNullOrEmpty
            Assert-PropertyExists -Object $result[0] -PropertyName "CollectionName"
            $result[0].CollectionName | Should -Be $testData.CollectionName
        }
    }

    Context "Get Collection Members by CollectionId" {

        It "Should get members for a collection by CollectionId" {
            $testData = $script:TestCollectionMemberData.ByCollectionId

            $result = Get-CMASCollectionMember -CollectionId $testData.CollectionId

            $result | Should -Not -BeNullOrEmpty
            if ($testData.ExpectedMinCount) {
                @($result).Count | Should -BeGreaterOrEqual $testData.ExpectedMinCount
            }
        }
    }

    Context "Filtering" {

        It "Should support wildcard patterns in ResourceName" {
            $testData = $script:TestCollectionMemberData.ByCollectionNameAndResourceName

            if (-not $testData.ResourceName) {
                Set-ItResult -Skipped -Because "No ResourceName specified in declarations.ps1"
                return
            }

            $result = Get-CMASCollectionMember -CollectionName $testData.CollectionName -ResourceName $testData.ResourceName

            if (-not $result) {
                Set-ItResult -Skipped -Because "No members matched ResourceName filter"
                return
            }

            foreach ($member in $result) {
                $member.Name | Should -BeLike $testData.ResourceName
            }
        }

        It "Should filter by ResourceId" {
            $testData = $script:TestCollectionMemberData.ByCollectionIdAndResourceId

            if (-not $testData.ResourceId) {
                Set-ItResult -Skipped -Because "No ResourceId specified in declarations.ps1"
                return
            }

            $result = Get-CMASCollectionMember -CollectionId $testData.CollectionId -ResourceId $testData.ResourceId

            if (-not $result) {
                Set-ItResult -Skipped -Because "ResourceId not found in collection"
                return
            }

            $result.ResourceID | Should -Be $testData.ResourceId
        }
    }

    Context "Output Properties" {

        It "Should not include WMI or OData metadata" {
            $testData = $script:TestCollectionMemberData.ByCollectionName

            $result = Get-CMASCollectionMember -CollectionName $testData.CollectionName

            $result | Should -Not -BeNullOrEmpty
            Assert-NoMetadataProperties -Object $result[0]
        }
    }
}

AfterAll {
    Write-Verbose "Get-CMASCollectionMember tests completed"
}

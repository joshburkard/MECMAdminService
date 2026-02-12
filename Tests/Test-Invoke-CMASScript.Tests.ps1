# Functional Tests for Invoke-CMASScript
# Tests the Invoke-CMASScript function behavior and return values
#
# ⚠️ WARNING: Some tests in this file will EXECUTE SCRIPTS in your SCCM environment
# These tests are skipped by default unless proper test data is configured in declarations.ps1

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

Describe "Invoke-CMASScript Function Tests" -Tag "Integration", "ScriptExecution" {

    Context "Parameter Validation" {

        It "Should require either ScriptName or ScriptID" {
            # Arrange & Act & Assert
            { Invoke-CMASScript -ResourceId 123 -ErrorAction Stop } | Should -Throw "*Either ScriptName or ScriptID must be specified*"
        }

        It "Should not accept both ScriptName and ScriptID" {
            # Arrange & Act & Assert
            { Invoke-CMASScript -ScriptName "Test" -ScriptID "00000000-0000-0000-0000-000000000000" -ResourceId 123 -ErrorAction Stop } | Should -Throw "*Only one of ScriptName or ScriptID*"
        }

        It "Should require either CollectionId or ResourceId" {
            # Arrange & Act & Assert
            { Invoke-CMASScript -ScriptName "Test" -ErrorAction Stop } | Should -Throw "*Either CollectionId or ResourceId must be specified*"
        }
    }

    Context "Script Lookup" {

        It "Should find script by valid ScriptName" -Skip:($script:TestScriptName -eq "Test-Script") {
            # Arrange
            $skipExecution = $true # We're just testing lookup, not execution

            # Act & Assert - should not throw during script lookup
            # The function will fail later at execution, but lookup should succeed
            try {
                Invoke-CMASScript -ScriptName $script:TestScriptName -ResourceId 999999999 -ErrorAction Stop
            }
            catch {
                # If we get an execution error (not "script not found"), the lookup worked
                $_.Exception.Message | Should -Not -Match "Failed to find script.*$($script:TestScriptName)"
            }
        }

        It "Should fail gracefully when script doesn't exist" {
            # Arrange & Act & Assert
            { Invoke-CMASScript -ScriptName "NonExistentScript-XYZ123" -ResourceId 123 -ErrorAction Stop } | Should -Throw
        }
    }

    Context "Script Execution - Single Device" {

        It "⚠️ Should execute script on single device by ResourceId" -Skip:($script:TestScriptGuid -eq "00000000-0000-0000-0000-000000000000") {
            # ⚠️ WARNING: This test EXECUTES A SCRIPT in SCCM
            # Arrange
            $resourceId = $script:TestTargetResourceID
            $params = @{ $script:TestScriptParameterName = $script:TestScriptParameterValue }

            # Act
            $result = Invoke-CMASScript -ScriptName $script:TestScriptName -ResourceId $resourceId -InputParameters $params

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.OperationId | Should -Not -BeNullOrEmpty
            $result.OperationId | Should -BeOfType [long]
        }

        It "⚠️ Should execute script by ScriptID/GUID" -Skip:($script:TestScriptGuid -eq "00000000-0000-0000-0000-000000000000") {
            # ⚠️ WARNING: This test EXECUTES A SCRIPT in SCCM
            # Arrange
            $resourceId = $script:TestTargetResourceID
            $params = @{ $script:TestScriptParameterName = $script:TestScriptParameterValue }

            # Act
            $result = Invoke-CMASScript -ScriptID $script:TestScriptGuid -ResourceId $resourceId -InputParameters $params

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.OperationId | Should -Not -BeNullOrEmpty
        }

        It "Should return OperationId with expected properties" -Skip:($script:TestScriptGuid -eq "00000000-0000-0000-0000-000000000000") {
            # ⚠️ WARNING: This test EXECUTES A SCRIPT in SCCM
            # Arrange
            $params = @{ $script:TestScriptParameterName = $script:TestScriptParameterValue }

            # Act
            $result = Invoke-CMASScript -ScriptName $script:TestScriptName -ResourceId $script:TestTargetResourceID -InputParameters $params

            # Assert
            Assert-PropertyExists -Object $result -PropertyName "OperationId"
        }
    }

    Context "Script Execution - Multiple Devices" {

        It "Should accept array of ResourceIds" -Skip:($script:TestScriptGuid -eq "00000000-0000-0000-0000-000000000000") {
            # ⚠️ WARNING: This test EXECUTES A SCRIPT in SCCM on MULTIPLE devices
            # Arrange
            $resourceIds = @($script:TestTargetResourceID)
            $params = @{ $script:TestScriptParameterName = $script:TestScriptParameterValue }

            # Act & Assert
            { Invoke-CMASScript -ScriptName $script:TestScriptName -ResourceId $resourceIds -InputParameters $params -ErrorAction Stop } | Should -Not -Throw
        }
    }

    Context "Script Execution - Collection Target" {

        It "Should accept CollectionId parameter" -Skip:($script:TestScriptGuid -eq "00000000-0000-0000-0000-000000000000") {
            # Note: Skipped by default - executing on entire collection is dangerous
            # Arrange
            $collectionId = $script:TestCollectionID

            # Act & Assert
            # Uncommenting below will execute script on ALL devices in collection
            # { Invoke-CMASScript -ScriptName $script:TestScriptName -CollectionId $collectionId -ErrorAction Stop } | Should -Not -Throw

            # For now, just verify the function accepts the parameter
            $command = Get-Command Invoke-CMASScript
            $command.Parameters['CollectionId'] | Should -Not -BeNullOrEmpty
        }
    }

    Context "Script Parameters" {

        It "Should accept InputParameters hashtable" -Skip:($script:TestScriptParameterName -eq "ComputerName") {
            # ⚠️ WARNING: This test EXECUTES A SCRIPT with parameters in SCCM
            # Arrange
            $params = @{
                $script:TestScriptParameterName = $script:TestScriptParameterValue
            }

            # Act & Assert
            { Invoke-CMASScript -ScriptName $script:TestScriptName -ResourceId $script:TestTargetResourceID -InputParameters $params -ErrorAction Stop } | Should -Not -Throw
        }

        It "Should fail when required parameters are missing" -Skip:($script:TestScriptGuid -eq "00000000-0000-0000-0000-000000000000") {
            # Arrange - empty hashtable when script has required parameters
            $params = @{}

            # Act & Assert - should throw because 'Detail' parameter is required
            { Invoke-CMASScript -ScriptName $script:TestScriptName -ResourceId $script:TestTargetResourceID -InputParameters $params -ErrorAction Stop } | Should -Throw "*required parameter*"
        }
    }

    Context "Error Handling" {

        It "Should handle invalid ResourceId gracefully" -Skip:($script:TestScriptGuid -eq "00000000-0000-0000-0000-000000000000") {
            # Arrange
            $invalidResourceId = -1

            # Act & Assert
            # May throw or return error - either is acceptable
            try {
                $result = Invoke-CMASScript -ScriptName $script:TestScriptName -ResourceId $invalidResourceId -ErrorAction Stop
                # If it returns, check it's an error response
                if($result) {
                    $result.Status | Should -Match "error|failed"
                }
            }
            catch {
                # Throwing is also acceptable error handling
                $_.Exception.Message | Should -Not -BeNullOrEmpty
            }
        }

        It "Should handle non-existent CollectionId gracefully" -Skip:($script:TestScriptGuid -eq "00000000-0000-0000-0000-000000000000") {
            # Arrange
            $invalidCollectionId = "XXX99999"

            # Act & Assert
            try {
                $result = Invoke-CMASScript -ScriptName $script:TestScriptName -CollectionId $invalidCollectionId -ErrorAction Stop
                # If it returns, might be an error response
                if($result -and $result.PSObject.Properties['Status']) {
                    $result.Status | Should -Match "error|failed"
                }
            }
            catch {
                # Throwing is acceptable
                $_.Exception.Message | Should -Not -BeNullOrEmpty
            }
        }
    }
}

Describe "Invoke-CMASScript Parameter Validation" -Tag "Unit" {

    Context "Parameter Metadata" {

        It "Should accept string for ScriptName parameter" {
            # Get the command metadata
            $command = Get-Command Invoke-CMASScript
            $param = $command.Parameters['ScriptName']

            # Assert
            $param.ParameterType.Name | Should -Be "String"
        }

        It "Should accept string for ScriptID parameter" {
            # Get the command metadata
            $command = Get-Command Invoke-CMASScript
            $param = $command.Parameters['ScriptID']

            # Assert
            $param.ParameterType.Name | Should -Be "String"
        }

        It "Should accept long array for ResourceId parameter" {
            # Get the command metadata
            $command = Get-Command Invoke-CMASScript
            $param = $command.Parameters['ResourceId']

            # Assert
            $param.ParameterType.Name | Should -Match "Int64\[\]|Long\[\]"
        }

        It "Should accept string for CollectionId parameter" {
            # Get the command metadata
            $command = Get-Command Invoke-CMASScript
            $param = $command.Parameters['CollectionId']

            # Assert
            $param.ParameterType.Name | Should -Be "String"
        }

        It "Should accept hashtable for InputParameters parameter" {
            # Get the command metadata
            $command = Get-Command Invoke-CMASScript
            $param = $command.Parameters['InputParameters']

            # Assert
            $param.ParameterType.Name | Should -Be "Hashtable"
        }

        It "Should have all parameters as optional" {
            # Get the command metadata
            $command = Get-Command Invoke-CMASScript

            # Assert - they're all optional, validation happens inside function
            $command.Parameters['ScriptName'].Attributes.Mandatory | Should -Not -Contain $true
            $command.Parameters['ScriptID'].Attributes.Mandatory | Should -Not -Contain $true
            $command.Parameters['ResourceId'].Attributes.Mandatory | Should -Not -Contain $true
            $command.Parameters['CollectionId'].Attributes.Mandatory | Should -Not -Contain $true
        }
    }
}

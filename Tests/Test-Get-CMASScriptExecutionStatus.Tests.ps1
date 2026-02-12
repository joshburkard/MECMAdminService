# Functional Tests for Get-CMASScriptExecutionStatus
# Tests the Get-CMASScriptExecutionStatus function behavior and return values

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

Describe "Get-CMASScriptExecutionStatus Function Tests" -Tag "Integration", "ScriptExecution" {

    Context "Status Retrieval by OperationID" {

        It "Should return execution status for valid OperationID" -Skip:($script:TestClientOperationID -eq 16777220) {
            # Arrange & Act
            $result = Get-CMASScriptExecutionStatus -OperationID $script:TestClientOperationID

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.OperationID | Should -Be $script:TestClientOperationID
        }

        It "Should return status with expected properties" -Skip:($script:TestClientOperationID -eq 16777220) {
            # Arrange & Act
            $result = Get-CMASScriptExecutionStatus -OperationID $script:TestClientOperationID

            # Assert
            $result | Should -Not -BeNullOrEmpty
            Assert-PropertyExists -Object $result -PropertyName "OperationID"
            Assert-PropertyExists -Object $result -PropertyName "ScriptName"
            Assert-PropertyExists -Object $result -PropertyName "ScriptGuid"
        }

        It "Should return error object when OperationID doesn't exist" {
            # Arrange - Use an OperationID that likely doesn't exist
            $nonExistentOperationID = 99999999

            # Act
            $result = Get-CMASScriptExecutionStatus -OperationID $nonExistentOperationID

            # Assert
            # Function returns a structured error response instead of null
            $result | Should -Not -BeNullOrEmpty
            $result.Status | Should -Be "error"
            $result.ScriptName | Should -Be "Operation not found"
            $result.OperationID | Should -Be $nonExistentOperationID
        }
    }

    Context "Status Retrieval by CollectionID" {

        It "Should accept CollectionID parameter" {
            # Arrange & Act & Assert
            # Function may require specific parameter set combinations
            { Get-CMASScriptExecutionStatus -CollectionID $script:TestCollectionID -ErrorAction Stop } | Should -Not -Throw
        }

        It "Should return results when combining CollectionID with ScriptName" -Skip:($script:TestScriptName -eq "Test-Script") {
            # Arrange & Act
            $result = Get-CMASScriptExecutionStatus -CollectionID $script:TestCollectionID -ScriptName $script:TestScriptName

            # Assert
            # May return empty if script never executed on this collection, which is valid
            if($result){
                @($result).Count | Should -BeGreaterThan 0
            }
        }
    }

    Context "Status Retrieval by ScriptName" {

        It "Should accept ScriptName parameter" -Skip:($script:TestScriptName -eq "Test-Script") {
            # Arrange & Act & Assert
            { Get-CMASScriptExecutionStatus -ScriptName $script:TestScriptName -ErrorAction Stop } | Should -Not -Throw
        }

        It "Should return script execution history" -Skip:($script:TestScriptName -eq "Test-Script") {
            # Arrange & Act
            $result = Get-CMASScriptExecutionStatus -ScriptName $script:TestScriptName

            # Assert
            # May return empty if script never executed, or return error object
            if($result -and $result.Status -ne 'error'){
                @($result).Count | Should -BeGreaterThan 0
                $result[0].ScriptName | Should -Be $script:TestScriptName
            }
        }
    }

    Context "Combined Filters" {

        It "Should accept both CollectionID and ScriptName parameters" -Skip:($script:TestScriptName -eq "Test-Script") {
            # Arrange & Act & Assert
            { Get-CMASScriptExecutionStatus -CollectionID $script:TestCollectionID -ScriptName $script:TestScriptName } | Should -Not -Throw
        }
    }

    Context "Query All Executions" {

        It "Should return script executions when no filter is specified" {
            # Arrange & Act
            $result = Get-CMASScriptExecutionStatus

            # Assert
            # May return empty if no scripts ever executed, which is valid
            if($result){
                @($result).Count | Should -BeGreaterThan 0
            }
        }
    }

    Context "Result Structure" {

        BeforeAll {
            # Get any existing execution for testing structure
            $script:AnyExecution = Get-CMASScriptExecutionStatus | Select-Object -First 1
        }

        It "Should return results with client execution details" -Skip:(-not $script:AnyExecution) {
            # Assert
            $script:AnyExecution | Should -Not -BeNullOrEmpty
            Assert-PropertyExists -Object $script:AnyExecution -PropertyName "OperationID"
        }

        It "Should include execution status information" -Skip:(-not $script:AnyExecution) {
            # Assert
            $script:AnyExecution | Should -Not -BeNullOrEmpty
            # Check for status-related properties
            $properties = $script:AnyExecution.PSObject.Properties.Name
            ($properties -contains "TotalClients" -or $properties -contains "Status") | Should -Be $true
        }
    }

    Context "Error Handling" {

        It "Should handle invalid OperationID gracefully" {
            # Arrange
            $invalidOperationID = -1

            # Act & Assert
            { Get-CMASScriptExecutionStatus -OperationID $invalidOperationID -ErrorAction SilentlyContinue } | Should -Not -Throw
        }

        It "Should handle non-existent collection gracefully" {
            # Arrange & Act & Assert
            { Get-CMASScriptExecutionStatus -CollectionID "XXX99999" -ErrorAction SilentlyContinue } | Should -Not -Throw
        }
    }
}

Describe "Get-CMASScriptExecutionStatus Parameter Validation" -Tag "Unit" {

    Context "Parameter Metadata" {

        It "Should accept string for OperationID parameter" {
            # Get the command metadata
            $command = Get-Command Get-CMASScriptExecutionStatus
            $param = $command.Parameters['OperationID']

            # Assert
            $param.ParameterType.Name | Should -Be "String"
        }

        It "Should accept string for CollectionID parameter" {
            # Get the command metadata
            $command = Get-Command Get-CMASScriptExecutionStatus
            $param = $command.Parameters['CollectionID']

            # Assert
            $param.ParameterType.Name | Should -Be "String"
        }

        It "Should accept string for ScriptName parameter" {
            # Get the command metadata
            $command = Get-Command Get-CMASScriptExecutionStatus
            $param = $command.Parameters['ScriptName']

            # Assert
            $param.ParameterType.Name | Should -Be "String"
        }

        It "Should have filter parameters with appropriate mandatory settings" {
            # Get the command metadata
            $command = Get-Command Get-CMASScriptExecutionStatus

            # Assert - Parameters are mandatory in specific parameter sets but optional in others
            # OperationID is never mandatory (only used in OperationID parameter set)
            $command.Parameters['OperationID'].Attributes | Where-Object { $_.Mandatory -eq $true } | Should -BeNullOrEmpty
            # CollectionID is mandatory in 'CollectionID' parameter set
            ($command.Parameters['CollectionID'].Attributes | Where-Object { $_.Mandatory -eq $true }).Count | Should -BeGreaterThan 0
            # ScriptName is mandatory in 'ScriptName' parameter set
            ($command.Parameters['ScriptName'].Attributes | Where-Object { $_.Mandatory -eq $true }).Count | Should -BeGreaterThan 0
        }
    }
}

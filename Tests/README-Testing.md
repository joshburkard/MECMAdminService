# Testing Guide for SCCMAdminService Module

This guide explains how to set up and run functional tests for the SCCM Admin Service PowerShell module.

## Quick Start

### Run Tests for a Specific Function
```powershell
# Navigate to Tests folder
cd Tests

# Run tests for a specific function
.\Invoke-Test.ps1 -FunctionName "Get-CMASCollection"

# Run with structural tests (naming, documentation, parameters)
.\Invoke-Test.ps1 -FunctionName "Get-CMASCollection" -IncludeStructuralTests

# Run with specific output level
.\Invoke-Test.ps1 -FunctionName "Invoke-CMASScript" -Output Normal

# Run only Unit tests for a function
.\Invoke-Test.ps1 -FunctionName "Get-CMASDevice" -Tag "Unit"
```

### Run All Functional Tests
```powershell
# Run all Test-*.Tests.ps1 files
.\Invoke-Test.ps1

# Run only Integration tests
.\Invoke-Test.ps1 -Tag "Integration"
```

### Run Structural Tests for a Function
Structural tests validate function naming, documentation, and parameter structure:
```powershell
# Run both structural and functional tests for a specific function
.\Invoke-Test.ps1 -FunctionName "Get-CMASCollection" -IncludeStructuralTests
```

Structural tests check:
- ✅ Approved PowerShell verb usage
- ✅ Module prefix in function name
- ✅ SYNOPSIS, DESCRIPTION, and EXAMPLES in help
- ✅ CmdletBinding attribute
- ✅ Parameter help documentation
- ✅ Parameter type declarations

## Test Structure

The Tests folder contains several types of tests:

### 1. **Functions.Tests.ps1** - Structural Tests
This file tests the structure and documentation of all functions:
- Approved PowerShell verbs
- Function naming conventions with module prefix
- Help documentation (SYNOPSIS, DESCRIPTION, EXAMPLES)
- Parameter declarations and types
- CmdletBinding attribute

### 2. **Test-*.Tests.ps1** - Functional Tests (Split by Function)
Individual test files for each function, testing actual behavior and return values:
- **Test-Connect-CMAS.Tests.ps1** ✅ - Connection establishment and credential handling
- **Test-Get-CMASDevice.Tests.ps1** ✅ - Device retrieval and data validation
- **Test-Get-CMASCollection.Tests.ps1** ✅ - Collection queries
- **Test-Get-CMASScript.Tests.ps1** ✅ - Script metadata retrieval
- **Test-Get-CMASScriptExecutionStatus.Tests.ps1** ✅ - Execution status tracking
- **Test-Invoke-CMASScript.Tests.ps1** ⚠️ - Script execution (not yet created - triggers actions in SCCM)

Each test file follows the naming pattern `Test-<FunctionName>.Tests.ps1` and tests:
- Function behavior with valid inputs
- Error handling with invalid inputs
- Return value structure and properties
- Data type validation
- Integration with SCCM Admin Service API

### 3. **TestHelpers.ps1** - Shared Test Utilities
Common functions used across test files:
- `Initialize-TestEnvironment` - Loads declarations and functions
- `Connect-TestEnvironment` - Establishes SCCM connection
- `Assert-PropertyExists` - Helper for property validation
- `Assert-NoMetadataProperties` - Validates metadata exclusion

### 4. **Module.Tests.ps1** - Module-level Tests
Tests the module manifest and overall module structure.

## Integration with Build Process

The test files are automatically invoked during the module build process by **CI/Build-Module.ps1**:

### Build-Time Test Execution Order

1. **Functions.Tests.ps1** (Structural Tests) - **BLOCKING**
   - Runs early in the build process
   - **Must pass** for the build to continue
   - Tests function structure, naming, parameters, and documentation
   - Does not require SCCM connection
   - Failures prevent module assembly

2. **Module Build** (PSM1 and PSD1 creation)
   - Only happens if structural tests pass
   - Combines all functions into module files

3. **Module.Tests.ps1** - **INFORMATIONAL**
   - Runs after successful build
   - Tests the assembled module manifest
   - Does not block the build if it fails

4. **Test-*.Tests.ps1** (Functional Tests) - **OPTIONAL**
   - Automatically discovers all Test-*.Tests.ps1 files
   - Runs at the end if `declarations.ps1` exists
   - Tests actual functionality against SCCM
   - Skipped if `declarations.ps1` is not configured
   - Does not block the build if it fails
   - Provides validation of working functionality
   - Each function has its own test file for focused testing

### Running the Full Build with Tests

```powershell
# Execute the full build process including all tests
.\CI\Build-Module.ps1
```

The build script will:
- Prompt for version and change description
- Run structural tests (must pass)
- Build the module if tests pass
- Run module validation tests (informational)
- Run functional behavior tests based on `$RunAllFunctionalTests` setting:
  - If `$false`: Only tests for changed functions (smart mode - default)
  - If `$true`: All functional tests (full validation mode)

### Smart Test Execution (Default Behavior)

By default, functional tests only run for functions you've modified. This prevents:
- Accidentally triggering script executions in SCCM during routine builds
- Unnecessary API calls when working on unrelated code
- Long test runs when only documentation changed

**How it works:**
1. Build script uses `git diff` to detect changed function files
2. Maps changed functions to their corresponding test files
3. Only runs tests for those specific functions
4. Shows which tests are being skipped

**Example output:**
```
[BUILD] [TEST]  Checking for changed functions since last commit...
[BUILD] [TEST]  Found 1 changed function(s), running 1 test file(s)
           - Test-Get-CMASDevice.Tests.ps1
```

**To run all functional tests:**
Set `$script:RunAllFunctionalTests = $true` in `declarations.ps1`

## Setting Up Test Declarations

### Step 1: Create Your Test Configuration

1. Copy `declarations_sample.ps1` to `declarations.ps1`:
   ```powershell
   Copy-Item -Path ".\Tests\declarations_sample.ps1" -Destination ".\Tests\declarations.ps1"
   ```

2. Edit `declarations.ps1` with your actual test environment values:
   - SCCM site server hostname
   - Test device names and ResourceIDs
   - Test collection IDs
   - Test script GUIDs (if testing script execution)

### Step 2: Add declarations.ps1 to .gitignore

Add the following line to your `.gitignore` file to prevent committing sensitive test data:
```
Tests/declarations.ps1
```

## Test Variables Explained

### Connection Settings
- **TestSiteServer**: Your SCCM site server hostname or FQDN
- **TestCredential**: Credentials for API access (use `$null` for current user)
- **TestSkipCertificateCheck**: Set to `$true` if using self-signed certificates

### Test Execution Control
- **RunAllFunctionalTests**: Controls which functional tests run during build
  - `$false` (default): Only runs tests for functions that changed since last git commit
  - `$true`: Runs all functional tests regardless of changes
  - **Why this matters**: Prevents accidentally triggering script executions or other actions in SCCM during routine builds when only documentation or unrelated code changed

### Device Testing
- **TestDeviceName**: Name of a real device in your environment
- **TestDeviceResourceID**: ResourceID of a real device
- **TestNonExistentDeviceName**: A device name that doesn't exist (for negative testing)

### Collection Testing
- **TestCollectionID**: ID of an existing collection (e.g., "SMS00001" for All Systems)
- **TestCollectionName**: Name of the collection
- **TestNonExistentCollectionID**: A collection ID that doesn't exist

### Script Execution Testing
- **TestScriptGuid**: GUID of a test script in SCCM
- **TestScriptName**: Name of the test script
- **TestClientOperationID**: An existing operation ID for status testing

### Expected Values
- **ExpectedDeviceCount**: Expected number of results when querying by name
- **ExpectedCollectionCount**: Expected number of results when querying by ID

## Running Tests

### Automatic Execution During Build

Tests are automatically executed when running `.\CI\Build-Module.ps1`. See **Integration with Build Process** section above for details.

### Manual Test Execution

You can run tests independently of the build process using either the provided `Invoke-Test.ps1` script or Pester directly.

#### Using Invoke-Test.ps1 (Recommended)

The `Invoke-Test.ps1` script provides a convenient way to run tests with automatic setup:

**Run tests for a specific function:**
```powershell
cd Tests
.\Invoke-Test.ps1 -FunctionName "Get-CMASCollection"
```

**Run all functional tests:**
```powershell
.\Invoke-Test.ps1
```

**Run with different output levels:**
```powershell
# Less verbose
.\Invoke-Test.ps1 -FunctionName "Connect-CMAS" -Output Normal

# More verbose
.\Invoke-Test.ps1 -FunctionName "Invoke-CMASScript" -Output Diagnostic
```

**Filter by tags:**
```powershell
# Run only Integration tests for a function
.\Invoke-Test.ps1 -FunctionName "Get-CMASDevice" -Tag "Integration"

# Run only Unit tests for all functions
.\Invoke-Test.ps1 -Tag "Unit"
```

**Get available functions:**
```powershell
# Run without parameters to see available test files
.\Invoke-Test.ps1 -FunctionName "NonExistent"
```

**Include structural tests:**
```powershell
# Run both structural and functional tests for comprehensive validation
.\Invoke-Test.ps1 -FunctionName "Get-CMASCollection" -IncludeStructuralTests

# Useful before code reviews or releases to ensure code quality
```

#### Using Pester Directly

**Run all tests:**
```powershell
Invoke-Pester -Path .\Tests\
```

**Run structural tests only:**
```powershell
Invoke-Pester -Path .\Tests\Functions.Tests.ps1
```

**Run functional tests only:**
```powershell
Invoke-Pester -Path .\Tests\ -TagFilter "Integration"
```

**Run tests by tag:**
```powershell
# Run only integration tests (require SCCM connection)
Invoke-Pester -Path .\Tests\ -Tag "Integration"

# Run only unit tests (no SCCM connection needed)
Invoke-Pester -Path .\Tests\ -Tag "Unit"
```

**Run tests with detailed output:**
```powershell
Invoke-Pester -Path .\Tests\Test-Get-CMASDevice.Tests.ps1 -Output Detailed
```

**Run specific test file:**
```powershell
# Run tests for a specific function
Invoke-Pester -Path .\Tests\Test-Connect-CMAS.Tests.ps1
```

## Creating New Functional Test Files

When you add a new function to the module, create a corresponding test file following this pattern:

### 1. File Naming Convention
- Pattern: `Test-<FunctionName>.Tests.ps1`
- Example: `Test-Get-CMASDevice.Tests.ps1` for the `Get-CMASDevice` function
- Place in the `Tests/` folder

### 2. Basic Template

```powershell
# Functional Tests for <FunctionName>
# Tests the <FunctionName> function behavior and return values

BeforeAll {
    # Load test environment
    . (Join-Path $PSScriptRoot "TestHelpers.ps1")
    Initialize-TestEnvironment

    # Connect to test environment (if function requires connection)
    Connect-TestEnvironment
}

Describe "<FunctionName> Function Tests" -Tag "Integration", "<Category>" {

    Context "Primary Functionality" {

        It "Should perform expected action with valid inputs" {
            # Arrange
            $inputValue = $script:TestSomeValue

            # Act
            $result = Your-CMASFunction -Parameter $inputValue

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Property | Should -Be "expected-value"
        }

        It "Should return objects with expected properties" {
            # Arrange & Act
            $result = Your-CMASFunction -Parameter $script:TestValue

            # Assert
            Assert-PropertyExists -Object $result -PropertyName "RequiredProperty"
            Assert-NoMetadataProperties -Object $result
        }
    }

    Context "Error Handling" {

        It "Should handle invalid input gracefully" {
            # Arrange
            $invalidInput = "NonExistentValue"

            # Act & Assert
            { Your-CMASFunction -Parameter $invalidInput -ErrorAction Stop } | Should -Throw
        }
    }
}

Describe "<FunctionName> Parameter Validation" -Tag "Unit" {

    Context "Parameter Metadata" {

        It "Should have required parameters marked as mandatory" {
            $command = Get-Command Your-CMASFunction
            $param = $command.Parameters['RequiredParam']

            $param.Attributes.Mandatory | Should -Contain $true
        }

        It "Should accept correct data type for parameter" {
            $command = Get-Command Your-CMASFunction
            $param = $command.Parameters['SomeParam']

            $param.ParameterType.Name | Should -Be "String"
        }
    }
}
```

### 3. Using TestHelpers

The `TestHelpers.ps1` file provides common functions:

```powershell
# Load environment and all functions
Initialize-TestEnvironment

# Connect to SCCM test environment
Connect-TestEnvironment

# Assert property exists on object
Assert-PropertyExists -Object $result -PropertyName "Name"

# Assert no WMI/OData metadata
Assert-NoMetadataProperties -Object $result
```

### 4. Test Discovery

Pester automatically discovers files matching the pattern:
- `*.Tests.ps1` in the Tests folder
- The build script finds all `Test-*.Tests.ps1` files

No need to register new test files - just create them with the right naming pattern!

## Writing Effective Functional Tests

### Arrange-Act-Assert Pattern

Structure each test with three clear sections:

```powershell
It "Should do something specific" {
    # Arrange - Set up test data and preconditions
    $input = $script:TestDeviceName

    # Act - Execute the function being tested
    $result = Get-CMASDevice -Name $input

    # Assert - Verify the results
    $result | Should -Not -BeNullOrEmpty
    $result.Name | Should -Be $input
}
```

### Common Assertions

```powershell
# Check if result exists
$result | Should -Not -BeNullOrEmpty

# Check specific values
$result.Property | Should -Be "expected-value"

# Check types
$result.ResourceID | Should -BeOfType [Int]

# Check if property exists
$result.PSObject.Properties.Name | Should -Contain "PropertyName"

# Check if function throws error
{ Your-CMASFunction -Invalid $param } | Should -Throw

# Check if function doesn't throw
{ Your-CMASFunction -Valid $param } | Should -Not -Throw

# Check arrays
@($result).Count | Should -Be 5

# Check regex patterns
$result.Property | Should -Match "^[A-Z]{3}\d{5}$"
```

### Skip Tests Conditionally

Some tests should only run when specific test data is configured:

```powershell
It "Should execute script" -Skip:($script:TestScriptGuid -eq "00000000-0000-0000-0000-000000000000") {
    # This test only runs if a real script GUID is configured
}
```

### Tags

Use tags to organize tests:
- **Integration**: Tests that require SCCM connection
- **Unit**: Tests that don't require external dependencies
- **Slow**: Tests that take a long time
- **Feature**: Group tests by feature name

```powershell
Describe "Function Tests" -Tag "Integration", "Device" {
    # Tests here
}
```

## Best Practices

1. **Arrange-Act-Assert Pattern**: Organize each test into three clear sections
2. **One Assertion Per Test**: Each `It` block should test one specific behavior
3. **Descriptive Test Names**: Use clear, readable descriptions
4. **Use Test Variables**: Reference `$script:Test*` variables from declarations.ps1
5. **Clean Up**: Use `AfterAll` or `AfterEach` to clean up test data
6. **Mock External Calls**: For unit tests, mock calls to external systems
7. **Test Both Success and Failure**: Test happy path and error conditions

## Example: Testing Return Values

```powershell
Describe "Get-CMASDevice Return Value Tests" {

    BeforeAll {
        Connect-CMAS -SiteServer $script:TestSiteServer
    }

    Context "Return Structure" {

        It "Should return object with required properties" {
            $result = Get-CMASDevice -Name $script:TestDeviceName

            # Test for specific properties
            $result.PSObject.Properties.Name | Should -Contain "Name"
            $result.PSObject.Properties.Name | Should -Contain "ResourceID"
            $result.PSObject.Properties.Name | Should -Contain "LastLogonUserName"
        }

        It "Should exclude WMI metadata properties" {
            $result = Get-CMASDevice -Name $script:TestDeviceName

            # Metadata properties should be filtered out
            $result.PSObject.Properties.Name | Should -Not -Contain "__GENUS"
            $result.PSObject.Properties.Name | Should -Not -Match "@odata"
        }

        It "Should return correct data types" {
            $result = Get-CMASDevice -Name $script:TestDeviceName

            $result.ResourceID | Should -BeOfType [Int]
            $result.Name | Should -BeOfType [String]
        }
    }

    Context "Return Count" {

        It "Should return single device when querying by name" {
            $result = Get-CMASDevice -Name $script:TestDeviceName

            @($result).Count | Should -Be 1
        }

        It "Should return empty result for non-existent device" {
            $result = Get-CMASDevice -Name $script:TestNonExistentDeviceName

            $result | Should -BeNullOrEmpty
        }
    }
}
```

## Troubleshooting

### "declarations.ps1 not found" Warning
- Copy `declarations_sample.ps1` to `declarations.ps1`
- Ensure the file is in the `Tests` folder

### Connection Failures
- Verify `$script:TestSiteServer` is correct
- Check network connectivity to SCCM server
- Verify Admin Service is enabled in SCCM
- Try setting `$script:TestSkipCertificateCheck = $true`

### Test Failures
- Check that test data (device names, ResourceIDs) exists in your environment
- Verify permissions to access SCCM Admin Service
- Review test output for specific error messages
- Use `-Output Detailed` for verbose test results

### Pester Version
This module uses Pester 5.x syntax. Ensure you have Pester 5.2.2 or later:
```powershell
Get-Module Pester -ListAvailable
Install-Module Pester -MinimumVersion 5.2.2 -Force
```

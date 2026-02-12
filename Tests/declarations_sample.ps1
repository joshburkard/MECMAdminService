# Test Declarations Sample
# Copy this file to 'declarations.ps1' and fill in your actual test values
# The 'declarations.ps1' file should be added to .gitignore to avoid committing sensitive data

# SCCM Admin Service Connection Settings
$script:TestSiteServer = "sccm.yourdomain.local"  # Your SCCM site server hostname

# Credential options:
# Option 1: Use current user credentials (no prompt)
$script:TestCredential = $null

# Option 2: Prompt for credentials (only once per PowerShell session)
if(-not $Global:TestCredentialCached){
    # Uncomment the line below to enable credential prompting
    # $Global:TestCredentialCached = Get-Credential -Message "Enter credentials for connecting to the test SCCM environment"
}
$script:TestCredential = $Global:TestCredentialCached

$script:TestSkipCertificateCheck = $true  # Set to $true if using self-signed certificates

# Test Execution Control
# Set to $true to run all functional tests during build
# Set to $false (default) to only run tests for functions that changed since last git commit
# This prevents accidentally triggering script executions or other actions in SCCM during routine builds
$script:RunAllFunctionalTests = $false

# Test Device Information
$script:TestDeviceName = "TEST-DEVICE-001"  # Name of an existing test device in your environment
$script:TestDeviceResourceID = 16777220  # ResourceID of an existing test device
$script:TestNonExistentDeviceName = "NONEXISTENT-DEVICE-999"  # A device name that doesn't exist

# Test Collection Information
$script:TestCollectionID = "SMS00001"  # ID of an existing collection (SMS00001 is "All Systems")
$script:TestCollectionName = "All Systems"  # Name of an existing collection
$script:TestNonExistentCollectionID = "XXX99999"  # A collection ID that doesn't exist
$script:TestNonExistentCollectionName = "NonExistent Collection 999"  # A collection name that doesn't exist

# Test Script Information
$script:TestScriptGuid = "00000000-0000-0000-0000-000000000000"  # GUID of an existing script in your environment
$script:TestScriptName = "Test-Script"  # Name of an existing script
$script:TestScriptParameterName = "ComputerName"  # Parameter name if your test script has parameters
$script:TestScriptParameterValue = "localhost"  # Parameter value for testing

# Test Script Execution
$script:TestClientOperationID = 16777220  # ID of an existing script execution for status testing
$script:TestTargetResourceID = 16777220  # ResourceID used for script execution testing

# Expected Values
$script:ExpectedDeviceCount = 1  # Expected number of devices when querying by specific name
$script:ExpectedCollectionCount = 1  # Expected number of collections when querying by specific ID

# Timeout Settings
$script:TestTimeout = 300  # Timeout in seconds for script execution tests
$script:TestPollingInterval = 5  # Polling interval in seconds for status checks

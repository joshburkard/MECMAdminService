# ============================================================================
# Test Declarations - Structured Approach
# ============================================================================
# Copy this file to 'declarations.ps1' and fill in your actual test values
# The 'declarations.ps1' file should be added to .gitignore to avoid committing sensitive data

#region Global Connection Settings
# SCCM Admin Service Connection
$script:CMASConnection = @{
    SiteServer              = "sccm.yourdomain.local"  # Your SCCM site server hostname
    Credential              = $null                    # Will be set below if needed
    SkipCertificateCheck    = $true                   # Set to $true if using self-signed certificates
}

# Credential options:
# Option 1: Use current user credentials (no prompt) - leave Credential as $null above
# Option 2: Prompt for credentials (uncomment below)
if(-not $Global:TestCredentialCached){
    # Uncomment the line below to enable credential prompting
    # $Global:TestCredentialCached = Get-Credential -Message "Enter credentials for connecting to the test SCCM environment"
}
$script:CMASConnection.Credential = $Global:TestCredentialCached

#endregion

#region Test Execution Control
# Set to $true to run all functional tests during build
# Set to $false (default) to only run tests for functions that changed since last git commit
# This prevents accidentally triggering script executions or other actions in SCCM during routine builds
$script:RunAllFunctionalTests = $false

# Timeout Settings
$script:TestTimeout = 300  # Timeout in seconds for script execution tests
$script:TestPollingInterval = 5  # Polling interval in seconds for status checks
#endregion

#region Test Data by Function
# Organized hashtable structure: Function -> ParameterSet -> Parameters -> Values
# This makes it easy to add new functions and parameter sets

$script:TestData = @{

    # ========================================================================
    # Connect-CMAS
    # ========================================================================
    'Connect-CMAS' = @{
        Valid = @{
            SiteServer = $script:CMASConnection.SiteServer
            Credential = $script:CMASConnection.Credential
            SkipCertificateCheck = $script:CMASConnection.SkipCertificateCheck
        }
        Invalid = @{
            SiteServer = "invalid-server.invalid.local"
        }
    }

    # ========================================================================
    # Get-CMASDevice
    # ========================================================================
    'Get-CMASDevice' = @{
        ByName = @{
            Name = "TEST-DEVICE-001"  # Replace with an existing device name
            ExpectedCount = 1
        }
        ByResourceId = @{
            ResourceId = 16777220  # Replace with an existing device ResourceID
            ExpectedCount = 1
        }
        ByWildcard = @{
            Name = "TEST-*"  # Wildcard pattern
            ExpectedMinCount = 1
        }
        NonExistent = @{
            Name = "NONEXISTENT-DEVICE-999"
            ExpectedCount = 0
        }
        All = @{
            ExpectedMinCount = 1  # At least 1 device should exist
        }
    }

    # ========================================================================
    # Get-CMASCollection
    # ========================================================================
    'Get-CMASCollection' = @{
        ByName = @{
            Name = "All Systems"
            ExpectedCount = 1
        }
        ByCollectionID = @{
            CollectionID = "SMS00001"  # "All Systems" collection
            ExpectedCount = 1
        }
        NonExistent = @{
            Name = "NonExistent Collection 999"
            CollectionID = "XXX99999"
            ExpectedCount = 0
        }
        All = @{
            ExpectedMinCount = 1  # At least 1 collection should exist
        }
    }

    # ========================================================================
    # Get-CMASCollectionDirectMembershipRule
    # ========================================================================
    'Get-CMASCollectionDirectMembershipRule' = @{
        ByCollectionName = @{
            CollectionName = "All Systems"
            # May return empty if no direct membership rules exist
        }
        ByCollectionId = @{
            CollectionId = "SMS00001"
            # May return empty if no direct membership rules exist
        }
        ByCollectionNameAndResourceName = @{
            CollectionName = "All Systems"
            ResourceName = "TEST-DEVICE-001"  # Replace with device that's directly added
        }
        ByCollectionIdAndResourceId = @{
            CollectionId = "SMS00001"
            ResourceId = 16777220  # Replace with ResourceID directly added
        }
        WithWildcard = @{
            CollectionName = "All Systems"
            ResourceName = "TEST-*"
        }
        NonExistent = @{
            CollectionName = "NonExistent Collection 999"
            CollectionId = "XXX99999"
        }
    }

    # ========================================================================
    # Get-CMASCollectionExcludeMembershipRule
    # ========================================================================
    'Get-CMASCollectionExcludeMembershipRule' = @{
        ByCollectionName = @{
            CollectionName = "All Systems"
            # May return empty if no exclude rules exist
        }
        ByCollectionId = @{
            CollectionId = "SMS00001"
            # May return empty if no exclude rules exist
        }
        ByCollectionNameAndExcludeName = @{
            CollectionName = "All Systems"
            ExcludeCollectionName = "Test Exclude Collection"  # Replace with actual excluded collection
        }
        ByCollectionIdAndExcludeId = @{
            CollectionId = "SMS00001"
            ExcludeCollectionId = "SMS00002"  # Replace with actual excluded collection ID
        }
        WithWildcard = @{
            CollectionName = "All Systems"
            ExcludeCollectionName = "TEST-*"
        }
        NonExistent = @{
            CollectionName = "NonExistent Collection 999"
            CollectionId = "XXX99999"
        }
    }

    # ========================================================================
    # Get-CMASScript
    # ========================================================================
    'Get-CMASScript' = @{
        ByName = @{
            ScriptName = "Test-Script"  # Replace with an existing script name
            ExpectedCount = 1
        }
        ByGuid = @{
            ScriptGuid = "00000000-0000-0000-0000-000000000000"  # Replace with actual script GUID
            ExpectedCount = 1
        }
        NonExistent = @{
            ScriptName = "NonExistent-Script-999"
            ExpectedCount = 0
        }
        All = @{
            ExpectedMinCount = 0  # May have no scripts
        }
    }

    # ========================================================================
    # Invoke-CMASScript
    # ========================================================================
    'Invoke-CMASScript' = @{
        ByScriptNameAndDeviceName = @{
            ScriptName = "Test-Script"
            DeviceName = "TEST-DEVICE-001"
            ScriptParameters = @{
                ComputerName = "localhost"
            }
        }
        ByScriptGuidAndResourceId = @{
            ScriptGuid = "00000000-0000-0000-0000-000000000000"
            ResourceId = 16777220
            ScriptParameters = @{
                ComputerName = "localhost"
            }
        }
        ByScriptNameAndCollectionId = @{
            ScriptName = "Test-Script"
            CollectionId = "SMS00001"
            ScriptParameters = @{}
        }
    }

    # ========================================================================
    # Get-CMASScriptExecutionStatus
    # ========================================================================
    'Get-CMASScriptExecutionStatus' = @{
        ByClientOperationId = @{
            ClientOperationId = 16777220  # Replace with actual operation ID from a script execution
        }
        ByScriptGuidAndResourceId = @{
            ScriptGuid = "00000000-0000-0000-0000-000000000000"
            TargetResourceId = 16777220
        }
        NonExistent = @{
            ClientOperationId = 999999999
        }
    }
}
#endregion

#region Helper Functions for Tests
# Helper function to get test data for a specific function and parameter set
function Get-TestData {
    param(
        [string]$FunctionName,
        [string]$ParameterSet
    )

    if ($script:TestData.ContainsKey($FunctionName)) {
        if ($script:TestData[$FunctionName].ContainsKey($ParameterSet)) {
            return $script:TestData[$FunctionName][$ParameterSet]
        }
    }
    return $null
}

# Helper function to check if test data exists for a function
function Test-HasTestData {
    param(
        [string]$FunctionName,
        [string]$ParameterSet = $null
    )

    if ($script:TestData.ContainsKey($FunctionName)) {
        if ($null -eq $ParameterSet) {
            return $true
        }
        return $script:TestData[$FunctionName].ContainsKey($ParameterSet)
    }
    return $false
}
#endregion

#region Backward Compatibility (Optional - for existing tests)
# Keep old variable names for backward compatibility with existing tests
# Remove this section once all tests are migrated to use $script:TestData

$script:TestSiteServer = $script:CMASConnection.SiteServer
$script:TestCredential = $script:CMASConnection.Credential
$script:TestSkipCertificateCheck = $script:CMASConnection.SkipCertificateCheck

$script:TestDeviceName = $script:TestData['Get-CMASDevice'].ByName.Name
$script:TestDeviceResourceID = $script:TestData['Get-CMASDevice'].ByResourceId.ResourceId
$script:TestNonExistentDeviceName = $script:TestData['Get-CMASDevice'].NonExistent.Name

$script:TestCollectionID = $script:TestData['Get-CMASCollection'].ByCollectionID.CollectionID
$script:TestCollectionName = $script:TestData['Get-CMASCollection'].ByName.Name
$script:TestNonExistentCollectionID = $script:TestData['Get-CMASCollection'].NonExistent.CollectionID
$script:TestNonExistentCollectionName = $script:TestData['Get-CMASCollection'].NonExistent.Name

$script:TestScriptGuid = $script:TestData['Get-CMASScript'].ByGuid.ScriptGuid
$script:TestScriptName = $script:TestData['Get-CMASScript'].ByName.ScriptName

$script:TestClientOperationID = $script:TestData['Get-CMASScriptExecutionStatus'].ByClientOperationId.ClientOperationId
$script:TestTargetResourceID = $script:TestData['Invoke-CMASScript'].ByScriptGuidAndResourceId.ResourceId

$script:ExpectedDeviceCount = $script:TestData['Get-CMASDevice'].ByName.ExpectedCount
$script:ExpectedCollectionCount = $script:TestData['Get-CMASCollection'].ByName.ExpectedCount

$script:TestScriptParameterName = "ComputerName"
$script:TestScriptParameterValue = "localhost"
#endregion

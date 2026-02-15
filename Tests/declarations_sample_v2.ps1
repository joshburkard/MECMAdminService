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
    # Get-CMASCollectionIncludeMembershipRule
    # ========================================================================
    'Get-CMASCollectionIncludeMembershipRule' = @{
        ByCollectionName = @{
            CollectionName = "Test-Collection-Include"  # Replace with collection that has include rules
            # May return empty if no include rules exist
        }
        ByCollectionId = @{
            CollectionId = "SMS00101"  # Replace with actual collection ID
            # May return empty if no include rules exist
        }
        ByCollectionNameAndIncludeName = @{
            CollectionName = "Test-Collection-Include"
            IncludeCollectionName = "Test-Collection-Direct"  # Replace with actual included collection
        }
        ByCollectionIdAndIncludeId = @{
            CollectionId = "SMS00101"
            IncludeCollectionId = "SMS00100"  # Replace with actual included collection ID
        }
        WithWildcard = @{
            CollectionName = "Test-Collection-Include"
            IncludeCollectionName = "TEST-*"
        }
        NonExistent = @{
            CollectionName = "NonExistent Collection 999"
            CollectionId = "XXX99999"
        }
    }

    # ========================================================================
    # Get-CMASCollectionQueryMembershipRule
    # ========================================================================
    'Get-CMASCollectionQueryMembershipRule' = @{
        ByCollectionName = @{
            CollectionName = "Test-Collection-Query"  # Replace with collection that has query rules
            # May return empty if no query rules exist
        }
        ByCollectionId = @{
            CollectionId = "SMS00102"  # Replace with actual collection ID
            # May return empty if no query rules exist
        }
        ByCollectionNameAndRuleName = @{
            CollectionName = "Test-Collection-Query"
            RuleName = "Test-Servers"  # Replace with actual query rule name
        }
        ByCollectionIdAndRuleName = @{
            CollectionId = "SMS00102"
            RuleName = "Test-Servers"  # Replace with actual query rule name
        }
        WithWildcard = @{
            CollectionName = "Test-Collection-Query"
            RuleName = "*Server*"
        }
        NonExistent = @{
            CollectionName = "NonExistent Collection 999"
            CollectionId = "XXX99999"
        }
    }

    # ========================================================================
    # Add-CMASCollectionMembershipRule
    # ========================================================================
    'Add-CMASCollectionMembershipRule' = @{
        TestCollection = @{
            CollectionName = "Test-Collection-Rules"  # Replace with test collection name
            CollectionId = "SMS00104"  # Replace with test collection ID
        }
        DirectByCollectionNameAndResourceId = @{
            CollectionName = "Test-Collection-Rules"
            ResourceId = 16777220  # Replace with actual ResourceID to add
            ResourceIdArray = @(16777220, 16777221)  # Optional: Array for multi-add tests
        }
        DirectByCollectionIdAndResourceName = @{
            CollectionId = "SMS00104"
            ResourceName = "TEST-DEVICE-001"  # Replace with actual device name
        }
        QueryByCollectionName = @{
            CollectionName = "Test-Collection-Rules"
            RuleName = "Test-Query-Rule"  # Replace with unique rule name
            QueryExpression = "select SMS_R_SYSTEM.ResourceID from SMS_R_System where SMS_R_System.Name like 'TEST-%'"
        }
        IncludeByCollectionName = @{
            CollectionName = "Test-Collection-Rules"
            CollectionId = "SMS00104"  # Optional: for testing by ID
            IncludeCollectionName = "Test-Collection-Query"  # Replace with collection to include
            IncludeCollectionId = "SMS00102"  # Optional: for testing by ID
        }
        ExcludeByCollectionName = @{
            CollectionName = "Test-Collection-Rules"
            CollectionId = "SMS00104"  # Optional: for testing by ID
            ExcludeCollectionName = "Test-Collection-Direct"  # Replace with collection to exclude
            ExcludeCollectionId = "SMS00100"  # Optional: for testing by ID
        }
    }

    # ========================================================================
    # Remove-CMASCollectionMembershipRule
    # ========================================================================
    'Remove-CMASCollectionMembershipRule' = @{
        TestCollection = @{
            CollectionName = "Test-Collection-Rules"  # Replace with test collection name
            CollectionId = "SMS00104"  # Replace with test collection ID
        }
        DirectByCollectionNameAndResourceId = @{
            CollectionName = "Test-Collection-Rules"
            ResourceId = 16777220  # Replace with actual ResourceID to remove
            ResourceIdArray = @(16777220, 16777221)  # Optional: Array for multi-remove tests
        }
        DirectByCollectionIdAndResourceName = @{
            CollectionId = "SMS00104"
            ResourceName = "TEST-DEVICE-001"  # Replace with actual device name
        }
        DirectByWildcard = @{
            CollectionName = "Test-Collection-Rules"
            ResourceName = "TEST-*"  # Wildcard pattern for batch removal
        }
        QueryByCollectionName = @{
            CollectionName = "Test-Collection-Rules"
            RuleName = "Test-Query-Rule"  # Replace with query rule name
        }
        QueryByWildcard = @{
            CollectionName = "Test-Collection-Rules"
            RuleName = "*Query*"  # Wildcard pattern for batch removal
        }
        IncludeByCollectionName = @{
            CollectionName = "Test-Collection-Rules"
            CollectionId = "SMS00104"  # Optional: for testing by ID
            IncludeCollectionName = "Test-Collection-Query"  # Replace with collection to remove
            IncludeCollectionId = "SMS00102"  # Optional: for testing by ID
        }
        ExcludeByCollectionName = @{
            CollectionName = "Test-Collection-Rules"
            CollectionId = "SMS00104"  # Optional: for testing by ID
            ExcludeCollectionName = "Test-Collection-Direct"  # Replace with collection to remove
            ExcludeCollectionId = "SMS00100"  # Optional: for testing by ID
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

    # ========================================================================
    # New-CMASCollection
    # ========================================================================
    'New-CMASCollection' = @{
        DeviceCollectionByLimitingId = @{
            Name = "Test-DeviceCollection-ByID"
            LimitingCollectionId = "SMS00001"  # All Systems
        }
        DeviceCollectionByLimitingName = @{
            Name = "Test-DeviceCollection-ByName"
            LimitingCollectionName = "All Systems"
        }
        UserCollection = @{
            Name = "Test-UserCollection"
            CollectionType = "User"
            LimitingCollectionId = "SMS00002"  # All Users - Replace with your limiting collection for users
            LimitingCollectionName = "All Users"
        }
        WithComment = @{
            Name = "Test-Collection-WithComment"
            LimitingCollectionId = "SMS00001"
            Comment = "This is a test collection created by automated tests"
        }
        WithPeriodicRefresh = @{
            Name = "Test-Collection-PeriodicRefresh"
            LimitingCollectionId = "SMS00001"
            RefreshType = "Periodic"
        }
        WithContinuousRefresh = @{
            Name = "Test-Collection-ContinuousRefresh"
            LimitingCollectionId = "SMS00001"
            RefreshType = "Continuous"
        }
        WithBothRefresh = @{
            Name = "Test-Collection-BothRefresh"
            LimitingCollectionId = "SMS00001"
            RefreshType = "Both"
        }
    }

    # ========================================================================
    # Remove-CMASCollection
    # ========================================================================
    'Remove-CMASCollection' = @{
        ByName = @{
            # Note: Test collections will be created dynamically during tests
            # This ensures we don't accidentally delete real collections
            CollectionNamePattern = "Test-Remove-Collection-*"
        }
        ById = @{
            # Note: Test collections will be created dynamically during tests
            # CollectionId will be determined at test runtime
        }
        WithMembers = @{
            # Note: Test collection with members will be created dynamically
            # to test warning messages about member count
            CreateWithMembers = $true
        }
        Protected = @{
            # These collections should never be deletable
            ProtectedCollections = @("SMS00001", "SMS00002", "SMS00003", "SMS00004")
        }
    }

    # ========================================================================
    # Set-CMASCollection
    # ========================================================================
    'Set-CMASCollection' = @{
        UpdateName = @{
            # Note: Test collection will be created dynamically during tests
            OriginalName = "Test-Set-Collection-Original"
            NewName = "Test-Set-Collection-Updated"
        }
        UpdateComment = @{
            # Note: Test collection will be created dynamically during tests
            CollectionName = "Test-Set-Collection-Comment"
            Comment = "Updated comment via automated tests"
        }
        UpdateRefreshType = @{
            # Note: Test collection will be created dynamically during tests
            CollectionName = "Test-Set-Collection-RefreshType"
            OriginalRefreshType = "Manual"
            NewRefreshType = "Continuous"
        }
        UpdateRefreshSchedule = @{
            # Note: Test collection will be created dynamically during tests
            CollectionName = "Test-Set-Collection-Schedule"
            RefreshType = "Periodic"
            RefreshSchedule = @{
                DaySpan = 1
                StartTime = "2025-02-14T00:00:00Z"
            }
        }
        UpdateMultipleProperties = @{
            # Note: Test collection will be created dynamically during tests
            CollectionName = "Test-Set-Collection-Multiple"
            NewName = "Test-Set-Collection-Multiple-Updated"
            Comment = "Multiple properties updated"
            RefreshType = "Both"
        }
        ByCollectionId = @{
            # Note: Test collection will be created dynamically during tests
            # CollectionId will be determined at test runtime
        }
        ByInputObject = @{
            # Note: Test collection will be created dynamically during tests
            # Collection object will be retrieved at test runtime
        }
    }

    # ========================================================================
    # Set-CMASCollectionSchedule
    # ========================================================================
    'Set-CMASCollectionSchedule' = @{
        DailySchedule = @{
            CollectionName = "Test-Schedule-Daily"
            RecurInterval = "Days"
            RecurCount = 1
        }
        HourlySchedule = @{
            CollectionName = "Test-Schedule-Hourly"
            RecurInterval = "Hours"
            RecurCount = 4
        }
        MinuteSchedule = @{
            CollectionName = "Test-Schedule-Minute"
            RecurInterval = "Minutes"
            RecurCount = 30
        }
    }

    # ========================================================================
    # Invoke-CMASCollectionUpdate
    # ========================================================================
    'Invoke-CMASCollectionUpdate' = @{
        ByCollectionName = @{
            CollectionName = "All Systems"
            ExpectedSuccess = $true
        }
        ByCollectionId = @{
            CollectionId = "SMS00001"  # All Systems
            ExpectedSuccess = $true
        }
        NonExistent = @{
            CollectionName = "NonExistent-Collection-XYZ999"
            CollectionId = "XXX99999"
            ExpectedSuccess = $false
        }
    }

    # ========================================================================
    # Get-CMASCollectionVariable
    # ========================================================================
    'Get-CMASCollectionVariable' = @{
        ByCollectionName = @{
            CollectionName = "Test-Collection-WithVariables"  # Collection with variables
            ExpectedMinCount = 1  # Should have at least 1 variable
        }
        ByCollectionId = @{
            CollectionId = "SMS00100"  # Replace with CollectionID of collection with variables
            ExpectedMinCount = 1
        }
        ByCollectionNameAndVariableName = @{
            CollectionName = "Test-Collection-WithVariables"
            VariableName = "TestVar"  # Replace with existing variable
        }
        ByCollectionIdAndVariableName = @{
            CollectionId = "SMS00100"
            VariableName = "TestMaskedVar"  # Replace with existing masked variable
        }
        ByWildcard = @{
            CollectionName = "Test-Collection-WithVariables"
            VariableName = "Test*"  # Wildcard pattern to match test variables
        }
        NonExistentCollection = @{
            CollectionName = "NONEXISTENT-COLLECTION-999"
            ExpectedCount = 0
        }
        NonExistentVariable = @{
            CollectionName = "Test-Collection-WithVariables"
            VariableName = "NonExistentVar999"
            ExpectedCount = 0
        }
        CollectionWithoutVariables = @{
            # If you have a collection without variables, specify it here
            # Otherwise this test will be skipped
            CollectionName = "All Systems"  # All Systems typically has no variables
            CollectionId = "SMS00001"
        }
    }

    # ========================================================================
    # New-CMASCollectionVariable
    # ========================================================================
    'New-CMASCollectionVariable' = @{
        ByCollectionName = @{
            CollectionName = "Test-Collection-WithVariables"  # Existing test collection
            VariableName = "TestCollVar"  # Will be made unique with timestamp in tests
            VariableValue = "TestCollValue123"
        }
        ByCollectionId = @{
            CollectionId = "SMS00100"  # Replace with test collection ID
            VariableName = "TestCollVar_CollID"  # Will be made unique with timestamp in tests
            VariableValue = "TestValueByCollID"
        }
        WithSpecialChars = @{
            CollectionName = "Test-Collection-WithVariables"
            VariableName = "TestCollVar_Special"  # Will be made unique with timestamp in tests
            VariableValue = "C:\\Windows\\System32;D:\\Apps"
        }
        MaskedVariable = @{
            CollectionName = "Test-Collection-WithVariables"
            VariableName = "TestCollVar_Masked"  # Will be made unique with timestamp in tests
            VariableValue = "SecretCollValue123"
            IsMasked = $true
        }
        EmptyValue = @{
            CollectionName = "Test-Collection-WithVariables"
            VariableName = "TestCollVar_Empty"  # Will be made unique with timestamp in tests
            VariableValue = ""
        }
        NonExistentCollection = @{
            CollectionName = "NONEXISTENT-COLLECTION-999"
            VariableName = "TestCollVar_NoCollection"
            VariableValue = "ShouldFail"
        }
        InvalidVariableName = @{
            CollectionName = "Test-Collection-WithVariables"
            VariableName = "Test Coll Var Invalid"  # Spaces not allowed - should fail validation
            VariableValue = "ShouldFail"
        }
    }

    # ========================================================================
    # Remove-CMASCollectionVariable
    # ========================================================================
    'Remove-CMASCollectionVariable' = @{
        ByCollectionName = @{
            CollectionName = "Test-Collection-Direct"  # Replace with test collection name
            VariableName = "TestCollVar_Remove"  # Will be made unique with timestamp in tests
        }
        ByCollectionId = @{
            CollectionId = "SMS00100"  # Replace with test collection ID
            VariableName = "TestCollVar_RemoveByID"  # Will be made unique with timestamp in tests
        }
        ByWildcard = @{
            CollectionName = "Test-Collection-Direct"
            VariableNamePattern = "TestCollVar_RemoveWildcard_*"  # Pattern for batch removal
        }
        NonExistentCollection = @{
            CollectionName = "NONEXISTENT-COLLECTION-999"
            VariableName = "TestCollVar"
        }
        NonExistentVariable = @{
            CollectionName = "Test-Collection-Direct"
            VariableName = "NonExistentCollVar999"
        }
    }

    # ========================================================================
    # New-CMASDeviceVariable
    # ========================================================================
    'New-CMASDeviceVariable' = @{
        ByDeviceName = @{
            DeviceName = "TEST-DEVICE-001"  # Existing test device
            VariableName = "TestVar"  # Will be made unique with timestamp in tests
            VariableValue = "TestValue123"
        }
        ByResourceId = @{
            ResourceId = 16777220  # Replace with actual ResourceID
            VariableName = "TestVar_ResID"  # Will be made unique with timestamp in tests
            VariableValue = "TestValueByResID"
        }
        WithSpecialChars = @{
            DeviceName = "TEST-DEVICE-001"
            VariableName = "TestVar_Special"  # Will be made unique with timestamp in tests
            VariableValue = "C:\\Windows\\System32;D:\\Apps"
        }
        MaskedVariable = @{
            DeviceName = "TEST-DEVICE-001"
            VariableName = "TestVar_Masked"  # Will be made unique with timestamp in tests
            VariableValue = "SecretValue123"
            IsMasked = $true
        }
        EmptyValue = @{
            DeviceName = "TEST-DEVICE-001"
            VariableName = "TestVar_Empty"  # Will be made unique with timestamp in tests
            VariableValue = ""
        }
        NonExistentDevice = @{
            DeviceName = "NONEXISTENT-DEVICE-999"
            VariableName = "TestVar_NoDevice"
            VariableValue = "ShouldFail"
        }
        InvalidVariableName = @{
            DeviceName = "TEST-DEVICE-001"
            VariableName = "Test Var Invalid"  # Spaces not allowed - should fail validation
            VariableValue = "ShouldFail"
        }
    }

    # ========================================================================
    # Get-CMASDeviceVariable
    # ========================================================================
    'Get-CMASDeviceVariable' = @{
        ByDeviceName = @{
            DeviceName = "TEST-DEVICE-001"  # Device with variables
            ExpectedMinCount = 1  # Should have at least 1 variable from tests
        }
        ByResourceId = @{
            ResourceId = 16777220  # Replace with actual ResourceID
            ExpectedMinCount = 1
        }
        ByDeviceNameAndVariableName = @{
            DeviceName = "TEST-DEVICE-001"
            VariableName = "TestVar*"  # Wildcard pattern to match test variables
        }
        ByResourceIdAndVariableName = @{
            ResourceId = 16777220
            VariableName = "TestVar_ResID*"  # Specific test variable pattern
        }
        NonExistentDevice = @{
            DeviceName = "NONEXISTENT-DEVICE-999"
            ExpectedCount = 0
        }
        NonExistentVariable = @{
            DeviceName = "TEST-DEVICE-001"
            VariableName = "NonExistentVar999"
            ExpectedCount = 0
        }
        DeviceWithoutVariables = @{
            # If you have a device without variables, specify it here
            # Otherwise this test will be skipped
            DeviceName = $null  # Set to actual device name or leave null
            ResourceId = $null  # Set to actual ResourceID or leave null
        }
    }

    # ========================================================================
    # Remove-CMASDeviceVariable
    # ========================================================================
    'Remove-CMASDeviceVariable' = @{
        ByDeviceName = @{
            DeviceName = "TEST-DEVICE-001"
            VariableName = "TestVar_Remove"  # Will be made unique with timestamp in tests
        }
        ByResourceId = @{
            ResourceId = 16777220  # Replace with actual ResourceID
            VariableName = "TestVar_RemoveByID"  # Will be made unique with timestamp in tests
        }
        ByWildcard = @{
            DeviceName = "TEST-DEVICE-001"
            VariableNamePattern = "TestVar_RemoveWildcard_*"  # Pattern for batch removal
        }
        NonExistentDevice = @{
            DeviceName = "NONEXISTENT-DEVICE-999"
            VariableName = "TestVar"
        }
        NonExistentVariable = @{
            DeviceName = "TEST-DEVICE-001"
            VariableName = "NonExistentVar999"
        }
    }

    # ========================================================================
    # Set-CMASDeviceVariable
    # ========================================================================
    'Set-CMASDeviceVariable' = @{
        ByDeviceName = @{
            DeviceName = "TEST-DEVICE-001"
            VariableName = "TestVar_Set"  # Will be made unique with timestamp in tests
            OriginalValue = "OriginalValue"
            NewValue = "ModifiedValue123"
        }
        ByResourceId = @{
            ResourceId = 16777220  # Replace with actual ResourceID
            VariableName = "TestVar_SetByResID"  # Will be made unique with timestamp in tests
            OriginalValue = "OriginalValueByID"
            NewValue = "ModifiedValueByID"
        }
        ChangeMaskedState = @{
            DeviceName = "TEST-DEVICE-001"
            VariableName = "TestVar_Mask"  # Will be made unique with timestamp in tests
            OriginalValue = "ValueToMask"
            NewValue = "ValueToMask"  # Keep value same, just change masked state
            IsMasked = $true
        }
        UnmaskVariable = @{
            DeviceName = "TEST-DEVICE-001"
            VariableName = "TestVar_Unmask"  # Will be made unique with timestamp in tests
            OriginalValue = "MaskedValue"
            NewValue = "UnmaskedValue"
            IsNotMasked = $true
        }
        EmptyValue = @{
            DeviceName = "TEST-DEVICE-001"
            VariableName = "TestVar_SetEmpty"  # Will be made unique with timestamp in tests
            OriginalValue = "SomeValue"
            NewValue = ""
        }
        NonExistentDevice = @{
            DeviceName = "NONEXISTENT-DEVICE-999"
            VariableName = "TestVar"
            NewValue = "ShouldFail"
        }
        NonExistentVariable = @{
            DeviceName = "TEST-DEVICE-001"
            VariableName = "NonExistentVar999"
            NewValue = "ShouldFail"
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

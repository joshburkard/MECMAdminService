# Test Declarations for New-CMASDeviceVariable
# This file contains test data declarations for New-CMASDeviceVariable function tests
# Add this data to your main declarations.ps1 file under the $script:TestData hashtable

$script:TestData['New-CMASDeviceVariable'] = @{
    # Create variable by device name
    ByDeviceName = @{
        DeviceName = "TEST-DEVICE-001"  # Replace with an existing test device name
        VariableName = "TestVar_$(Get-Date -Format 'yyyyMMddHHmmss')"
        VariableValue = "TestValue123"
    }

    # Create variable by ResourceID
    ByResourceId = @{
        ResourceId = 16777220  # Replace with an existing device ResourceID
        VariableName = "TestVar_ResID_$(Get-Date -Format 'yyyyMMddHHmmss')"
        VariableValue = "TestValueByResID"
    }

    # Create variable with special characters in value
    WithSpecialChars = @{
        DeviceName = "TEST-DEVICE-001"
        VariableName = "TestVar_Special_$(Get-Date -Format 'yyyyMMddHHmmss')"
        VariableValue = "C:\Windows\System32;D:\Apps"
    }

    # Create masked variable (sensitive)
    MaskedVariable = @{
        DeviceName = "TEST-DEVICE-001"
        VariableName = "TestVar_Masked_$(Get-Date -Format 'yyyyMMddHHmmss')"
        VariableValue = "SecretValue123"
        IsMasked = $true
    }

    # Create variable with empty value
    EmptyValue = @{
        DeviceName = "TEST-DEVICE-001"
        VariableName = "TestVar_Empty_$(Get-Date -Format 'yyyyMMddHHmmss')"
        VariableValue = ""
    }

    # Non-existent device
    NonExistentDevice = @{
        DeviceName = "NONEXISTENT-DEVICE-999"
        VariableName = "TestVar_NoDevice"
        VariableValue = "ShouldFail"
    }

    # Invalid variable name (contains spaces)
    InvalidVariableName = @{
        DeviceName = "TEST-DEVICE-001"
        VariableName = "Test Var Invalid"  # Spaces not allowed
        VariableValue = "ShouldFail"
    }
}

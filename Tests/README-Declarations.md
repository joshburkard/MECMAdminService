# Test Declarations Structure

This document explains the test data organization approaches available in this project.

## Overview

We provide two approaches for organizing test data:

1. **Simple Approach** (`declarations_sample.ps1`) - Flat variable structure, easy to understand
2. **Structured Approach** (`declarations_sample_v2.ps1`) - Hierarchical hashtable structure, scalable

## Approach 1: Simple (Current)

**File:** `declarations_sample.ps1`

### Pros
- Easy to understand for beginners
- Quick to set up
- Direct variable access

### Cons
- Can become cluttered with many functions
- Harder to see which values belong to which function
- Difficult to manage multiple parameter sets per function

### Example
```powershell
$script:TestCollectionID = "SMS00001"
$script:TestCollectionName = "All Systems"
```

### Usage in Tests
```powershell
$result = Get-CMASCollection -CollectionID $script:TestCollectionID
```

## Approach 2: Structured (Recommended for Growth)

**File:** `declarations_sample_v2.ps1`

### Pros
- Organized by function and parameter set
- Easy to see all test scenarios for a function
- Scalable as project grows
- Self-documenting structure
- Helper functions for easy access

### Cons
- Slightly more complex initial setup
- Requires understanding of hashtables

### Example
```powershell
$script:TestData = @{
    'Get-CMASCollection' = @{
        ByName = @{
            Name = "All Systems"
            ExpectedCount = 1
        }
        ByCollectionID = @{
            CollectionID = "SMS00001"
            ExpectedCount = 1
        }
        NonExistent = @{
            Name = "NonExistent Collection 999"
            CollectionID = "XXX99999"
            ExpectedCount = 0
        }
    }
}
```

### Usage in Tests

#### Option 1: Using helper function
```powershell
$testData = Get-TestData -FunctionName 'Get-CMASCollection' -ParameterSet 'ByName'
$result = Get-CMASCollection -Name $testData.Name
$result | Should -HaveCount $testData.ExpectedCount
```

#### Option 2: Direct access
```powershell
$testData = $script:TestData['Get-CMASCollection'].ByName
$result = Get-CMASCollection -Name $testData.Name
```

#### Option 3: Backward compatible (included in v2 file)
```powershell
# Old variables still work via backward compatibility section
$result = Get-CMASCollection -CollectionID $script:TestCollectionID
```

## Adding New Functions

### Simple Approach
Add new variables to the appropriate section:
```powershell
# Test NewFunction Information
$script:TestNewFunctionParam1 = "value1"
$script:TestNewFunctionParam2 = "value2"
```

### Structured Approach
Add new function to `$script:TestData` hashtable:
```powershell
'Get-CMASNewFunction' = @{
    ByParameter1 = @{
        Parameter1 = "value1"
        ExpectedCount = 1
    }
    ByParameter2 = @{
        Parameter2 = "value2"
        ExpectedResult = "expected"
    }
    Combined = @{
        Parameter1 = "value1"
        Parameter2 = "value2"
    }
    NonExistent = @{
        Parameter1 = "nonexistent"
        ExpectedCount = 0
    }
}
```

## Migration Path

If you want to migrate from Simple to Structured:

1. Copy `declarations_sample_v2.ps1` to `declarations.ps1`
2. Update the values with your environment specifics
3. Tests will continue to work via backward compatibility section
4. Gradually update tests to use the new structure
5. Once migration complete, remove backward compatibility section

## Recommendations

- **Starting new**: Use **Simple** approach - it's easier to learn
- **Growing project**: Switch to **Structured** approach when you have 5+ functions
- **Large project**: Use **Structured** approach from the start

## Setup Instructions

1. Copy your chosen sample file:
   ```powershell
   # Simple approach
   Copy-Item -Path "Tests\declarations_sample.ps1" -Destination "Tests\declarations.ps1"

   # OR Structured approach
   Copy-Item -Path "Tests\declarations_sample_v2.ps1" -Destination "Tests\declarations.ps1"
   ```

2. Edit `declarations.ps1` with your environment values

3. Ensure `declarations.ps1` is in `.gitignore` (already done)

## JSON Alternative?

We considered JSON but chose PowerShell because:
- ❌ JSON has no comments (or limited)
- ❌ JSON can't contain logic or functions
- ❌ JSON less familiar to PowerShell developers
- ✅ PowerShell hashtables achieve same structure
- ✅ PowerShell supports comments and logic
- ✅ Native to PowerShell ecosystem

If you really prefer JSON, you could externalize data:
```powershell
$script:TestData = Get-Content -Path "test-data.json" | ConvertFrom-Json -AsHashtable
```

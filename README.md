# MECMAdminService PowerShell Module

A PowerShell module for managing Microsoft Endpoint Configuration Manager (MECM) / System Center Configuration Manager (SCCM) through the Administration Service REST API.

![PowerShell](https://img.shields.io/badge/PowerShell-5.1%20%7C%207.x-blue)
![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Linux%20%7C%20macOS-lightgrey)

## 📋 Table of Contents

- [Overview](#-overview)
- [What is the Admin Service?](#what-is-the-admin-service)
- [Features](#-features)
- [Requirements](#-requirements)
- [Installation](#-installation)
- [Getting Started](#-getting-started)
- [Available Functions](#-available-functions)
- [Usage Examples](#-usage-examples)
- [Contributing](#-contributing)
- [License](#-license)

## 🎯 Overview

The **SCCMAdminService** module provides a PowerShell interface to interact with the Configuration Manager Administration Service (Admin Service). It enables automation of common MECM/SCCM tasks such as managing collections, devices, scripts, and more through a modern REST API.

This module is compatible with:
- **Windows PowerShell 5.1** (Windows only)
- **PowerShell 7.x** (Windows, Linux, macOS)

## What is the Admin Service?

The **Administration Service** is a REST API provided by Microsoft Endpoint Configuration Manager (MECM) that allows you to interact with Configuration Manager data through HTTPS. It exposes both the SMS Provider WMI classes and custom API endpoints.

The Admin Service provides:
- **WMI Access**: Query Configuration Manager WMI classes (e.g., `SMS_Collection`, `SMS_R_System`)
- **Custom Operations**: Execute specific actions like running scripts or managing devices
- **REST-based**: Modern HTTP/HTTPS interface instead of traditional WMI/COM
- **OData Support**: Query filtering, selection, and expansion capabilities

### Key Benefits:
- ✅ Remote access over HTTPS
- ✅ No need for WMI or COM dependencies
- ✅ Works with PowerShell Core (cross-platform)
- ✅ Built-in authentication and security
- ✅ Supports automation and CI/CD scenarios

For more information, see [Microsoft's Admin Service Documentation](https://learn.microsoft.com/en-us/mem/configmgr/develop/adminservice/overview).

## ✨ Features

- **Device Management**: Query and manage Configuration Manager devices
- **Collection Management**: Retrieve collections and their membership rules
- **Script Execution**: Run Configuration Manager scripts and monitor their execution status
- **Direct Membership Rules**: Manage collection direct membership rules
- **Flexible Authentication**: Support for default credentials or explicit credential passing
- **Certificate Validation**: Skip certificate validation for lab/test environments
- **Pipeline Support**: Many cmdlets support PowerShell pipeline for efficient workflows

## 📋 Requirements

### MECM/SCCM Environment

- **Configuration Manager**: Current Branch (version 1810 or later recommended)
- **Admin Service**: Must be enabled on the SMS Provider server
- **Site Server**: HTTPS connectivity to the SMS Provider server

### Network & Connectivity

- **HTTPS Access**: Port 443 (default) must be accessible to the SMS Provider server
- **Network Connectivity**: Direct network path from the client to the SMS Provider server
- **Certificate**: Valid SSL/TLS certificate on the SMS Provider server (or use `-SkipCertificateCheck` for testing)

### Permissions

The account used to connect must have appropriate Configuration Manager role-based access control (RBAC) permissions:

- **Read-Only Administrator**: Minimum for viewing collections and devices
- **Operations Administrator**: Required for script execution and device operations
- **Full Administrator**: Required for all operations

Common required permissions:
- **Collections**: Read Collection
- **Devices**: Read Resource
- **Scripts**: Read Script, Run Script
- **Site**: Read Site

### PowerShell Environment

- **Windows PowerShell 5.1** or later (Windows only)
- **PowerShell 7.x** (recommended for cross-platform support - Windows, Linux, macOS)
- **Execution Policy**: Set to allow script execution

> **Note**: While PowerShell 7.x is supported on all platforms, the SCCM Admin Service endpoint must still be accessible over the network (typically a Windows Server).

## 📦 Installation

### Option 1: Manual Installation

1. Download the module from this repository
2. Copy the module folder to one of your PowerShell module paths:
   ```powershell
   # View your module paths
   $env:PSModulePath -split ';'

   # Typical locations:
   # User: C:\Users\<Username>\Documents\PowerShell\Modules
   # System: C:\Program Files\PowerShell\Modules
   ```

3. Import the module:
   ```powershell
   Import-Module SCCMAdminService
   ```

### Option 2: Import from Source

```powershell
# Import directly from the repository location
Import-Module "C:\GIT\SDWorx\SCCMAdminService\SCCMAdminService.psd1"
```

### Verify Installation

```powershell
# Check available commands
Get-Command -Module SCCMAdminService

# View module information
Get-Module SCCMAdminService
```

## 🚀 Getting Started

### Quick Start

```powershell
# 1. Import the module
Import-Module SCCMAdminService

# 2. Connect to your Admin Service
Connect-CMAS -SiteServer "sccm.contoso.com"

# 3. Start using the cmdlets
Get-CMASDevice -Name "WORKSTATION01"
Get-CMASCollection -Name "All Servers"
```

### Connection Examples

```powershell
# Connect with default credentials (current user)
Connect-CMAS -SiteServer "sccm.contoso.com"

# Connect with explicit credentials
$cred = Get-Credential
Connect-CMAS -SiteServer "sccm.contoso.com" -Credential $cred

# Connect and skip certificate validation (for test environments only)
Connect-CMAS -SiteServer "sccm.contoso.com" -SkipCertificateCheck
```

The connection information is stored in a session variable and automatically used by other cmdlets.

## 💡 Usage Examples

### Basic Device Query

```powershell
# Get a specific device by name
Get-CMASDevice -Name "WORKSTATION01"

# Get device by Resource ID
Get-CMASDevice -ResourceID 16777220

# Get all devices (returns first batch)
Get-CMASDevice
```

### Basic Collection Query

```powershell
# Get a collection by name
Get-CMASCollection -Name "All Servers"

# Get collection by ID
Get-CMASCollection -CollectionID "SMS00001"

# Get direct membership rules
Get-CMASCollectionDirectMembershipRule -CollectionName "My Collection"
```

### More Examples

For detailed examples and usage scenarios for each function, see:
- **[Help Documentation](./Help/)** - Complete documentation with examples for all functions
- **[Examples Folder](./Examples/)** - Real-world scenario examples and sample scripts

Or use PowerShell's built-in help:
```powershell
Get-Help Connect-CMAS -Examples
Get-Help Get-CMASDevice -Full
Get-Help Invoke-CMASScript -Detailed
```

## 📚 Available Functions

### Connection Management
- `Connect-CMAS` - Establish a connection to the Admin Service

### Device Management
- `Get-CMASDevice` - Retrieve Configuration Manager device information
- `Get-CMASDeviceVariable` - Get device variables for Configuration Manager devices
- `New-CMASDeviceVariable` - Create new device variables for Configuration Manager devices
- `Remove-CMASDeviceVariable` - Remove device variables from Configuration Manager devices

### Collection Management
- `Get-CMASCollection` - Retrieve Configuration Manager collections
- `New-CMASCollection` - Create new Configuration Manager collections
- `Set-CMASCollection` - Modify properties of Configuration Manager collections
- `Remove-CMASCollection` - Remove Configuration Manager collections
- `Invoke-CMASCollectionUpdate` - Trigger membership updates for collections
- `Set-CMASCollectionSchedule` - Set refresh schedules for collections

### Collection Membership Rules
- `Get-CMASCollectionDirectMembershipRule` - Get direct membership rules from collections
- `Get-CMASCollectionExcludeMembershipRule` - Get exclude membership rules from collections
- `Get-CMASCollectionIncludeMembershipRule` - Get include membership rules from collections
- `Get-CMASCollectionQueryMembershipRule` - Get query-based membership rules from collections
- `Add-CMASCollectionMembershipRule` - Add membership rules to collections
- `Remove-CMASCollectionMembershipRule` - Remove membership rules from collections

### Script Management
- `Get-CMASScript` - Retrieve Configuration Manager scripts
- `Invoke-CMASScript` - Execute a Configuration Manager script on target devices
- `Get-CMASScriptExecutionStatus` - Check the execution status of scripts

### Core (private) Functions
- `Invoke-CMASApi` - Low-level function to make direct API calls (advanced users)

## � Documentation

Detailed documentation and examples are available for each function:

```powershell
# Get help for a specific function
Get-Help Connect-CMAS -Full
Get-Help Get-CMASDevice -Examples
Get-Help Invoke-CMASScript -Detailed

# List all available commands
Get-Command -Module SCCMAdminService
```

**Complete documentation is available in the [Help](./Help/) folder:**
- Each function has its own markdown file with detailed descriptions
- Full parameter documentation
- Multiple usage examples for common scenarios
- Notes on implementation and best practices

**Sample scripts and scenarios are in the [Examples](./Examples/) folder.**

## 🔧 Troubleshooting

### Common Issues

**Connection Failures**
```powershell
# Check connectivity
Test-NetConnection -ComputerName "sccm.contoso.com" -Port 443

# Verify Admin Service is enabled
Invoke-WebRequest -Uri "https://sccm.contoso.com/AdminService/wmi/SMS_Site" -UseDefaultCredentials
```

**Permission Denied**
- Verify your account has appropriate RBAC permissions in Configuration Manager
- Check with Configuration Manager administrator

**Certificate Errors**
- Use `-SkipCertificateCheck` for testing (not recommended for production)
- Install proper SSL/TLS certificates on the SMS Provider server

For more troubleshooting help, see the [Help folder](./Help/) documentation.

## 🤝 Contributing

Contributions are welcome! We appreciate your help in making this module better.

### How to Contribute

- **Report Bugs**: Open an issue describing the problem and steps to reproduce
- **Request Features**: Suggest new functions or enhancements via issues
- **Submit Pull Requests**: Fix bugs or add features (see contribution guide)
- **Improve Documentation**: Help make documentation clearer and more comprehensive

### Contribution Guide

For detailed information on contributing to this project, including:
- Project structure and organization
- How to create or modify functions
- Testing requirements and procedures
- Build process and workflow
- Documentation standards

Please read our **[Contribution Guide (CONTRIBUTING.md)](./CONTRIBUTING.md)**.

### Quick Start for Contributors

```powershell
# 1. Fork the repository on GitHub (click "Fork" button)

# 2. Clone YOUR fork
git clone https://github.com/YOUR-USERNAME/SCCMAdminService.git
cd SCCMAdminService

# 3. Create a feature branch (REQUIRED - no direct commits to main!)
git checkout -b feature/your-feature-name

# 4. Make your changes following the function template
# See Code/function-template.ps1

# 5. Test your changes
.\Tests\Invoke-Test.ps1 -FunctionName "Your-Function"

# 6. Build the module (optional)
.\CI\Build-Module.ps1

# 7. Commit and push to your feature branch
git add .
git commit -m "Add your feature"
git push origin feature/your-feature-name

# 8. Create a Pull Request on GitHub from your feature branch
```

> **⚠️ Important**: Direct pushes to the `main` branch are blocked. All changes must go through pull requests, even for core contributors. This ensures code quality and proper review.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

**In short**: You are free to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of this software, as long as you include the original copyright notice and license terms.

## 🔗 Related Resources

- [Configuration Manager Admin Service Overview](https://learn.microsoft.com/en-us/mem/configmgr/develop/adminservice/overview)
- [How to use the Administration Service](https://learn.microsoft.com/en-us/mem/configmgr/develop/adminservice/usage)
- [Configuration Manager PowerShell Documentation](https://learn.microsoft.com/en-us/powershell/sccm/overview)

---

**Note**: This module is designed for use with Microsoft Endpoint Configuration Manager (MECM) / System Center Configuration Manager (SCCM) Current Branch. Always test in a non-production environment first.


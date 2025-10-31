# Entra Groups Setup - PowerShell

Complete deployment script for creating Entra ID groups and assigning proper roles for tenant and subscription management.

## Prerequisites

- **PowerShell 7+** installed on your local machine
- **Azure CLI** installed and available in PATH
- **Global Administrator** rights in Entra ID
- **Subscription Owner** rights on target subscription

### Installation

**PowerShell 7+:**
```bash
# Windows
winget install Microsoft.PowerShell

# macOS
brew install --cask powershell

# Linux
# See: https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-linux
```

**Azure CLI:**
```bash
# Windows
winget install Microsoft.AzureCLI

# macOS
brew install azure-cli

# Linux
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
```

## Quick Start

1. **Download the script:**
```powershell
# Download to current directory
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/CXNSMB/onboarding/main/entra-groups-setup/deploy-entra-groups.ps1" -OutFile "deploy-entra-groups.ps1"
```

2. **Run the script:**
```powershell
# First run - creates groups and config file
./deploy-entra-groups.ps1 -TenantCode "your-tenant-code"
```

The script will:
- ✅ Check if you're logged in to Azure CLI
- ✅ If not logged in → automatically trigger device code login
- ✅ Execute all setup tasks
- ✅ If login was triggered by the script → automatically logout at the end

> 💡 **Note:** If you're already logged in with `az login`, the script will use your existing session and will NOT logout at the end.

## Authentication Behavior

The script intelligently handles authentication:

| Scenario | Script Behavior |
|----------|----------------|
| **Not logged in** | Triggers `az login --use-device-code` → Executes script → Logs out automatically |
| **Already logged in** | Uses existing session → Executes script → Does NOT logout |

This ensures your existing Azure CLI sessions are never disrupted.

## Features

### `deploy-entra-groups.ps1` - Complete Setup Script
**Standalone PowerShell script** that handles all Entra ID setup using Microsoft Graph REST API via Azure CLI.

**Features:**
- ✅ Hard-coded group definitions (standalone, no external files needed)
- ✅ Uses only Azure CLI (no PowerShell modules required)
- ✅ Supports multiple subscriptions in one config file
- ✅ Creates Restricted Administrative Unit
- ✅ Assigns AU-scoped roles to calling user
- ✅ All groups in AU with HiddenMembership
- ✅ Tenant-level Entra directory roles
- ✅ Subscription-level RBAC roles
- ✅ Azure Reservations RBAC roles (tenant-level)
- ✅ 15 second replication wait (prevents errors!)
- ✅ Automatic login/logout management

## Usage

### 1. Ensure you're in the correct subscription
```powershell
# Check current context
az account show

# Switch to desired subscription if needed
az account set --subscription "your-subscription-id"
```

### 2. First run (new tenant)
```powershell
# Execute with TenantCode parameter
./deploy-entra-groups.ps1 -TenantCode "7qx45m"
```

This creates:
- Administrative Unit: `7qx45m-tenant-admin`
- Tenant groups: `sec-tenant-7qx45m-*`
- Subscription groups: `sec-az-7qx45m-<prefix>-*`
- `7qx45m-config.json` file

### 3. Add another subscription
```powershell
# Switch to another subscription
az account set --subscription "other-subscription-id"

# Run script (reads TenantCode from config file)
./deploy-entra-groups.ps1
```

The script automatically recognizes it's the same tenant and adds the subscription to existing config.

### 4. WhatIf mode (test without changes)
```powershell
./deploy-entra-groups.ps1 -TenantCode "7qx45m" -WhatIf
```

### 5. Entra-only mode (skip subscription setup)
```powershell
./deploy-entra-groups.ps1 -TenantCode "7qx45m" -SetupEntraOnly
```

## What does the script do?

### Administrative Unit (AU)
- Creates a **Restricted Administrative Unit**: `<tenantcode>-tenant-admin`
- **isMemberManagementRestricted**: `true` (restricted management)
- **Visibility**: `HiddenMembership` (only AU admins see members)
- **Calling user receives AU-scoped roles**:
  - User Administrator
  - Groups Administrator
  - Privileged Authentication Administrator
  - License Administrator

### Tenant Level Groups
The script creates the following tenant-level groups and assigns roles:

**Groups with Entra Directory Roles (tenant-wide):**
- `sec-tenant-{code}-dailyadmin` - Daily operations
  - User Administrator
  - Groups Administrator
- `sec-tenant-{code}-elevadmin` - Elevated roles
  - User Administrator
  - Groups Administrator
  - Security Administrator
  - Application Administrator
  - Global Reader
  - License Administrator
  - Authentication Administrator
  - Authentication Policy Administrator
  - Privileged Authentication Administrator
  - Conditional Access Administrator
- `sec-tenant-{code}-sharepoint-admin` - SharePoint Administrator
- `sec-tenant-{code}-intune-admin` - Intune Administrator
- `sec-tenant-{code}-teams-admin` - Teams Administrator
- `sec-tenant-{code}-privileged-role-admin` - Privileged Role Administrator

**Groups with Azure Reservations RBAC Roles (tenant-level, scope: `/providers/Microsoft.Capacity`):**
- `sec-tenant-{code}-reservations-read` → Reservations Reader
- `sec-tenant-{code}-reservations-admin` → Reservations Administrator
- `sec-tenant-{code}-reservations-purchase` → Reservation Purchaser

**Informational group:**
- `sec-tenant-{code}-break-glass` - Break glass accounts (no roles)

### Subscription Level Groups
For each subscription, groups are created with pattern `sec-az-{code}-<subscription-prefix>-<role>`:

- `sec-az-{code}-xxx-reader` → Reader
- `sec-az-{code}-xxx-dailyadmin` → Reader, Backup Reader, Desktop Virtualization Virtual Machine Contributor, Desktop Virtualization User Session Operator, DNS Zone Contributor
- `sec-az-{code}-xxx-contributor` → Contributor
- `sec-az-{code}-xxx-costreader` → Cost Management Reader
- `sec-az-{code}-xxx-sec-uaa` → User Access Administrator
- `sec-az-{code}-xxx-owner` → Owner

Where `xxx` is the first part of subscription ID (up to first hyphen).

### Config File Structure
The script saves all information in `{tenantcode}-config.json`:
```json
{
  "tenantconfig": {
    "tenantCode": "7qx45m",
    "tenantId": "...",
    "onMicrosoftDomain": "7qx45m.onmicrosoft.com",
    "restrictedAdminUnitId": "...",
    "prefix": "sec-tenant-7qx45m",
    "groups": {
      "dailyadmin": "guid",
      "elevadmin": "guid",
      ...
    },
    "lastUpdated": "2025-10-31T12:00:00Z"
  },
  "subscriptions": {
    "subscription-id-1": {
      "prefix": "sec-az-7qx45m-8983f6f3",
      "groups": {
        "reader": "guid",
        "dailyadmin": "guid",
        ...
      }
    },
    "subscription-id-2": { ... }
  },
  "subscriptionId": "current-subscription-id"
}
```

## Error Handling

The script:
- ✅ Checks if groups already exist before creating (idempotent)
- ✅ Checks if role assignments already exist (idempotent)
- ✅ Verifies groups exist via Graph API (not just via config)
- ✅ Uses `--assignee-principal-type Group` for RBAC assignments
- ✅ Waits 15 seconds between group creation and RBAC assignments (replication)
- ✅ Logs all actions with color-coded output
- ✅ Multi-subscription support: preserves existing subscriptions in config
- ✅ Automatic authentication management

### Typical workflow with errors:
1. **First run**: Possible replication delay errors with RBAC
2. **Second run**: Script recognizes existing groups and only assigns missing roles
3. **Result**: All groups and roles correctly configured

## Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| `-TenantCode` | First run only | Tenant code for group names (e.g., "7qx45m") |
| `-WhatIf` | No | Test mode, no changes made |
| `-SetupEntraOnly` | No | Only AU and Entra roles, no subscription setup |
| `-ConfigFile` | No | Path to config file (default: `<scriptdir>/<tenantcode>-config.json`) |

## Verification

After running the script, you can verify everything:

```powershell
# View all created groups
az ad group list --filter "startswith(displayName, 'sec-tenant-')" --output table
az ad group list --filter "startswith(displayName, 'sec-az-')" --output table

# View AU properties
az rest --method GET --uri "https://graph.microsoft.com/v1.0/directory/administrativeUnits/<au-id>"

# View RBAC assignments on subscription
az role assignment list --subscription "<subscription-id>" --output table

# View tenant-level RBAC (reservations)
az role assignment list --scope "/providers/Microsoft.Capacity" --output table

# View config file
Get-Content 7qx45m-config.json | ConvertFrom-Json | ConvertTo-Json -Depth 10
```

## Files

- `deploy-entra-groups.ps1` - Complete deployment script (standalone)
- `{tenantcode}-config.json` - Configuration with all groups and subscriptions (auto-created)
- `README.md` - This documentation

## Troubleshooting

### Common issues:

1. **"PowerShell version too old"**
   - **Solution**: Install PowerShell 7+ (not Windows PowerShell 5.1)
   - Check version: `$PSVersionTable.PSVersion`

2. **"az: command not found"**
   - **Solution**: Install Azure CLI and ensure it's in PATH
   - Test: `az --version`

3. **"No config file found and no TenantCode parameter provided"**
   - **Solution**: On first run, provide `-TenantCode "your-code"` parameter

4. **"Insufficient privileges"**
   - **Solution**: Ensure you have Global Admin + Subscription Owner rights
   - Login with correct account: `az logout` then `az login --use-device-code`

5. **"PrincipalNotFound" errors during RBAC assignments**
   - **Solution**: Normal on first run (replication delay)
   - Run script again, it will only assign missing roles

6. **"Group already exists" warnings**
   - **This is normal**: Script is idempotent, recognizes existing groups
   - No action needed

7. **"Cannot create Administrative Unit"**
   - **Solution**: Create AU manually in Azure Portal:
     1. Go to **Azure Portal** → **Entra ID** → **Administrative Units**
     2. Click **"New administrative unit"**
     3. **Name**: `{your-tenant-code}-tenant-admin`
     4. **Description**: Restricted administrative unit for tenant management operations
     5. **✓ Check**: "Restricted management administrative unit"
     6. Click **Create**
     7. Re-run the script

### Debug information
The script shows extensive logging:
- 🔵 Cyan: Information about what's being executed
- 🟢 Green: Successful actions
- 🟡 Yellow: Warnings (usually OK)
- 🔴 Red: Errors (require action)

## Security Notes

### Token Lifetime
- Azure CLI tokens are valid for **1 hour** by default
- This cannot be shortened via `az login` parameters
- If the script triggered the login, it automatically logs out at the end
- If you were already logged in, your session remains active

### Authentication Scope
- The script uses standard Azure CLI authentication
- Requires delegated Graph API permissions (user context)
- Required permissions:
  - `Directory.AccessAsUser.All` (recommended), OR
  - `Directory.ReadWrite.All` + `Group.ReadWrite.All` + `RoleManagement.ReadWrite.Directory`

## Best Practices

1. **Test first with `-WhatIf`** to see what will happen
2. **Run script twice** on new tenant (first: groups, second: fix replication delays)
3. **Save config file** for multi-subscription setups
4. **Use dedicated admin account** for running the script
5. **Review created groups** in Azure Portal after first run
6. **Document your tenant code** for future reference

## Example Workflow

```powershell
# 1. Download script
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/CXNSMB/onboarding/main/entra-groups-setup/deploy-entra-groups.ps1" -OutFile "deploy-entra-groups.ps1"

# 2. Test run (WhatIf)
./deploy-entra-groups.ps1 -TenantCode "7qx45m" -WhatIf

# 3. First subscription
./deploy-entra-groups.ps1 -TenantCode "7qx45m"

# 4. Wait for replication (15 seconds already built-in)

# 5. Second run to fix any replication issues
./deploy-entra-groups.ps1 -TenantCode "7qx45m"

# 6. Switch to another subscription
az account set --subscription "other-subscription-id"

# 7. Add second subscription (TenantCode read from config)
./deploy-entra-groups.ps1

# 8. Verify
az ad group list --filter "startswith(displayName, 'sec-tenant-')" --output table
az ad group list --filter "startswith(displayName, 'sec-az-')" --output table
```

## Multi-Tenant Usage

If you manage multiple customer tenants:

```powershell
# Tenant 1
az logout  # Clean slate
./deploy-entra-groups.ps1 -TenantCode "tenant1"

# Tenant 2
az logout  # Clean slate
./deploy-entra-groups.ps1 -TenantCode "tenant2"
```

The automatic logout ensures you don't accidentally mix tenants.

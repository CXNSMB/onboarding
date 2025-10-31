# Entra Groups Setup

Complete deployment script for creating Entra ID groups and assigning proper roles for tenant and subscription management.

## Quick Start - Azure Cloud Shell

The fastest way to get started is via Azure Cloud Shell in your browser:

### Prerequisites
Before running the script, **manually create the Administrative Unit** (due to Cloud Shell API permission limitations):

1. Go to **Azure Portal** → **Entra ID** → **Administrative Units**
2. Click **"New administrative unit"**
3. Configure:
   - **Name**: `{your-tenant-code}-tenant-admin` (e.g., `7qx45m-tenant-admin`)
   - **Description**: Restricted administrative unit for tenant management operations
   - **✓ Check**: "Restricted management administrative unit"
4. Click **Create**

### Run the Script

1. Open [Azure Cloud Shell](https://shell.azure.com)
2. Select **Bash** as shell type
3. Copy and paste the following command:

```bash
# Download and execute the script
curl -s https://raw.githubusercontent.com/CXNSMB/onboarding/main/entra-groups-setup/deploy-entra-groups.sh | bash -s -- -t "your-tenant-code"
```

Replace `"your-tenant-code"` with your actual tenant code (e.g., "7qx45m").

> 💡 **Why manual AU creation?** Azure Cloud Shell uses a managed app that lacks the `AdministrativeUnit.ReadWrite.All` Graph API permission. Creating the AU manually beforehand allows the script to proceed with all other operations (group creation, role assignments) which work fine with Cloud Shell's existing permissions.

### Alternative: Download first, execute later

If you want to review the script before executing:

```bash
# Download the script
curl -s https://raw.githubusercontent.com/CXNSMB/onboarding/main/entra-groups-setup/deploy-entra-groups.sh -o deploy-entra-groups.sh
chmod +x deploy-entra-groups.sh

# Review the script
cat deploy-entra-groups.sh

# Execute it
./deploy-entra-groups.sh -t "your-tenant-code"
```

## Features

### `deploy-entra-groups.sh` - Complete Setup Script
**Standalone script** that handles all Entra ID setup using Microsoft Graph REST API via Azure CLI. No PowerShell modules required.

**Features:**
- ✅ Hard-coded group definitions (standalone, no external files needed)
- ✅ Uses only Azure CLI and jq (available in Cloud Shell)
- ✅ Supports multiple subscriptions in one config file
- ✅ Creates Restricted Administrative Unit
- ✅ Assigns AU-scoped roles to calling user
- ✅ All groups in AU with HiddenMembership
- ✅ Tenant-level Entra directory roles
- ✅ Subscription-level RBAC roles
- ✅ Azure Reservations RBAC roles (tenant-level)
- ✅ 15 second replication wait (prevents errors!)

## Requirements

- **Global Administrator** rights in Entra ID
- **Subscription Owner** rights on target subscription
- **Azure CLI** installed and logged in (pre-installed in Cloud Shell)
- **jq** for JSON parsing (pre-installed in Cloud Shell)

## Usage

### 1. Ensure you're logged in to the correct subscription
```bash
# Check current context
az account show

# Switch to desired subscription if needed
az account set --subscription "your-subscription-id"
```

### 2. First run (new tenant)
```bash
# Execute with TenantCode parameter
./deploy-entra-groups.sh -t "7qx45m"
```

This creates:
- Administrative Unit: `7qx45m-tenant-admin`
- Tenant groups: `sec-tenant-7qx45m-*`
- Subscription groups: `sec-az-7qx45m-<prefix>-*`
- `7qx45m-config.json` file

### 3. Add another subscription
```bash
# Switch to another subscription
az account set --subscription "other-subscription-id"

# Run script (reads TenantCode from config file)
./deploy-entra-groups.sh
```

The script automatically recognizes it's the same tenant and adds the subscription to existing config.

### 4. WhatIf mode (test without changes)
```bash
./deploy-entra-groups.sh -t "7qx45m" -w
```

### 5. Entra-only mode (skip subscription setup)
```bash
./deploy-entra-groups.sh -t "7qx45m" -e
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

### Typical workflow with errors:
1. **First run**: Possible replication delay errors with RBAC
2. **Second run**: Script recognizes existing groups and only assigns missing roles
3. **Result**: All groups and roles correctly configured

## Parameters

- `-t, --tenant-code` (optional after first run): Tenant code for group names (e.g., "7qx45m")
- `-w, --whatif`: Test mode, no changes made
- `-e, --entra-only`: Only AU and Entra roles, no subscription setup
- `-c, --config-file`: Path to config file (default: `<scriptdir>/<tenantcode>-config.json`)
- `-h, --help`: Show help message

## Verification

After running the script, you can verify everything:

```bash
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
cat 7qx45m-config.json | jq .
```

## Files

- `deploy-entra-groups.sh` - Complete deployment script (standalone)
- `{tenantcode}-config.json` - Configuration with all groups and subscriptions (auto-created)
- `README.md` - This documentation

## Troubleshooting

### Common issues:

1. **"No config file found and no TenantCode parameter provided"**
   - **Solution**: Expected on first run from Cloud Shell
   - Add `-t "your-code"` parameter

2. **"Not logged in to Azure CLI"**
   - **Solution**: Run `az login --use-device-code` or use Azure Cloud Shell (already logged in)

3. **"Insufficient privileges"**
   - **Solution**: Ensure you have Global Admin + Subscription Owner rights

4. **"PrincipalNotFound" errors during RBAC assignments**
   - **Solution**: Normal on first run (replication delay)
   - Run script again, it will only assign missing roles

5. **"Group already exists" warnings**
   - **This is normal**: Script is idempotent, recognizes existing groups
   - No action needed

6. **Config file not found on second subscription**
   - **Solution**: Ensure config file is in same directory
   - Or download first from Cloud Shell storage/GitHub

### Debug information
The script shows extensive logging:
- 🔵 Cyan: Information about what's being executed
- 🟢 Green: Successful actions
- 🟡 Yellow: Warnings (usually OK)
- 🔴 Red: Errors (require action)

### Cloud Shell specific
- Scripts in Cloud Shell storage persist between sessions
- Config file is saved in same directory as script
- When using one-line piped command, config file is NOT saved
- For multi-subscription: download script first, execute locally

## Best Practices

1. **Test first with -w (WhatIf)** to see what will happen
2. **Run script twice** on new tenant (first: groups, second: fix replication delays)
3. **Save config file** for multi-subscription setups
4. **Use Cloud Shell** for quick setup without local installation
5. **Download script locally** for production use with multiple subscriptions

## Differences from PowerShell Version

The Bash version:
- ✅ Uses same logic and features as PowerShell version
- ✅ Native in Azure Cloud Shell (Bash is default)
- ✅ No PowerShell required
- ✅ Uses `jq` for JSON parsing (pre-installed in Cloud Shell)
- ✅ Same config file structure
- ✅ Same group naming conventions
- ✅ Same role assignments
- ✅ Fully tested and production-ready

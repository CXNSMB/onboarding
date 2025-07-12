# GitHub Actions Azure OIDC Onboarding

Complete setup for secure GitHub Actions authentication with Azure using OIDC (no secrets needed!).

## 🚀 Quick Start

### Standard Setup (Default Parameters)

**For CXNSMB/solution-onboarding repository:**

```bash
curl -s https://raw.githubusercontent.com/CXNSMB/onboarding/main/setup-app-registration.sh | bash
```

This uses the default parameters:
- App Name: `CXNSMB-github-solution-onboarding`
- GitHub Org: `CXNSMB`
- GitHub Repo: `solution-onboarding`
- Branch: `main`

### Custom Setup

**For your own repository:**

```bash
curl -s https://raw.githubusercontent.com/CXNSMB/onboarding/main/setup-app-registration.sh | bash -s -- "YourApp-GitHub" "your-org" "your-repo" "main"
```

**Replace the parameters:**
- `"YourApp-GitHub"` → Your app name
- `"your-org"` → Your GitHub organization
- `"your-repo"` → Your GitHub repository  
- `"main"` → Your GitHub branch

### 🔍 Verbose Mode

**Standard with verbose output:**

```bash
curl -s https://raw.githubusercontent.com/CXNSMB/onboarding/main/setup-app-registration.sh | bash -s -- "" "" "" "" verbose
```

**Custom with verbose output:**

```bash
curl -s https://raw.githubusercontent.com/CXNSMB/onboarding/main/setup-app-registration.sh | bash -s -- "YourApp-GitHub" "your-org" "your-repo" "main" verbose
```

### 🏢 Management Group Scope

**Standard with management group scope (root level access):**

```bash
curl -s https://raw.githubusercontent.com/CXNSMB/onboarding/main/setup-app-registration.sh | bash -s -- "" "" "" "" management-group
```

**Custom management group name:**

```bash
curl -s https://raw.githubusercontent.com/CXNSMB/onboarding/main/setup-app-registration.sh | bash -s -- "YourApp-GitHub" "your-org" "your-repo" "main" management-group "CXNSMB"
```

**Root management group with verbose:**

```bash
curl -s https://raw.githubusercontent.com/CXNSMB/onboarding/main/setup-app-registration.sh | bash -s -- "YourApp-GitHub" "your-org" "your-repo" "main" management-group verbose
```

**Custom management group with verbose:**

```bash
curl -s https://raw.githubusercontent.com/CXNSMB/onboarding/main/setup-app-registration.sh | bash -s -- "YourApp-GitHub" "your-org" "your-repo" "main" management-group "MyCompany" verbose
```

**Verbose mode provides:**
- ✅ Detailed step-by-step execution logs
- ✅ Current Azure context information  
- ✅ Command-by-command output
- ✅ Error troubleshooting details
- ✅ Complete resource summary

**Management group mode provides:**
- ✅ Owner role assignment at the specified management group level (or root if none specified)
- ✅ Access to all subscriptions within the target management group
- ✅ Perfect for enterprise-wide Azure governance
- ✅ Automatic creation of named management groups if they don't exist
- ✅ Fallback to root management group when no name is specified
- ⚠️ Requires management group permissions to assign roles

## 📋 Prerequisites

1. **Login to Azure Portal** as Owner or User Access Administrator
2. **Open Azure Cloud Shell** (Bash mode)
3. **Paste one of the commands above**

**That's it!** The script will:
- ✅ Create App Registration
- ✅ Create Service Principal  
- ✅ Setup Federated Credential (OIDC)
- ✅ Assign Microsoft Graph API permissions (Application.ReadWrite.All + Directory.ReadWrite.All)
- ✅ Assign Owner role (with security restrictions to prevent dangerous role assignments)

## 📋 Output

The script provides clear feedback and outputs the GitHub Secrets you need:

```
🎉 SETUP COMPLETED SUCCESSFULLY!
=================================

🎯 GitHub Secrets to add:
   AZURE_CLIENT_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
   AZURE_TENANT_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
   AZURE_SUBSCRIPTION_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx

🔒 Security: Service Principal CANNOT assign these roles:
   ❌ Owner (8e3af657-a8ff-443c-a75c-2fe8c4bcb635)
   ❌ RBAC Administrator (f58310d9-a9f6-439a-9e8d-f62e7b41a168)

✅ Service Principal HAS these roles:
   ✅ Owner (with security restrictions - cannot assign/delete Owner and RBAC Admin roles)
   ✅ Application.ReadWrite.All (Microsoft Graph API permission for app management)
   ✅ Directory.ReadWrite.All (Microsoft Graph API permission for directory operations)

✅ Ready for GitHub Actions!
```

## 📋 What gets created?

- **App Registration**: `CXNSMB-github-solution-onboarding` (default) or your custom name
- **Service Principal**: Linked to the app registration
- **Federated Credential**: For GitHub Actions OIDC (passwordless authentication)
- **Microsoft Graph API Permissions**: Application.ReadWrite.All and Directory.ReadWrite.All for app management
- **Owner Role**: With security restrictions to prevent dangerous role assignments while providing full Azure access

## 🔒 Security Features

The script assigns the **Owner role** with security restrictions using Azure RBAC conditions:

### Owner (Restricted)
- ✅ Full access to all Azure resources and services
- ✅ Can manage subscriptions, resource groups, and all resources
- ✅ Can assign most Azure roles to other users and service principals
- ✅ Perfect for comprehensive Azure management and deployments
- ❌ **Cannot** assign Owner role to anyone (including itself)
- ❌ **Cannot** assign RBAC Administrator role to anyone
- ❌ **Cannot** delete existing Owner or RBAC Administrator role assignments
- 🔒 Protected by Azure RBAC conditions

This approach provides maximum Azure access for deployments and management while preventing the service principal from escalating privileges to the most dangerous roles.

## 🔑 Microsoft Graph API Permissions

In addition to Azure RBAC roles, the script assigns Microsoft Graph API permissions for enhanced functionality:

### Application.ReadWrite.All
- ✅ Can create and manage all aspects of app registrations
- ✅ Can manage enterprise applications and service principals
- ✅ Can manage application proxy and federated credentials
- ✅ Perfect for automated application lifecycle management
- ✅ Required for managing OIDC configurations in CI/CD

### Directory.ReadWrite.All
- ✅ Can write directory objects (users, groups, applications)
- ✅ Can update directory properties and attributes
- ✅ Enables advanced Azure AD automation scenarios
- ✅ Supports identity and access management workflows

**Why these permissions are needed:**
- GitHub Actions workflows often need to manage app registrations
- Automated deployment scenarios may require directory object creation
- Enterprise environments benefit from programmatic Azure AD management
- Reduces manual intervention in identity management processes

## 🎯 Scope Options

The script supports two different scope levels for role assignment:

### Subscription Scope (Default)
- ✅ Owner role assigned to the current subscription only
- ✅ Perfect for single-subscription projects
- ✅ Requires subscription-level Owner permissions
- ✅ Simpler setup and management

### Management Group Scope
- ✅ Owner role assigned at the specified management group level (or root level if no name provided)
- ✅ Access to **all subscriptions** within the target management group
- ✅ Perfect for enterprise-wide Azure governance and multi-subscription deployments
- ✅ Enables cross-subscription resource management
- ✅ Automatically creates named management groups if they don't exist
- ✅ Defaults to root management group when no name is specified
- ⚠️ Requires management group-level Owner permissions
- ⚠️ Broad access scope - use with caution

**When to use Management Group scope:**
- Multi-subscription enterprise environments
- Cross-subscription resource deployments
- Azure landing zone implementations
- Enterprise governance scenarios
- When you need tenant-wide access

**When to use Subscription scope:**
- Single subscription projects
- Development/testing environments
- When you want to limit blast radius
- Simpler permission model

## ⚙️ Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `appName` | `CXNSMB-github-solution-onboarding` | Name of the App Registration |
| `githubOrg` | `CXNSMB` | GitHub organization name |
| `githubRepo` | `solution-onboarding` | GitHub repository name |
| `githubRef` | `main` | GitHub branch/environment |
| `verbose` | (none) | Add `verbose` for detailed logging |
| `management-group` | (none) | Add `management-group` for management group scope |
| `management-group-name` | (root) | Optional: Specify management group name (creates if needed) |

## 💡 Usage Examples

**Most common - CXNSMB solution-onboarding repo:**
```bash
curl -s https://raw.githubusercontent.com/CXNSMB/onboarding/main/setup-app-registration.sh | bash
```

**Different app name for CXNSMB/solution-onboarding:**
```bash
curl -s https://raw.githubusercontent.com/CXNSMB/onboarding/main/setup-app-registration.sh | bash -s -- "MyProject-GitHub"
```

**Different repository in CXNSMB:**
```bash
curl -s https://raw.githubusercontent.com/CXNSMB/onboarding/main/setup-app-registration.sh | bash -s -- "MyApp" "CXNSMB" "my-repo"
```

**Management group scope (enterprise-wide access):**
```bash
curl -s https://raw.githubusercontent.com/CXNSMB/onboarding/main/setup-app-registration.sh | bash -s -- "MyApp" "CXNSMB" "my-repo" "main" management-group
```

**Specific management group (CXNSMB):**
```bash
curl -s https://raw.githubusercontent.com/CXNSMB/onboarding/main/setup-app-registration.sh | bash -s -- "MyApp" "CXNSMB" "my-repo" "main" management-group "CXNSMB"
```

**Completely custom with verbose:**
```bash
curl -s https://raw.githubusercontent.com/CXNSMB/onboarding/main/setup-app-registration.sh | bash -s -- "MyApp" "my-org" "my-repo" "develop" verbose
```

**Enterprise setup with custom management group and verbose:**
```bash
curl -s https://raw.githubusercontent.com/CXNSMB/onboarding/main/setup-app-registration.sh | bash -s -- "MyApp" "my-org" "my-repo" "main" management-group "MyCompany" verbose
```

##  GitHub Actions Setup

After deployment, use these values in your GitHub Actions:

```yaml
permissions:
  id-token: write
  contents: read

steps:
  - uses: azure/login@v1
    with:
      client-id: ${{ secrets.AZURE_CLIENT_ID }}
      tenant-id: ${{ secrets.AZURE_TENANT_ID }}
      subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
```

## 🎯 GitHub Secrets

Add these secrets to your GitHub repository:

- `AZURE_CLIENT_ID`: The Application (client) ID from the deployment output
- `AZURE_TENANT_ID`: Your Azure Tenant ID
- `AZURE_SUBSCRIPTION_ID`: Your Azure Subscription ID

## ❓ Why No "Deploy to Azure" Button?

This template cannot use the standard "Deploy to Azure" button because it requires **Microsoft Graph API** operations to:

- Create App Registrations
- Configure Federated Credentials for OIDC
- Set up Service Principals with specific permissions

The Azure Resource Manager (ARM) deployment service used by "Deploy to Azure" buttons cannot access Microsoft Graph APIs, which are required for Azure AD/Entra ID operations. This is why we use the Cloud Shell script approach instead, which has the necessary permissions to interact with both Azure Resource Manager and Microsoft Graph APIs.

For security and functionality reasons, App Registration and OIDC setup must be done through dedicated tooling with proper Microsoft Graph permissions.

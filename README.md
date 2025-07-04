# GitHub Actions Azure OIDC Onboarding

Complete setup for secure GitHub Actions authentication with Azure using OIDC (no secrets needed!).

## 🚀 Quick Start

### Standard Setup (Default Parameters)

**For CXNSMB/azlighthouse repository:**

```bash
curl -s https://raw.githubusercontent.com/CXNSMB/onboarding/main/setup-app-registration.sh | bash
```

This uses the default parameters:
- App Name: `CXNSMB-github-lighthouse`
- GitHub Org: `CXNSMB`
- GitHub Repo: `azlighthouse`
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

Verbose mode provides:
- ✅ Detailed step-by-step execution logs
- ✅ Current Azure context information  
- ✅ Command-by-command output
- ✅ Error troubleshooting details
- ✅ Complete resource summary

## 📋 Prerequisites

1. **Login to Azure Portal** as Owner or User Access Administrator
2. **Open Azure Cloud Shell** (Bash mode)
3. **Paste one of the commands above**

**That's it!** The script will:
- ✅ Create App Registration
- ✅ Create Service Principal  
- ✅ Setup Federated Credential (OIDC)
- ✅ Assign User Access Administrator role (with security restrictions)
- ✅ Assign Reader role (subscription-wide read access)

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
   ❌ User Access Administrator (18d7d88d-d35e-4fb5-a5c3-7773c20a72d9)
   ❌ RBAC Administrator (f58310d9-a9f6-439a-9e8d-f62e7b41a168)

✅ Service Principal HAS these roles:
   ✅ User Access Administrator (with security restrictions)
   ✅ Reader (subscription-wide read access)

✅ Ready for GitHub Actions!
```

## 📋 What gets created?

- **App Registration**: `CXNSMB-github-lighthouse` (default) or your custom name
- **Service Principal**: Linked to the app registration
- **Federated Credential**: For GitHub Actions OIDC (passwordless authentication)
- **User Access Administrator Role**: With security restrictions to prevent dangerous role assignments
- **Reader Role**: Subscription-wide read access for monitoring and reporting

## 🔒 Security Features

The script assigns **two RBAC roles** with different security levels:

### User Access Administrator (Restricted)
- ✅ Can assign most Azure roles
- ❌ **Cannot** assign Owner role
- ❌ **Cannot** assign User Access Administrator role  
- ❌ **Cannot** assign RBAC Administrator role
- 🔒 Protected by Azure RBAC conditions

### Reader (Unrestricted)
- ✅ Can read all subscription resources
- ✅ Perfect for monitoring and cost analysis
- ✅ No modification rights

This dual-role approach provides maximum flexibility while maintaining security.

## ⚙️ Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `appName` | `CXNSMB-github-lighthouse` | Name of the App Registration |
| `githubOrg` | `CXNSMB` | GitHub organization name |
| `githubRepo` | `azlighthouse` | GitHub repository name |
| `githubRef` | `main` | GitHub branch/environment |
| `verbose` | (none) | Add `verbose` for detailed logging |

## 💡 Usage Examples

**Most common - CXNSMB azlighthouse repo:**
```bash
curl -s https://raw.githubusercontent.com/CXNSMB/onboarding/main/setup-app-registration.sh | bash
```

**Different app name for CXNSMB/azlighthouse:**
```bash
curl -s https://raw.githubusercontent.com/CXNSMB/onboarding/main/setup-app-registration.sh | bash -s -- "MyProject-GitHub"
```

**Different repository in CXNSMB:**
```bash
curl -s https://raw.githubusercontent.com/CXNSMB/onboarding/main/setup-app-registration.sh | bash -s -- "MyApp" "CXNSMB" "my-repo"
```

**Completely custom with verbose:**
```bash
curl -s https://raw.githubusercontent.com/CXNSMB/onboarding/main/setup-app-registration.sh | bash -s -- "MyApp" "my-org" "my-repo" "develop" verbose
```

## 🔧 Alternative: Full CLI Deployment

If you prefer to do everything via CLI, you can still use the original Bicep template:

```bash
# Clone the repository
git clone https://github.com/CXNSMB/onboarding.git
cd onboarding

# Deploy with Azure CLI
az deployment sub create \
  --location westeurope \
  --template-file onboarding.bicep \
  --parameters appName='your-app-name' githubOrg='your-org' githubRepo='your-repo'
```

## 📖 GitHub Actions Setup

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

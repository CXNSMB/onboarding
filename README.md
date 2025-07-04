# GitHub Actions Azure OIDC Onboarding

Complete setup for secure GitHub Actions authentication with Azure using OIDC (no secrets needed!).

## 🚀 One Command Setup

1. **Login to Azure Portal** as Owner
2. **Open Cloud Shell** (Bash mode)  
3. **Paste this command**:

```bash
curl -s https://raw.githubusercontent.com/CXNSMB/onboarding/main/setup-app-registration.sh | bash -s -- "MyApp-GitHub" "myorg" "myrepo" "main"
```

**Replace the parameters:**
- `"MyApp-GitHub"` → Your app name
- `"myorg"` → Your GitHub organization
- `"myrepo"` → Your GitHub repository  
- `"main"` → Your GitHub branch

### 🔍 Verbose Mode

For detailed logging and troubleshooting, add `verbose` as the 5th parameter:

```bash
curl -s https://raw.githubusercontent.com/CXNSMB/onboarding/main/setup-app-registration.sh | bash -s -- "MyApp-GitHub" "myorg" "myrepo" "main" verbose
```

Verbose mode provides:
- ✅ Detailed step-by-step execution logs
- ✅ Current Azure context information  
- ✅ Command-by-command output
- ✅ Error troubleshooting details
- ✅ Complete resource summary

**That's it!** The script will:
- ✅ Create App Registration
- ✅ Create Service Principal  
- ✅ Setup Federated Credential (OIDC)
- ✅ Assign RBAC with security restrictions

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
   ❌ Owner
   ❌ User Access Administrator
   ❌ RBAC Administrator

✅ Ready for GitHub Actions!
```

## 📋 What gets created?

- **App Registration**: `CXNSMB-github-lighthouse`
- **Service Principal**: Linked to the app registration
- **Federated Credential**: For GitHub Actions OIDC (passwordless authentication)
- **RBAC Assignment**: User Access Administrator role with security restrictions

## 🔒 Security Features

The template contains a **condition** that prevents the service principal from assigning these dangerous roles:

- ❌ Owner
- ❌ User Access Administrator  
- ❌ RBAC Administrator

## ⚙️ Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `appName` | `CXNSMB-github-lighthouse` | Name of the App Registration |
| `githubOrg` | `CXNSMB` | GitHub organization name |
| `githubRepo` | `onboarding` | GitHub repository name |
| `githubRef` | `main` | GitHub branch/environment |

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

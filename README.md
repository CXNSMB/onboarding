# GitHub Actions Azure OIDC Onboarding

This repository contains a Bicep/ARM template for setting up a secure Azure App Registration with Service Principal for GitHub Actions OIDC authentication.

## 🚀 Quick Deploy

Click the button below to deploy directly to Azure:

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FCXNSMB%2Fonboarding%2Fmain%2Fdeploy-to-azure.json)

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

## 🔧 Manual Deployment

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

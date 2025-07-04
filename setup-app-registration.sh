#!/bin/bash
# GitHub Actions Azure OIDC Setup - One-liner for Cloud Shell
# Usage: curl -s https://raw.githubusercontent.com/CXNSMB/onboarding/main/setup-app-registration.sh | bash -s -- "app-name" "github-org" "github-repo" "branch"

APP_NAME="${1:-CXNSMB-github-lighthouse}"
GITHUB_ORG="${2:-CXNSMB}"
GITHUB_REPO="${3:-onboarding}"
GITHUB_REF="${4:-main}"

# Create App Registration
APP_ID=$(az ad app create --display-name "$APP_NAME" --query appId -o tsv 2>/dev/null)
if [ -z "$APP_ID" ]; then
  echo "❌ FAILED - Could not create App Registration"
  exit 1
fi

# Create Service Principal
SP_ID=$(az ad sp create --id $APP_ID --query id -o tsv 2>/dev/null)
if [ -z "$SP_ID" ]; then
  echo "❌ FAILED - Could not create Service Principal"
  exit 1
fi

# Create Federated Credential
az ad app federated-credential create --id $APP_ID --parameters "{\"name\":\"github-$GITHUB_REPO-$GITHUB_REF\",\"issuer\":\"https://token.actions.githubusercontent.com\",\"subject\":\"repo:$GITHUB_ORG/$GITHUB_REPO:ref:refs/heads/$GITHUB_REF\",\"audiences\":[\"api://AzureADTokenExchange\"]}" >/dev/null 2>&1

if [ $? -ne 0 ]; then
  echo "❌ FAILED - Could not create Federated Credential"
  exit 1
fi

echo "✅ SUCCEEDED"
echo ""
echo "🎯 AZURE_CLIENT_ID: $APP_ID"
echo ""
echo "Next: Deploy RBAC using Deploy to Azure button with SP Object ID: $SP_ID"

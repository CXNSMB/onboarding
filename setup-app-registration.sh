#!/bin/bash
# GitHub Actions Azure OIDC Complete Setup
# One command to rule them all - creates App Registration, Service Principal, Federated Credential, and RBAC assignment

echo "🚀 GitHub Actions Azure OIDC Complete Setup"
echo "=============================================="

# Parameters
APP_NAME="${1:-CXNSMB-github-lighthouse}"
GITHUB_ORG="${2:-CXNSMB}"
GITHUB_REPO="${3:-onboarding}"
GITHUB_REF="${4:-main}"

echo "📋 Configuration:"
echo "   App Name: $APP_NAME"
echo "   GitHub: $GITHUB_ORG/$GITHUB_REPO (branch: $GITHUB_REF)"
echo ""

# Step 1: App Registration
echo "📌 Step 1/4: Creating App Registration..."
APP_ID=$(az ad app create --display-name "$APP_NAME" --query appId -o tsv 2>/dev/null)
if [ -z "$APP_ID" ]; then
  echo "❌ FAILED - Could not create App Registration"
  exit 1
fi
echo "✅ App Registration created: $APP_ID"
echo ""

# Wait for Azure AD to propagate
echo "⏳ Waiting for Azure AD propagation (10 seconds)..."
sleep 10

# Step 2: Service Principal
echo "🔄 Step 2/4: Creating Service Principal..."
SP_ID=$(az ad sp create --id $APP_ID --query id -o tsv 2>/dev/null)
if [ -z "$SP_ID" ]; then
  echo "❌ FAILED - Could not create Service Principal"
  exit 1
fi
echo "✅ Service Principal created: $SP_ID"
echo ""

# Wait for Service Principal to be ready
echo "⏳ Waiting for Service Principal to be ready (5 seconds)..."
sleep 5

# Step 3: Federated Credential
echo "🔐 Step 3/4: Creating Federated Credential..."
az ad app federated-credential create --id $APP_ID --parameters "{\"name\":\"github-$GITHUB_REPO-$GITHUB_REF\",\"issuer\":\"https://token.actions.githubusercontent.com\",\"subject\":\"repo:$GITHUB_ORG/$GITHUB_REPO:ref:refs/heads/$GITHUB_REF\",\"audiences\":[\"api://AzureADTokenExchange\"]}" >/dev/null 2>&1

if [ $? -ne 0 ]; then
  echo "❌ FAILED - Could not create Federated Credential"
  exit 1
fi
echo "✅ Federated Credential created"
echo ""

# Step 4: RBAC Assignment
echo "🔓 Step 4/4: Assigning RBAC permissions..."

# Get current subscription
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)

# Create role assignment with conditions
ROLE_DEF_ID="18d7d88d-d35e-4fb5-a5c3-7773c20a72d9"  # User Access Administrator
ASSIGNMENT_NAME=$(uuidgen)

# RBAC assignment with security conditions
CONDITION='((!(ActionMatches{'\''Microsoft.Authorization/roleAssignments/write'\''})) OR (@Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAllValues:GuidNotEquals {8e3af657-a8ff-443c-a75c-2fe8c4bcb635, 18d7d88d-d35e-4fb5-a5c3-7773c20a72d9, f58310d9-a9f6-439a-9e8d-f62e7b41a168})) AND ((!(ActionMatches{'\''Microsoft.Authorization/roleAssignments/delete'\''})) OR (@Resource[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAllValues:GuidNotEquals {8e3af657-a8ff-443c-a75c-2fe8c4bcb635, 18d7d88d-d35e-4fb5-a5c3-7773c20a72d9, f58310d9-a9f6-439a-9e8d-f62e7b41a168}))'

az role assignment create \
  --assignee $SP_ID \
  --role $ROLE_DEF_ID \
  --scope "/subscriptions/$SUBSCRIPTION_ID" \
  --description "GitHub Actions service principal - cannot assign/delete Owner, User Access Admin and RBAC Admin roles" \
  --condition "$CONDITION" \
  --condition-version "2.0" >/dev/null 2>&1

if [ $? -ne 0 ]; then
  echo "❌ FAILED - Could not create RBAC assignment"
  echo "   Note: You may need Owner permissions to assign roles with conditions"
  exit 1
fi
echo "✅ RBAC assignment created with security restrictions"
echo ""

echo "🎉 SETUP COMPLETED SUCCESSFULLY!"
echo "================================="
echo ""
echo "🎯 GitHub Secrets to add:"
echo "   AZURE_CLIENT_ID=$APP_ID"
echo "   AZURE_TENANT_ID=$TENANT_ID"
echo "   AZURE_SUBSCRIPTION_ID=$SUBSCRIPTION_ID"
echo ""
echo "🔒 Security: Service Principal CANNOT assign these roles:"
echo "   ❌ Owner"
echo "   ❌ User Access Administrator"
echo "   ❌ RBAC Administrator"
echo ""
echo "✅ Ready for GitHub Actions!"

#!/bin/bash
# GitHub Actions Azure OIDC Complete Setup
# Usage: curl -s https://raw.githubusercontent.com/CXNSMB/onboarding/main/setup-app-registration.sh | bash -s -- "app-name" "github-org" "github-repo" "branch" [verbose]

# Check for verbose mode
VERBOSE=""
if [[ "$5" == "verbose" || "$5" == "-v" || "$5" == "--verbose" ]]; then
    VERBOSE="true"
fi

# Verbose logging function
log_verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo "🔍 [VERBOSE] $1"
    fi
}

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
if [[ "$VERBOSE" == "true" ]]; then
    echo "   Verbose Mode: ENABLED"
fi
echo ""

log_verbose "Current Azure context:"
if [[ "$VERBOSE" == "true" ]]; then
    CURRENT_SUB=$(az account show --query name -o tsv 2>/dev/null)
    CURRENT_TENANT=$(az account show --query tenantDisplayName -o tsv 2>/dev/null)
    echo "🔍 [VERBOSE]   Subscription: $CURRENT_SUB"
    echo "🔍 [VERBOSE]   Tenant: $CURRENT_TENANT"
    echo ""
fi

# Step 1: App Registration
echo "📌 Step 1/4: Creating App Registration..."
log_verbose "Executing: az ad app create --display-name \"$APP_NAME\""

if [[ "$VERBOSE" == "true" ]]; then
    APP_ID=$(az ad app create --display-name "$APP_NAME" --query appId -o tsv)
    APP_CREATE_STATUS=$?
else
    APP_ID=$(az ad app create --display-name "$APP_NAME" --query appId -o tsv 2>/dev/null)
    APP_CREATE_STATUS=$?
fi

if [ $APP_CREATE_STATUS -ne 0 ] || [ -z "$APP_ID" ]; then
    echo "❌ FAILED - Could not create App Registration"
    log_verbose "Error details: Check if app name already exists or if you have sufficient permissions"
    exit 1
fi
echo "✅ App Registration created: $APP_ID"
log_verbose "App Registration Object ID: $(az ad app show --id $APP_ID --query id -o tsv)"
echo ""

# Wait for Azure AD to propagate
echo "⏳ Waiting for Azure AD propagation (10 seconds)..."
log_verbose "Azure AD needs time to replicate the new App Registration across all regions"
if [[ "$VERBOSE" == "true" ]]; then
    for i in {10..1}; do
        echo "🔍 [VERBOSE] Waiting... $i seconds remaining"
        sleep 1
    done
else
    sleep 10
fi
log_verbose "Azure AD propagation wait completed"
echo ""

# Step 2: Service Principal
echo "🔄 Step 2/4: Creating Service Principal..."
log_verbose "Executing: az ad sp create --id $APP_ID"

if [[ "$VERBOSE" == "true" ]]; then
    SP_ID=$(az ad sp create --id $APP_ID --query id -o tsv)
    SP_CREATE_STATUS=$?
else
    SP_ID=$(az ad sp create --id $APP_ID --query id -o tsv 2>/dev/null)
    SP_CREATE_STATUS=$?
fi

if [ $SP_CREATE_STATUS -ne 0 ] || [ -z "$SP_ID" ]; then
    echo "❌ FAILED - Could not create Service Principal"
    log_verbose "Error details: App Registration may not be fully propagated yet"
    exit 1
fi
echo "✅ Service Principal created: $SP_ID"
log_verbose "Service Principal will be used for RBAC assignments"
echo ""

# Wait for Service Principal to be ready
echo "⏳ Waiting for Service Principal to be ready (5 seconds)..."
log_verbose "Service Principal needs time to become available for role assignments"
if [[ "$VERBOSE" == "true" ]]; then
    for i in {5..1}; do
        echo "🔍 [VERBOSE] Waiting... $i seconds remaining"
        sleep 1
    done
else
    sleep 5
fi
log_verbose "Service Principal readiness wait completed"
echo ""

# Step 3: Federated Credential
echo "🔐 Step 3/4: Creating Federated Credential..."
SUBJECT="repo:$GITHUB_ORG/$GITHUB_REPO:ref:refs/heads/$GITHUB_REF"
CREDENTIAL_NAME="github-$GITHUB_REPO-$GITHUB_REF"

log_verbose "Federated Credential details:"
log_verbose "  Name: $CREDENTIAL_NAME"
log_verbose "  Issuer: https://token.actions.githubusercontent.com"
log_verbose "  Subject: $SUBJECT"
log_verbose "  Audience: api://AzureADTokenExchange"

if [[ "$VERBOSE" == "true" ]]; then
    az ad app federated-credential create --id $APP_ID --parameters "{\"name\":\"$CREDENTIAL_NAME\",\"issuer\":\"https://token.actions.githubusercontent.com\",\"subject\":\"$SUBJECT\",\"audiences\":[\"api://AzureADTokenExchange\"]}"
    CRED_CREATE_STATUS=$?
else
    az ad app federated-credential create --id $APP_ID --parameters "{\"name\":\"$CREDENTIAL_NAME\",\"issuer\":\"https://token.actions.githubusercontent.com\",\"subject\":\"$SUBJECT\",\"audiences\":[\"api://AzureADTokenExchange\"]}" >/dev/null 2>&1
    CRED_CREATE_STATUS=$?
fi

if [ $CRED_CREATE_STATUS -ne 0 ]; then
    echo "❌ FAILED - Could not create Federated Credential"
    log_verbose "Error details: Check if credential name already exists or GitHub details are correct"
    exit 1
fi
echo "✅ Federated Credential created"
log_verbose "GitHub Actions can now authenticate without secrets using OIDC"
echo ""

# Step 4: RBAC Assignment
echo "🔓 Step 4/4: Assigning RBAC permissions..."

# Get current subscription
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)

log_verbose "RBAC Assignment details:"
log_verbose "  Role: User Access Administrator (18d7d88d-d35e-4fb5-a5c3-7773c20a72d9)"
log_verbose "  Assignee: $SP_ID"
log_verbose "  Scope: /subscriptions/$SUBSCRIPTION_ID"
log_verbose "  Condition: Blocks Owner, User Access Admin, RBAC Admin assignments"

# Create role assignment with conditions
ROLE_DEF_ID="18d7d88d-d35e-4fb5-a5c3-7773c20a72d9"  # User Access Administrator

# RBAC assignment with security conditions
CONDITION='((!(ActionMatches{'\''Microsoft.Authorization/roleAssignments/write'\''})) OR (@Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAllValues:GuidNotEquals {8e3af657-a8ff-443c-a75c-2fe8c4bcb635, 18d7d88d-d35e-4fb5-a5c3-7773c20a72d9, f58310d9-a9f6-439a-9e8d-f62e7b41a168})) AND ((!(ActionMatches{'\''Microsoft.Authorization/roleAssignments/delete'\''})) OR (@Resource[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAllValues:GuidNotEquals {8e3af657-a8ff-443c-a75c-2fe8c4bcb635, 18d7d88d-d35e-4fb5-a5c3-7773c20a72d9, f58310d9-a9f6-439a-9e8d-f62e7b41a168}))'

if [[ "$VERBOSE" == "true" ]]; then
    echo "🔍 [VERBOSE] Executing role assignment with conditions..."
    az role assignment create \
      --assignee $SP_ID \
      --role $ROLE_DEF_ID \
      --scope "/subscriptions/$SUBSCRIPTION_ID" \
      --description "GitHub Actions service principal - cannot assign/delete Owner, User Access Admin and RBAC Admin roles" \
      --condition "$CONDITION" \
      --condition-version "2.0"
    RBAC_CREATE_STATUS=$?
else
    az role assignment create \
      --assignee $SP_ID \
      --role $ROLE_DEF_ID \
      --scope "/subscriptions/$SUBSCRIPTION_ID" \
      --description "GitHub Actions service principal - cannot assign/delete Owner, User Access Admin and RBAC Admin roles" \
      --condition "$CONDITION" \
      --condition-version "2.0" >/dev/null 2>&1
    RBAC_CREATE_STATUS=$?
fi

if [ $RBAC_CREATE_STATUS -ne 0 ]; then
    echo "❌ FAILED - Could not create RBAC assignment"
    log_verbose "Error details: You may need Owner permissions to assign roles with conditions"
    log_verbose "Alternative: Assign User Access Administrator role manually in Azure Portal"
    exit 1
fi
echo "✅ RBAC assignment created with security restrictions"
log_verbose "Service Principal can now manage most role assignments except dangerous ones"
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
echo "   ❌ Owner (8e3af657-a8ff-443c-a75c-2fe8c4bcb635)"
echo "   ❌ User Access Administrator (18d7d88d-d35e-4fb5-a5c3-7773c20a72d9)"
echo "   ❌ RBAC Administrator (f58310d9-a9f6-439a-9e8d-f62e7b41a168)"
echo ""

if [[ "$VERBOSE" == "true" ]]; then
    echo "🔍 [VERBOSE] Summary of created resources:"
    echo "🔍 [VERBOSE]   App Registration: $APP_NAME (ID: $APP_ID)"
    echo "🔍 [VERBOSE]   Service Principal: $SP_ID"
    echo "🔍 [VERBOSE]   Federated Credential: $CREDENTIAL_NAME"
    echo "🔍 [VERBOSE]   RBAC Role: User Access Administrator with conditions"
    echo "🔍 [VERBOSE]   Subscription: $SUBSCRIPTION_ID"
    echo "🔍 [VERBOSE]   Tenant: $TENANT_ID"
    echo ""
fi

echo "✅ Ready for GitHub Actions!"

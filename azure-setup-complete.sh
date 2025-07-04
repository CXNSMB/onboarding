#!/bin/bash
# Complete Azure App Registration setup with OIDC for GitHub Actions
# Run this in Azure Cloud Shell

#set -e  # Exit on any error

# Configuration
APP_NAME="CXNSMB-github-lh"
GITHUB_REPO="CXNSMB/onboarding"
GITHUB_REF="refs/heads/main"
ROLE_DEFINITION_ID="18d7d88d-d35e-4fb5-a5c3-7773c20a72d9"  # User Access Administrator

# ❌ Verboden rollen die deze app NIET mag toekennen aan anderen (voor veiligheid)
# Let op: De app krijgt zelf wel User Access Administrator om rollen te kunnen beheren
FORBIDDEN_ROLES_TO_ASSIGN=(
    "8e3af657-a8ff-443c-a75c-2fe8c4bcb635"  # Owner
    "18d7d88d-d35e-4fb5-a5c3-7773c20a72d9"  # User Access Administrator  
    "f58310d9-a9f6-439a-9e8d-f62e7b41a168"  # RBAC Administrator
)

echo "🚀 Starting Azure App Registration setup..."
echo "App Name: $APP_NAME"
echo "GitHub Repo: $GITHUB_REPO"
echo "GitHub Ref: $GITHUB_REF"
echo "Role: $ROLE_DEFINITION_ID"
echo ""

# Get current subscription info
SUBSCRIPTION_ID=$(az account show --query id --output tsv)
SUBSCRIPTION_NAME=$(az account show --query name --output tsv)
TENANT_ID=$(az account show --query tenantId --output tsv)

echo "📋 Current Azure context:"
echo "Subscription: $SUBSCRIPTION_NAME ($SUBSCRIPTION_ID)"
echo "Tenant: $TENANT_ID"
echo ""

# Check if app already exists
echo "🔍 Checking if app registration already exists..."
EXISTING_APP=$(az ad app list --query "[?displayName=='$APP_NAME'].appId" --output tsv)

if [ -n "$EXISTING_APP" ]; then
    echo "✅ App registration already exists with ID: $EXISTING_APP"
    APP_ID=$EXISTING_APP
else
    echo "📌 Creating App Registration..."
    
    # Create app registration
    APP_ID=$(az ad app create \
        --display-name "$APP_NAME" \
        --query appId \
        --output tsv)
    
    echo "✅ App Registration created with ID: $APP_ID"
fi

# Create service principal if it doesn't exist
echo "🔄 Checking Service Principal for App ID: $APP_ID..."
SP_ID=$(az ad sp list --query "[?appId=='$APP_ID'].id" --output tsv)

if [ -n "$SP_ID" ]; then
    echo "✅ Service Principal already exists with ID: $SP_ID"
else
    echo "📌 Creating Service Principal..."
    
    # Capture both stdout and stderr to handle creation errors properly
    CREATE_OUTPUT=$(az ad sp create --id $APP_ID --query id --output tsv 2>&1)
    CREATE_STATUS=$?
    
    if [ $CREATE_STATUS -eq 0 ] && [ -n "$CREATE_OUTPUT" ]; then
        SP_ID=$CREATE_OUTPUT
        echo "✅ Service Principal created with ID: $SP_ID"
    else
        # Creation failed - check if it already exists
        echo "⚠️  Service Principal creation failed (might already exist): $CREATE_OUTPUT"
        echo "   Checking for existing Service Principal..."
        sleep 2
        SP_ID=$(az ad sp list --query "[?appId=='$APP_ID'].id" --output tsv)
        
        if [ -n "$SP_ID" ]; then
            echo "✅ Found existing Service Principal with ID: $SP_ID"
        else
            echo "❌ ERROR: Could not create or find Service Principal for App ID: $APP_ID"
            echo "   Creation output: $CREATE_OUTPUT"
            echo "   Please check your permissions and try again."
            exit 1
        fi
    fi
fi

# Verify SP_ID is not empty before proceeding
if [ -z "$SP_ID" ]; then
    echo "❌ ERROR: Service Principal ID is empty. Cannot continue."
    exit 1
fi

echo "🔍 Service Principal verification complete. SP_ID: $SP_ID"

# Assign RBAC role
echo "🔓 Assigning RBAC role..."
echo "   Assigning User Access Administrator to enable role management..."

# Controleer of rol al bestaat met de juiste condition
echo "   Checking if role assignment with security conditions exists..."
ROLE_ASSIGNMENT_WITH_CONDITION=$(az role assignment list \
    --assignee "$SP_ID" \
    --role "$ROLE_DEFINITION_ID" \
    --scope "/subscriptions/$SUBSCRIPTION_ID" \
    --query "[?condition != null].name" \
    --output tsv)

if [ -n "$ROLE_ASSIGNMENT_WITH_CONDITION" ]; then
    ROLE_ASSIGNMENT_EXISTS=1
    echo "   ✅ Role assignment with conditions already exists"
else
    # Check if there's an assignment without conditions (need to update it)
    ROLE_ASSIGNMENT_WITHOUT_CONDITION=$(az role assignment list \
        --assignee "$SP_ID" \
        --role "$ROLE_DEFINITION_ID" \
        --scope "/subscriptions/$SUBSCRIPTION_ID" \
        --query "[?condition == null].name" \
        --output tsv)
    
    if [ -n "$ROLE_ASSIGNMENT_WITHOUT_CONDITION" ]; then
        echo "   ⚠️  Found role assignment without security conditions, will update..."
        # Delete the old assignment without conditions
        az role assignment delete \
            --assignee "$SP_ID" \
            --role "$ROLE_DEFINITION_ID" \
            --scope "/subscriptions/$SUBSCRIPTION_ID"
        echo "   🗑️  Removed old assignment without conditions"
        ROLE_ASSIGNMENT_EXISTS=0
    else
        ROLE_ASSIGNMENT_EXISTS=0
    fi
fi

if [ "$ROLE_ASSIGNMENT_EXISTS" -eq 1 ]; then
    echo "✅ RBAC role with security conditions already assigned"
else
    echo "   Creating role assignment with conditions to prevent forbidden role assignments..."
    
    # Create condition to prevent assigning forbidden roles
    CONDITION='(
        (
            !(ActionMatches{"Microsoft.Authorization/roleAssignments/write"})
        )
        OR
        (
            ActionMatches{"Microsoft.Authorization/roleAssignments/write"}
            AND
            NOT (
                Resource[Microsoft.Authorization/roleAssignments:RoleDefinitionId] StringEquals "8e3af657-a8ff-443c-a75c-2fe8c4bcb635"
                OR
                Resource[Microsoft.Authorization/roleAssignments:RoleDefinitionId] StringEquals "18d7d88d-d35e-4fb5-a5c3-7773c20a72d9"
                OR
                Resource[Microsoft.Authorization/roleAssignments:RoleDefinitionId] StringEquals "f58310d9-a9f6-439a-9e8d-f62e7b41a168"
            )
        )
    )'
    
    az role assignment create \
        --assignee "$SP_ID" \
        --role "$ROLE_DEFINITION_ID" \
        --scope "/subscriptions/$SUBSCRIPTION_ID" \
        --condition "$CONDITION" \
        --condition-version "2.0"
        
    echo "✅ RBAC role assigned successfully with security conditions"
fi

# Create federated identity credential
echo "🔗 Creating Federated Identity Credential..."

# Check if credential already exists
EXISTING_CRED=$(az ad app federated-credential list --id $APP_ID --query "[?name=='github-oidc'].name" --output tsv)

if [ -n "$EXISTING_CRED" ]; then
    echo "✅ Federated credential already exists"
else
    # Create the federated credential
    az ad app federated-credential create \
        --id $APP_ID \
        --parameters "{
            \"name\": \"github-oidc\",
            \"issuer\": \"https://token.actions.githubusercontent.com\",
            \"subject\": \"repo:$GITHUB_REPO:ref:$GITHUB_REF\",
            \"description\": \"GitHub Actions OIDC federated credential\",
            \"audiences\": [\"api://AzureADTokenExchange\"]
        }"
    echo "✅ Federated credential created successfully"
fi

# Verify setup
echo ""
echo "🔍 Verifying setup..."
echo "App Registration:"
az ad app show --id $APP_ID --query "{displayName:displayName, appId:appId}" --output table

echo ""
echo "Service Principal:"
az ad sp show --id $SP_ID --query "{displayName:displayName, appId:appId}" --output table

echo ""
echo "Federated Credentials:"
az ad app federated-credential list --id $APP_ID --output table

echo ""
echo "Role Assignments:"
az role assignment list --assignee $SP_ID --output table

echo ""
echo "🎉 Setup completed successfully!"
echo ""
echo "⚠️  Security Note:"
echo "   This app has User Access Administrator permissions to manage roles."
echo "   Please ensure your deployment scripts do NOT assign these forbidden roles:"
echo "   - Owner (8e3af657-a8ff-443c-a75c-2fe8c4bcb635)"
echo "   - User Access Administrator (18d7d88d-d35e-4fb5-a5c3-7773c20a72d9)"
echo "   - RBAC Administrator (f58310d9-a9f6-439a-9e8d-f62e7b41a168)"
echo ""
echo "   Safe roles to assign:"
echo "   - Contributor (b24988ac-6180-42a0-ab88-20f7382dd24c)"
echo "   - Reader (acdd72a7-3385-48ef-bd42-f606fba81ae7)"
echo "   - Storage Account Contributor (17d1049b-9a84-46fb-8f53-869881c3d3ab)"
echo ""
echo "📝 GitHub Actions Configuration:"
echo "Add these secrets to your GitHub repository:"
echo ""
echo "AZURE_CLIENT_ID: $APP_ID"
echo "AZURE_TENANT_ID: $TENANT_ID"
echo "AZURE_SUBSCRIPTION_ID: $SUBSCRIPTION_ID"
echo ""
echo "Example GitHub Actions workflow:"
echo ""
cat << 'EOF'
name: Azure Deployment
on:
  push:
    branches: [ main ]

jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Azure Login
      uses: azure/login@v1
      with:
        client-id: ${{ secrets.AZURE_CLIENT_ID }}
        tenant-id: ${{ secrets.AZURE_TENANT_ID }}
        subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
    
    - name: Deploy to Azure
      run: |
        az --version
        # Example: Deploy with safe role assignments
        az deployment sub create \
          --location "West Europe" \
          --template-file "main.bicep" \
          --parameters roleDefinitionId="b24988ac-6180-42a0-ab88-20f7382dd24c"
EOF

echo ""
echo "📋 Example Bicep role assignment validation:"
echo ""
cat << 'EOF'
// In your Bicep template - add this validation
param roleDefinitionId string = 'b24988ac-6180-42a0-ab88-20f7382dd24c'

// ❌ Verboden rollen
var forbiddenRoles = [
  '8e3af657-a8ff-443c-a75c-2fe8c4bcb635' // Owner
  '18d7d88d-d35e-4fb5-a5c3-7773c20a72d9' // User Access Administrator
  'f58310d9-a9f6-439a-9e8d-f62e7b41a168' // RBAC Administrator
]

@assert(!contains(forbiddenRoles, roleDefinitionId), 'Deze rol mag niet toegekend worden. Kies een veiligere rol zoals Contributor.')

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(subscription().subscriptionId, principalId, roleDefinitionId)
  properties: {
    principalId: principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
  }
}
EOF

echo ""
echo "✅ All done! Your GitHub Actions can now authenticate to Azure using OIDC."

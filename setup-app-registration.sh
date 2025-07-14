#!/bin/bash
# GitHub Actions Azure OIDC Complete Setup
# Usage: curl -s https://raw.githubusercontent.com/CXNSMB/onboarding/main/setup-app-registration.sh | bash -s -- "subscription-id" "github-org" "github-repo" "branch" [verbose|management-group] [management-group-name]
# For dev version: curl -s https://raw.githubusercontent.com/CXNSMB/onboarding/dev/setup-app-registration.sh | bash -s -- "subscription-id" "github-org" "github-repo" "branch" [verbose|management-group] [management-group-name]

# Check for verbose mode and management group mode
VERBOSE=""
MANAGEMENT_GROUP_MODE=""
MANAGEMENT_GROUP_NAME=""

# Process parameters 5 and 6 for options
for param in "$5" "$6"; do
    if [[ "$param" == "verbose" || "$param" == "-v" || "$param" == "--verbose" ]]; then
        VERBOSE="true"
    elif [[ "$param" == "management-group" || "$param" == "mg" || "$param" == "--management-group" ]]; then
        MANAGEMENT_GROUP_MODE="true"
    elif [[ "$MANAGEMENT_GROUP_MODE" == "true" && ! -z "$param" && "$param" != "verbose" && "$param" != "-v" && "$param" != "--verbose" ]]; then
        # This is a management group name
        MANAGEMENT_GROUP_NAME="$param"
    fi
done

# Verbose logging function
log_verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo "🔍 [VERBOSE] $1"
    fi
}

echo "🚀 GitHub Actions Azure OIDC Complete Setup"
echo "=============================================="

# Quick Azure CLI connectivity check
echo "🔍 Checking Azure CLI connectivity..."
if ! az account show >/dev/null 2>&1; then
    echo "❌ FAILED - Not logged into Azure CLI"
    echo "Please run: az login"
    exit 1
fi

# Get tenant ID for app name generation
TENANT_ID=$(az account show --query tenantId -o tsv 2>/dev/null)
if [ -z "$TENANT_ID" ]; then
    echo "❌ FAILED - Could not retrieve tenant ID"
    exit 1
fi

# Parameters
SUBSCRIPTION_ID="${1}"
GITHUB_ORG="${2:-CXNSMB}"
GITHUB_REPO="${3:-solution-onboarding}"
GITHUB_REF="${4:-main}"

# Generate app name: <github-org>-github-<repo>-<tenant-id>
APP_NAME="${GITHUB_ORG}-github-${GITHUB_REPO}-${TENANT_ID}"
log_verbose "Generated app name: $APP_NAME"

# Check subscription logic
if [[ ! -z "$SUBSCRIPTION_ID" ]]; then
    # Subscription ID provided, validate and use it
    echo "🔄 Setting subscription to: $SUBSCRIPTION_ID"
    log_verbose "Switching to subscription: $SUBSCRIPTION_ID"
    
    # Verify subscription exists and user has access
    SUBSCRIPTION_NAME=$(az account show --subscription "$SUBSCRIPTION_ID" --query name -o tsv 2>/dev/null)
    if [ $? -ne 0 ] || [ -z "$SUBSCRIPTION_NAME" ]; then
        echo "❌ FAILED - Cannot access subscription: $SUBSCRIPTION_ID"
        echo "Please check if:"
        echo "   1. The subscription ID is correct"
        echo "   2. You have access to this subscription"
        echo "   3. The subscription is active"
        exit 1
    fi
    
    # Set the subscription
    if [[ "$VERBOSE" == "true" ]]; then
        az account set --subscription "$SUBSCRIPTION_ID"
        SET_STATUS=$?
    else
        az account set --subscription "$SUBSCRIPTION_ID" >/dev/null 2>&1
        SET_STATUS=$?
    fi
    
    if [ $SET_STATUS -ne 0 ]; then
        echo "❌ FAILED - Could not switch to subscription: $SUBSCRIPTION_ID"
        echo "Please check your permissions for this subscription"
        exit 1
    fi
    
    echo "✅ Successfully switched to subscription: $SUBSCRIPTION_NAME"
    log_verbose "Active subscription is now: $SUBSCRIPTION_NAME (ID: $SUBSCRIPTION_ID)"
else
    # No subscription ID provided, check available subscriptions
    log_verbose "No subscription ID provided, checking available subscriptions..."
    
    # Get list of subscriptions
    mapfile -t SUBSCRIPTIONS < <(az account list --query "[].{name:name, id:id, isDefault:isDefault}" -o tsv)
    
    if [ ${#SUBSCRIPTIONS[@]} -eq 0 ]; then
        echo "❌ FAILED - No subscriptions found"
        echo "Please check your Azure access permissions"
        exit 1
    elif [ ${#SUBSCRIPTIONS[@]} -eq 1 ]; then
        # Only one subscription, use it automatically
        IFS=$'\t' read -r name id isDefault <<< "${SUBSCRIPTIONS[0]}"
        echo "📝 Only one subscription found, using: $name"
        log_verbose "Automatically using single subscription: $name (ID: $id)"
        
        if [[ "$isDefault" != "true" ]]; then
            # Set as active if not already active
            if [[ "$VERBOSE" == "true" ]]; then
                az account set --subscription "$id"
                SET_STATUS=$?
            else
                az account set --subscription "$id" >/dev/null 2>&1
                SET_STATUS=$?
            fi
            
            if [ $SET_STATUS -ne 0 ]; then
                echo "❌ FAILED - Could not switch to subscription: $name"
                echo "Please check your permissions for this subscription"
                exit 1
            fi
            
            echo "✅ Successfully switched to subscription: $name"
            log_verbose "Active subscription is now: $name (ID: $id)"
        else
            echo "✅ Using current subscription: $name"
            log_verbose "Subscription was already active: $name (ID: $id)"
        fi
    else
        # Multiple subscriptions found, show options with curl syntax
        echo ""
        echo "📋 Multiple Azure Subscriptions Found"
        echo "======================================"
        echo ""
        echo "Please run the script again with a specific subscription ID:"
        echo ""
        
        # Get the script URL (try to detect if this is from curl or local)
        SCRIPT_URL="https://raw.githubusercontent.com/CXNSMB/onboarding/main/setup-app-registration.sh"
        
        # Generate curl command for each subscription
        for i in "${!SUBSCRIPTIONS[@]}"; do
            IFS=$'\t' read -r name id isDefault <<< "${SUBSCRIPTIONS[i]}"
            echo "🔹 $name"
            if [[ "$isDefault" == "true" ]]; then
                echo "   [CURRENT]"
            fi
            
            # Build curl command with subscription ID as first parameter
            CURL_CMD="curl -s $SCRIPT_URL | bash -s -- \"$id\" \"$GITHUB_ORG\" \"$GITHUB_REPO\" \"$GITHUB_REF\""
            
            # Add verbose if it was specified
            if [[ "$VERBOSE" == "true" ]]; then
                CURL_CMD="$CURL_CMD \"verbose\""
            fi
            
            # Add management group options if specified
            if [[ "$MANAGEMENT_GROUP_MODE" == "true" ]]; then
                CURL_CMD="$CURL_CMD \"management-group\""
                if [[ ! -z "$MANAGEMENT_GROUP_NAME" ]]; then
                    CURL_CMD="$CURL_CMD \"$MANAGEMENT_GROUP_NAME\""
                fi
            fi
            
            echo "   $CURL_CMD"
            echo ""
        done
        
        echo "💡 Tip: Copy and paste one of the commands above to run with your desired subscription."
        echo ""
        exit 0
    fi
fi
echo ""

echo "📋 Configuration:"
echo "   App Name: $APP_NAME"
echo "   GitHub: $GITHUB_ORG/$GITHUB_REPO (branch: $GITHUB_REF)"
if [[ "$VERBOSE" == "true" ]]; then
    echo "   Verbose Mode: ENABLED"
fi
if [[ "$MANAGEMENT_GROUP_MODE" == "true" ]]; then
    if [[ ! -z "$MANAGEMENT_GROUP_NAME" ]]; then
        echo "   Scope: Management Group ($MANAGEMENT_GROUP_NAME)"
    else
        echo "   Scope: Management Group (root level)"
    fi
else
    echo "   Scope: Current Subscription"
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

# Register required Azure Resource Providers
echo "📌 Registering Azure Resource Providers..."
log_verbose "Registering required resource providers for Azure services"

PROVIDERS=(
    "Microsoft.Batch"
    "Microsoft.Compute" 
    "Microsoft.Capacity"
    "Microsoft.ManagedIdentity"
    "Microsoft.ManagedServices"
)

for provider in "${PROVIDERS[@]}"; do
    log_verbose "Registering provider: $provider"
    if [[ "$VERBOSE" == "true" ]]; then
        az provider register --namespace "$provider"
    else
        az provider register --namespace "$provider" >/dev/null 2>&1
    fi
    echo "✅ Registered: $provider"
done
echo ""

# Step 1: App Registration
echo "📌 Step 1/4: Creating App Registration..."
log_verbose "Executing: az ad app create --display-name \"$APP_NAME\""

# Check if App Registration with this name already exists
EXISTING_APP=$(az ad app list --display-name "$APP_NAME" --query "[0].appId" -o tsv 2>/dev/null)
if [ ! -z "$EXISTING_APP" ]; then
    echo "✅ App Registration already exists: $EXISTING_APP"
    APP_ID="$EXISTING_APP"
    log_verbose "Found existing App Registration, reusing it"
else
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
fi
log_verbose "App Registration Object ID: $(az ad app show --id $APP_ID --query id -o tsv 2>/dev/null || echo 'N/A')"
echo ""

# Wait for Azure AD to propagate
echo "⏳ Waiting for Azure AD propagation (15 seconds)..."
log_verbose "Azure AD needs time to replicate the new App Registration across all regions"
if [[ "$VERBOSE" == "true" ]]; then
    for i in {15..1}; do
        echo "🔍 [VERBOSE] Waiting... $i seconds remaining"
        sleep 1
    done
else
    sleep 15
fi
log_verbose "Azure AD propagation wait completed"
echo ""

# Step 2: Service Principal
echo "🔄 Step 2/4: Creating Service Principal..."
log_verbose "Checking for existing Service Principal first..."

# Check if Service Principal already exists using different approach
EXISTING_SP=$(az ad sp list --filter "appId eq '$APP_ID'" --query "[0].id" -o tsv 2>/dev/null)
if [ ! -z "$EXISTING_SP" ]; then
    echo "✅ Service Principal already exists: $EXISTING_SP"
    SP_ID="$EXISTING_SP"
    log_verbose "Found existing Service Principal, reusing it"
else
    log_verbose "Creating new Service Principal for App ID: $APP_ID"
    # Try multiple approaches due to Azure CLI bugs
    SP_CREATE_STATUS=1
    
    # Method 1: Try az ad sp create (may fail with JSON decode error)
    for attempt in {1..3}; do
        log_verbose "Attempt $attempt to create Service Principal using az ad sp create..."
        
        if [[ "$VERBOSE" == "true" ]]; then
            CREATE_OUTPUT=$(az ad sp create --id $APP_ID 2>&1)
            SP_CREATE_STATUS=$?
            echo "🔍 [VERBOSE] Create output: $CREATE_OUTPUT"
        else
            CREATE_OUTPUT=$(az ad sp create --id $APP_ID 2>/dev/null)
            SP_CREATE_STATUS=$?
        fi
        
        # Check for the specific JSON decoding error and treat it as transient
        if [[ "$CREATE_OUTPUT" == *"JSONDecodeError"* ]] || [[ "$CREATE_OUTPUT" == *"Expecting value: line 1 column 1"* ]]; then
            log_verbose "Detected Azure CLI JSON decoding error - will try REST API method"
            SP_CREATE_STATUS=1
            break  # Skip retries and go to REST API method
        fi
        
        if [ $SP_CREATE_STATUS -eq 0 ]; then
            # Get the SP ID after successful creation
            SP_ID=$(az ad sp list --filter "appId eq '$APP_ID'" --query "[0].id" -o tsv 2>/dev/null)
            if [ ! -z "$SP_ID" ]; then
                break
            fi
        fi
        
        if [ $attempt -lt 3 ]; then
            log_verbose "Service Principal creation failed, waiting 5 seconds before retry..."
            sleep 5
        fi
    done
    
    # Method 2: Try REST API if az ad sp create failed
    if [ $SP_CREATE_STATUS -ne 0 ] || [ -z "$SP_ID" ]; then
        log_verbose "Trying REST API method as fallback..."
        
        if [[ "$VERBOSE" == "true" ]]; then
            REST_OUTPUT=$(az rest --method POST --url "https://graph.microsoft.com/v1.0/servicePrincipals" \
                --body "{\"appId\":\"$APP_ID\",\"accountEnabled\":true}" \
                --headers "Content-Type=application/json" 2>&1)
            REST_STATUS=$?
            echo "🔍 [VERBOSE] REST API output: $REST_OUTPUT"
        else
            REST_OUTPUT=$(az rest --method POST --url "https://graph.microsoft.com/v1.0/servicePrincipals" \
                --body "{\"appId\":\"$APP_ID\",\"accountEnabled\":true}" \
                --headers "Content-Type=application/json" 2>/dev/null)
            REST_STATUS=$?
        fi
        
        if [ $REST_STATUS -eq 0 ]; then
            log_verbose "REST API Service Principal creation succeeded"
            # Wait a moment for propagation
            sleep 3
            SP_ID=$(az ad sp list --filter "appId eq '$APP_ID'" --query "[0].id" -o tsv 2>/dev/null)
            if [ ! -z "$SP_ID" ]; then
                SP_CREATE_STATUS=0
            fi
        fi
    fi

    # Final fallback: check if Service Principal was created despite any errors
    if [ $SP_CREATE_STATUS -ne 0 ] || [ -z "$SP_ID" ]; then
        log_verbose "Service Principal creation failed, checking if it was created anyway..."
        SP_ID=$(az ad sp list --filter "appId eq '$APP_ID'" --query "[0].id" -o tsv 2>/dev/null)
        if [ ! -z "$SP_ID" ]; then
            log_verbose "Service Principal found despite creation error - continuing"
            SP_CREATE_STATUS=0
        fi
    fi

    if [ $SP_CREATE_STATUS -ne 0 ] || [ -z "$SP_ID" ]; then
        echo "❌ FAILED - Could not create Service Principal after trying multiple methods"
        log_verbose "Error details: Azure AD propagation issue, Azure CLI bug, or permissions problem"
        log_verbose "Common solutions:"
        log_verbose "  1. Try running the script again after a few minutes"
        log_verbose "  2. Update Azure CLI: az upgrade"
        log_verbose "  3. Clear Azure CLI cache: az cache purge"
        log_verbose "  4. Create Service Principal manually: az ad sp create --id $APP_ID"
        log_verbose "  5. Check if you have permission to create Service Principals"
        exit 1
    fi
    echo "✅ Service Principal created: $SP_ID"
fi
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

# Step 3: Azure AD Directory Permissions
echo "🔑 Step 3/5: Assigning Azure AD Directory Permissions..."
log_verbose "Adding Microsoft Graph API permissions to app registration"

# Get Microsoft Graph App ID (not Service Principal ID)
log_verbose "Getting Microsoft Graph App ID..."
GRAPH_APP_ID="00000003-0000-0000-c000-000000000000"  # Well-known Microsoft Graph App ID

if [ ! -z "$GRAPH_APP_ID" ]; then
    log_verbose "Microsoft Graph App ID: $GRAPH_APP_ID"
    
    # Define required Microsoft Graph API permissions by name
    REQUIRED_PERMISSIONS=(
        "Application.ReadWrite.All"    # Application Administrator permission
        "Directory.ReadWrite.All"      # Directory Writers permission
        "AppRoleAssignment.ReadWrite.All"
    )
    
    echo "📝 Adding Microsoft Graph API permissions..."
    log_verbose "Looking up permission IDs for: ${REQUIRED_PERMISSIONS[*]}"
    
    # Get Microsoft Graph Service Principal to lookup permission IDs
    log_verbose "Retrieving Microsoft Graph Service Principal information..."
    GRAPH_SP_ID=$(az ad sp show --id $GRAPH_APP_ID --query "id" -o tsv 2>/dev/null)
    if [ -z "$GRAPH_SP_ID" ]; then
        echo "⚠️  WARNING - Could not retrieve Microsoft Graph Service Principal information"
        echo "   📝 Please add Microsoft Graph permissions manually in Azure Portal"
    else
        log_verbose "Microsoft Graph Service Principal ID: $GRAPH_SP_ID"
        
        # Process each required permission
        PERMISSION_IDS=()
        PERMISSION_NAMES=()
        
        for PERMISSION_NAME in "${REQUIRED_PERMISSIONS[@]}"; do
            log_verbose "Looking up permission ID for: $PERMISSION_NAME"
            
            # Find the permission ID by name in Microsoft Graph app roles
            PERMISSION_ID=$(az ad sp show --id $GRAPH_APP_ID --query "appRoles[?value=='$PERMISSION_NAME'].id | [0]" -o tsv 2>/dev/null)
            
            if [ ! -z "$PERMISSION_ID" ] && [ "$PERMISSION_ID" != "null" ]; then
                log_verbose "Found permission ID for $PERMISSION_NAME: $PERMISSION_ID"
                PERMISSION_IDS+=("$PERMISSION_ID")
                PERMISSION_NAMES+=("$PERMISSION_NAME")
                
                # Add the permission to app registration
                log_verbose "Adding $PERMISSION_NAME permission..."
                if [[ "$VERBOSE" == "true" ]]; then
                    echo "🔍 [VERBOSE] Executing: az ad app permission add --id $APP_ID --api $GRAPH_APP_ID --api-permissions $PERMISSION_ID=Role"
                    PERM_OUTPUT=$(az ad app permission add --id $APP_ID --api $GRAPH_APP_ID --api-permissions $PERMISSION_ID=Role 2>&1)
                    PERM_STATUS=$?
                    echo "🔍 [VERBOSE] $PERMISSION_NAME permission output: $PERM_OUTPUT"
                else
                    PERM_OUTPUT=$(az ad app permission add --id $APP_ID --api $GRAPH_APP_ID --api-permissions $PERMISSION_ID=Role 2>&1)
                    PERM_STATUS=$?
                fi
                
                if [ $PERM_STATUS -eq 0 ]; then
                    echo "✅ $PERMISSION_NAME permission added"
                    log_verbose "Service Principal now has $PERMISSION_NAME permission"
                elif [[ "$PERM_OUTPUT" == *"already exists"* ]] || [[ "$PERM_OUTPUT" == *"Conflict"* ]]; then
                    echo "✅ $PERMISSION_NAME permission already exists"
                    log_verbose "$PERMISSION_NAME permission already configured"
                else
                    echo "⚠️  WARNING - Could not add $PERMISSION_NAME permission"
                    log_verbose "Error adding $PERMISSION_NAME: $PERM_OUTPUT"
                fi
            else
                echo "⚠️  WARNING - Could not find permission ID for: $PERMISSION_NAME"
                log_verbose "Permission $PERMISSION_NAME not found in Microsoft Graph app roles"
            fi
        done
        
        # Grant admin consent for the permissions using REST API
        echo "🔐 Granting admin consent for permissions..."
        log_verbose "Granting admin consent for Microsoft Graph app permissions via REST API..."
        
        if [ ! -z "$GRAPH_SP_ID" ] && [ ${#PERMISSION_IDS[@]} -gt 0 ]; then
            log_verbose "Microsoft Graph Service Principal ID: $GRAPH_SP_ID"
            
            CONSENT_SUCCESS_COUNT=0
            TOTAL_PERMISSIONS=${#PERMISSION_IDS[@]}
            
            # Grant admin consent for each permission
            for i in "${!PERMISSION_IDS[@]}"; do
                PERMISSION_ID="${PERMISSION_IDS[i]}"
                PERMISSION_NAME="${PERMISSION_NAMES[i]}"
                
                log_verbose "Granting admin consent for $PERMISSION_NAME app permission..."
                if [[ "$VERBOSE" == "true" ]]; then
                    echo "🔍 [VERBOSE] Creating app role assignment for $PERMISSION_NAME..."
                    CONSENT_OUTPUT=$(az rest --method POST \
                        --url "https://graph.microsoft.com/v1.0/servicePrincipals/$SP_ID/appRoleAssignments" \
                        --body "{\"principalId\":\"$SP_ID\",\"resourceId\":\"$GRAPH_SP_ID\",\"appRoleId\":\"$PERMISSION_ID\"}" \
                        --headers "Content-Type=application/json" 2>&1)
                    CONSENT_STATUS=$?
                    echo "🔍 [VERBOSE] $PERMISSION_NAME consent output: $CONSENT_OUTPUT"
                else
                    CONSENT_OUTPUT=$(az rest --method POST \
                        --url "https://graph.microsoft.com/v1.0/servicePrincipals/$SP_ID/appRoleAssignments" \
                        --body "{\"principalId\":\"$SP_ID\",\"resourceId\":\"$GRAPH_SP_ID\",\"appRoleId\":\"$PERMISSION_ID\"}" \
                        --headers "Content-Type=application/json" 2>/dev/null)
                    CONSENT_STATUS=$?
                fi
                
                if [ $CONSENT_STATUS -eq 0 ]; then
                    echo "✅ Admin consent granted for $PERMISSION_NAME"
                    log_verbose "$PERMISSION_NAME app permission is now consented"
                    ((CONSENT_SUCCESS_COUNT++))
                elif [[ "$CONSENT_OUTPUT" == *"already exists"* ]] || [[ "$CONSENT_OUTPUT" == *"Conflict"* ]]; then
                    echo "✅ $PERMISSION_NAME already consented"
                    log_verbose "$PERMISSION_NAME permission was already consented"
                    ((CONSENT_SUCCESS_COUNT++))
                else
                    echo "⚠️  WARNING - Could not grant consent for $PERMISSION_NAME"
                    log_verbose "$PERMISSION_NAME consent failed: $CONSENT_OUTPUT"
                fi
            done
            
            # Final status check
            if [ $CONSENT_SUCCESS_COUNT -eq $TOTAL_PERMISSIONS ]; then
                echo "✅ Admin consent granted for all Microsoft Graph app permissions ($CONSENT_SUCCESS_COUNT/$TOTAL_PERMISSIONS)"
                log_verbose "All app permissions are now active and usable"
            elif [ $CONSENT_SUCCESS_COUNT -gt 0 ]; then
                echo "⚠️  Partial admin consent granted ($CONSENT_SUCCESS_COUNT/$TOTAL_PERMISSIONS permissions)"
                echo "   📝 Please grant remaining admin consent manually in Azure Portal:"
                echo "   📝 Azure AD > App registrations > $APP_NAME > API permissions > Grant admin consent"
            else
                echo "⚠️  WARNING - Could not grant consent for any app permissions"
                echo "   📝 Please grant admin consent manually in Azure Portal:"
                echo "   📝 Azure AD > App registrations > $APP_NAME > API permissions > Grant admin consent"
            fi
        else
            echo "⚠️  WARNING - No permissions to consent or missing Microsoft Graph Service Principal"
            echo "   📝 Please add Microsoft Graph permissions manually in Azure Portal:"
            echo "   📝 Azure AD > App registrations > $APP_NAME > API permissions"
            echo "   📝 Add required app permissions and grant admin consent"
        fi
    fi
fi

log_verbose "Azure AD directory permissions assignment completed"
echo ""

# Step 4: Federated Credential
echo "🔐 Step 4/5: Creating Federated Credential..."
SUBJECT="repo:$GITHUB_ORG/$GITHUB_REPO:ref:refs/heads/$GITHUB_REF"
CREDENTIAL_NAME="github-$GITHUB_REPO-$GITHUB_REF"

log_verbose "Federated Credential details:"
log_verbose "  Name: $CREDENTIAL_NAME"
log_verbose "  Issuer: https://token.actions.githubusercontent.com"
log_verbose "  Subject: $SUBJECT"
log_verbose "  Audience: api://AzureADTokenExchange"

# Check if federated credential already exists
log_verbose "Checking for existing federated credential..."
EXISTING_CRED=$(az ad app federated-credential list --id $APP_ID --query "[?name=='$CREDENTIAL_NAME'].name" -o tsv 2>/dev/null)

# Also check for existing credential with same subject (GitHub repo/branch combination)
EXISTING_SUBJECT=$(az ad app federated-credential list --id $APP_ID --query "[?subject=='$SUBJECT'].name" -o tsv 2>/dev/null)

if [ ! -z "$EXISTING_CRED" ] || [ ! -z "$EXISTING_SUBJECT" ]; then
    if [ ! -z "$EXISTING_CRED" ]; then
        echo "✅ Federated Credential already exists: $CREDENTIAL_NAME"
        log_verbose "Found existing federated credential with same name, reusing it"
    elif [ ! -z "$EXISTING_SUBJECT" ]; then
        echo "✅ Federated Credential already exists for this GitHub repo/branch: $EXISTING_SUBJECT"
        log_verbose "Found existing federated credential with same subject, reusing it"
    fi
else
    log_verbose "Creating new federated credential..."
    if [[ "$VERBOSE" == "true" ]]; then
        CREATE_OUTPUT=$(az ad app federated-credential create --id $APP_ID --parameters "{\"name\":\"$CREDENTIAL_NAME\",\"issuer\":\"https://token.actions.githubusercontent.com\",\"subject\":\"$SUBJECT\",\"audiences\":[\"api://AzureADTokenExchange\"]}" 2>&1)
        CRED_CREATE_STATUS=$?
        echo "🔍 [VERBOSE] Create output: $CREATE_OUTPUT"
    else
        CREATE_OUTPUT=$(az ad app federated-credential create --id $APP_ID --parameters "{\"name\":\"$CREDENTIAL_NAME\",\"issuer\":\"https://token.actions.githubusercontent.com\",\"subject\":\"$SUBJECT\",\"audiences\":[\"api://AzureADTokenExchange\"]}" 2>&1)
        CRED_CREATE_STATUS=$?
    fi

    # Check for specific error about existing credential
    if [[ "$CREATE_OUTPUT" == *"already exists"* ]] || [[ "$CREATE_OUTPUT" == *"DuplicateKeyValue"* ]] || [[ "$CREATE_OUTPUT" == *"Conflict"* ]]; then
        echo "✅ Federated Credential already exists (detected during creation)"
        log_verbose "Credential was created by another process or already existed - continuing"
        CRED_CREATE_STATUS=0
    elif [ $CRED_CREATE_STATUS -ne 0 ]; then
        echo "❌ FAILED - Could not create Federated Credential"
        log_verbose "Error details: Check if credential name conflicts or GitHub details are correct"
        log_verbose "Error output: $CREATE_OUTPUT"
        # Try to show existing credentials for debugging
        if [[ "$VERBOSE" == "true" ]]; then
            echo "🔍 [VERBOSE] Existing federated credentials:"
            az ad app federated-credential list --id $APP_ID --query "[].{name:name, subject:subject}" -o table 2>/dev/null || echo "Could not list existing credentials"
        fi
        exit 1
    else
        echo "✅ Federated Credential created"
    fi
fi
log_verbose "GitHub Actions can now authenticate without secrets using OIDC"
echo ""

# Step 5: RBAC Assignment
echo "🔓 Step 5/5: Assigning RBAC permissions..."

# Get current subscription and tenant
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)

# Determine scope
if [[ "$MANAGEMENT_GROUP_MODE" == "true" ]]; then
    if [[ ! -z "$MANAGEMENT_GROUP_NAME" ]]; then
        # Use specified management group name
        DEFAULT_MG_NAME="$MANAGEMENT_GROUP_NAME"
        log_verbose "Management Group mode: Using specified '$DEFAULT_MG_NAME' management group"
        
        # Check if specified management group exists
        SPECIFIED_MG_ID=$(az account management-group list --query "[?displayName=='$DEFAULT_MG_NAME'].name | [0]" -o tsv 2>/dev/null)
        
        if [ -z "$SPECIFIED_MG_ID" ] || [ "$SPECIFIED_MG_ID" == "null" ]; then
            echo "📁 Creating '$DEFAULT_MG_NAME' management group..."
            log_verbose "Management group '$DEFAULT_MG_NAME' not found, creating it"
            
            # Create the management group
            if [[ "$VERBOSE" == "true" ]]; then
                CREATE_MG_OUTPUT=$(az account management-group create --name "$DEFAULT_MG_NAME" --display-name "$DEFAULT_MG_NAME" 2>&1)
                CREATE_MG_STATUS=$?
                echo "🔍 [VERBOSE] Create management group output: $CREATE_MG_OUTPUT"
            else
                CREATE_MG_OUTPUT=$(az account management-group create --name "$DEFAULT_MG_NAME" --display-name "$DEFAULT_MG_NAME" 2>/dev/null)
                CREATE_MG_STATUS=$?
            fi
            
            # Check if creation succeeded or if it already existed
            if [ $CREATE_MG_STATUS -eq 0 ]; then
                echo "✅ Management group '$DEFAULT_MG_NAME' created successfully"
                TARGET_MG_ID="$DEFAULT_MG_NAME"
            elif [[ "$CREATE_MG_OUTPUT" == *"already exists"* ]] || [[ "$CREATE_MG_OUTPUT" == *"AlreadyExists"* ]]; then
                echo "✅ Management group '$DEFAULT_MG_NAME' already exists"
                TARGET_MG_ID="$DEFAULT_MG_NAME"
                log_verbose "Management group already existed, continuing"
            else
                echo "❌ FAILED - Could not create management group '$DEFAULT_MG_NAME'"
                log_verbose "Management group creation failed: $CREATE_MG_OUTPUT"
                exit 1
            fi
        else
            echo "✅ Using existing '$DEFAULT_MG_NAME' management group"
            log_verbose "Found existing management group '$DEFAULT_MG_NAME' with ID: $SPECIFIED_MG_ID"
            TARGET_MG_ID="$SPECIFIED_MG_ID"
        fi
        
        SCOPE="/providers/Microsoft.Management/managementGroups/$TARGET_MG_ID"
        SCOPE_NAME="Management Group ($DEFAULT_MG_NAME)"
    else
        # Use root management group (no name specified)
        log_verbose "Management Group mode: Using root management group"
        
        # Get the root management group (tenant root group)
        ROOT_MG_ID=$(az account management-group list --query "[?displayName=='Tenant Root Group' || name=='$TENANT_ID'].name | [0]" -o tsv 2>/dev/null)
        if [ -z "$ROOT_MG_ID" ] || [ "$ROOT_MG_ID" == "null" ]; then
            # Fallback: get the first management group the user has access to
            ROOT_MG_ID=$(az account management-group list --query "[0].name" -o tsv 2>/dev/null)
            if [ -z "$ROOT_MG_ID" ] || [ "$ROOT_MG_ID" == "null" ]; then
                echo "❌ FAILED - No management groups found or insufficient permissions"
                echo "   Falling back to subscription scope..."
                SCOPE="/subscriptions/$SUBSCRIPTION_ID"
                SCOPE_NAME="Subscription (fallback)"
                MANAGEMENT_GROUP_MODE="false"
            else
                echo "✅ Using management group: $ROOT_MG_ID"
                SCOPE="/providers/Microsoft.Management/managementGroups/$ROOT_MG_ID"
                SCOPE_NAME="Management Group ($ROOT_MG_ID)"
            fi
        else
            echo "✅ Using root management group: $ROOT_MG_ID"
            SCOPE="/providers/Microsoft.Management/managementGroups/$ROOT_MG_ID"
            SCOPE_NAME="Root Management Group ($ROOT_MG_ID)"
        fi
    fi
else
    SCOPE="/subscriptions/$SUBSCRIPTION_ID"
    SCOPE_NAME="Subscription"
fi

log_verbose "RBAC Assignment details:"
log_verbose "  Role: Owner (8e3af657-a8ff-443c-a75c-2fe8c4bcb635)"
log_verbose "  Assignee: $SP_ID"
log_verbose "  Scope: $SCOPE ($SCOPE_NAME)"
log_verbose "  Condition: Blocks Owner and RBAC Admin assignments from this service principal"

# Create role assignment
OWNER_ROLE="8e3af657-a8ff-443c-a75c-2fe8c4bcb635"  # Owner

# RBAC assignment with security conditions for Owner role
CONDITION='((!(ActionMatches{'\''Microsoft.Authorization/roleAssignments/write'\''})) OR (@Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAllValues:GuidNotEquals {8e3af657-a8ff-443c-a75c-2fe8c4bcb635, f58310d9-a9f6-439a-9e8d-f62e7b41a168})) AND ((!(ActionMatches{'\''Microsoft.Authorization/roleAssignments/delete'\''})) OR (@Resource[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAllValues:GuidNotEquals {8e3af657-a8ff-443c-a75c-2fe8c4bcb635, f58310d9-a9f6-439a-9e8d-f62e7b41a168}))'

# Assignment: Owner with conditions
log_verbose "Creating Owner role assignment with security conditions..."
if [[ "$VERBOSE" == "true" ]]; then
    echo "🔍 [VERBOSE] Executing Owner role assignment with conditions on $SCOPE_NAME..."
    az role assignment create \
      --assignee $SP_ID \
      --role $OWNER_ROLE \
      --scope "$SCOPE" \
      --description "GitHub Actions service principal - cannot assign/delete Owner and RBAC Admin roles" \
      --condition "$CONDITION" \
      --condition-version "2.0"
    RBAC_CREATE_STATUS=$?
else
    az role assignment create \
      --assignee $SP_ID \
      --role $OWNER_ROLE \
      --scope "$SCOPE" \
      --description "GitHub Actions service principal - cannot assign/delete Owner and RBAC Admin roles" \
      --condition "$CONDITION" \
      --condition-version "2.0" >/dev/null 2>&1
    RBAC_CREATE_STATUS=$?
fi

if [ $RBAC_CREATE_STATUS -ne 0 ]; then
    echo "❌ FAILED - Could not create Owner RBAC assignment on $SCOPE_NAME"
    log_verbose "Error details: You may need Owner permissions to assign roles with conditions"
    if [[ "$MANAGEMENT_GROUP_MODE" == "true" ]]; then
        log_verbose "Alternative: Try without management-group mode or assign Owner role manually in Azure Portal"
    else
        log_verbose "Alternative: Assign Owner role manually in Azure Portal"
    fi
    exit 1
fi
echo "✅ Owner role assigned with security restrictions on $SCOPE_NAME"
log_verbose "Service Principal has full $SCOPE_NAME access except cannot assign/delete Owner and RBAC Admin roles"
echo ""






echo "🎉 SETUP COMPLETED SUCCESSFULLY!"
echo "================================="
echo ""
echo "🎯 GitHub Secrets to add:"
echo "   AZURE_CLIENT_ID=$APP_ID"
echo "   AZURE_TENANT_ID=$TENANT_ID"
echo "   AZURE_SUBSCRIPTION_ID=$SUBSCRIPTION_ID"
echo ""
echo "📝 Next steps:"
echo "   1. Add the secrets above to your GitHub repository"
echo "   2. Use 'azure/login@v1' action with OIDC in your workflows"
echo "   3. Reference: https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-azure"
echo ""

if [[ "$VERBOSE" == "true" ]]; then
    echo "🔧 Troubleshooting info:"
    echo "   - App Registration ID: $APP_ID"
    echo "   - Service Principal ID: $SP_ID" 
    echo "   - Federated Credential Subject: repo:$GITHUB_ORG/$GITHUB_REPO:ref:refs/heads/$GITHUB_REF"
    echo "   - RBAC Roles: Owner (with security restrictions) + Azure AD roles"
    echo "   - Azure AD Permissions: Microsoft Graph API permissions"
    echo "   - RBAC Scope: $SCOPE_NAME"
    echo "   - Owner GUID: 8e3af657-a8ff-443c-a75c-2fe8c4bcb635"
    echo "   - Security Condition: Blocks Owner/RBAC Admin role assignments"
    echo ""
    echo "🆘 If you encounter issues:"
    echo "   1. Azure CLI JSON errors: Try 'az cache purge' and 'az upgrade'"
    echo "   2. Service Principal creation fails: Wait 5 minutes and retry"
    echo "   3. RBAC assignment fails: Check if you have Owner permissions"
    echo "   4. Run with 'verbose' mode for detailed debugging"
    echo ""
fi

echo "🔒 Security: Service Principal CANNOT assign these roles:"
echo "   ❌ Owner (8e3af657-a8ff-443c-a75c-2fe8c4bcb635)"
echo "   ❌ RBAC Administrator (f58310d9-a9f6-439a-9e8d-f62e7b41a168)"
echo ""
echo "✅ Service Principal HAS these RBAC roles:"
echo "   ✅ Owner (with security restrictions - cannot assign/delete Owner and RBAC Admin roles)"
echo ""
echo "✅ Service Principal HAS these Azure AD permissions:"
for PERMISSION_NAME in "${REQUIRED_PERMISSIONS[@]}"; do
    case "$PERMISSION_NAME" in
        "Application.ReadWrite.All")
            echo "   ✅ $PERMISSION_NAME (Microsoft Graph API permission for app management)"
            ;;
        "Directory.ReadWrite.All")
            echo "   ✅ $PERMISSION_NAME (Microsoft Graph API permission for directory operations)"
            ;;
        "AppRoleAssignment.ReadWrite.All")
            echo "   ✅ $PERMISSION_NAME (Microsoft Graph API permission for role assignments)"
            ;;
        *)
            echo "   ✅ $PERMISSION_NAME (Microsoft Graph API permission)"
            ;;
    esac
done
echo ""

if [[ "$VERBOSE" == "true" ]]; then
    echo "🔍 [VERBOSE] Summary of created resources:"
    echo "🔍 [VERBOSE]   App Registration: $APP_NAME (ID: $APP_ID)"
    echo "🔍 [VERBOSE]   Service Principal: $SP_ID"
    echo "🔍 [VERBOSE]   Federated Credential: $CREDENTIAL_NAME"
    echo "🔍 [VERBOSE]   RBAC Role: Owner (with security conditions)"
    echo "🔍 [VERBOSE]   Azure AD Permissions: Microsoft Graph API permissions"
    echo "🔍 [VERBOSE]   RBAC Scope: $SCOPE_NAME"
    echo "🔍 [VERBOSE]   Subscription: $SUBSCRIPTION_ID"
    echo "🔍 [VERBOSE]   Tenant: $TENANT_ID"
    echo ""
fi

echo "✅ Ready for GitHub Actions!"

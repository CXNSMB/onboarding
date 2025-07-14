#!/bin/bash

# Test script dat simuleert wat er gebeurt als er geen subscription ID wordt meegegeven
echo "🧪 Test Multiple Subscription Detection"
echo "======================================"

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

# Parameters (nieuwe volgorde)
SUBSCRIPTION_ID="${1}"
APP_NAME="${2:-CXNSMB-github-solution-onboarding}"
GITHUB_ORG="${3:-CXNSMB}"
GITHUB_REPO="${4:-solution-onboarding}"
GITHUB_REF="${5:-main}"

echo ""
echo "📋 Test Parameters Received:"
echo "   SUBSCRIPTION_ID: ${SUBSCRIPTION_ID:-'(not provided)'}"
echo "   APP_NAME: $APP_NAME"
echo "   GITHUB_ORG: $GITHUB_ORG"
echo "   GITHUB_REPO: $GITHUB_REPO"
echo "   GITHUB_REF: $GITHUB_REF"
echo ""

# Check subscription logic
if [[ ! -z "$SUBSCRIPTION_ID" ]]; then
    echo "✅ Subscription ID provided: $SUBSCRIPTION_ID"
    echo "   Script would proceed with this specific subscription"
else
    # No subscription ID provided, check available subscriptions
    echo "📝 No subscription ID provided, checking available subscriptions..."
    
    # Get list of subscriptions (limiteer tot eerste 5 voor test)
    mapfile -t SUBSCRIPTIONS < <(az account list --query "[0:5].{name:name, id:id, isDefault:isDefault}" -o tsv)
    
    if [ ${#SUBSCRIPTIONS[@]} -eq 0 ]; then
        echo "❌ FAILED - No subscriptions found"
        echo "Please check your Azure access permissions"
        exit 1
    elif [ ${#SUBSCRIPTIONS[@]} -eq 1 ]; then
        # Only one subscription, use it automatically
        IFS=$'\t' read -r name id isDefault <<< "${SUBSCRIPTIONS[0]}"
        echo "📝 Only one subscription found, would automatically use: $name"
        echo "   ID: $id"
        if [[ "$isDefault" != "true" ]]; then
            echo "   Would switch to this subscription"
        else
            echo "   Already active subscription"
        fi
    else
        # Multiple subscriptions found, show options with curl syntax
        echo ""
        echo "📋 Multiple Azure Subscriptions Found"
        echo "======================================"
        echo ""
        echo "Please run the script again with a specific subscription ID:"
        echo ""
        
        # Get the script URL
        SCRIPT_URL="https://raw.githubusercontent.com/CXNSMB/onboarding/main/setup-app-registration.sh"
        
        # Generate curl command for each subscription (eerste 5 voor test)
        for i in "${!SUBSCRIPTIONS[@]}"; do
            IFS=$'\t' read -r name id isDefault <<< "${SUBSCRIPTIONS[i]}"
            echo "🔹 $name"
            if [[ "$isDefault" == "true" ]]; then
                echo "   [CURRENT]"
            fi
            
            # Build curl command with new parameter order: subscription-id first
            CURL_CMD="curl -s $SCRIPT_URL | bash -s -- \"$id\" \"$APP_NAME\" \"$GITHUB_ORG\" \"$GITHUB_REPO\" \"$GITHUB_REF\""
            
            echo "   $CURL_CMD"
            echo ""
        done
        
        echo "💡 Tip: Copy and paste one of the commands above to run with your desired subscription."
        echo ""
        echo "🎯 Example with custom parameters:"
        IFS=$'\t' read -r name id isDefault <<< "${SUBSCRIPTIONS[0]}"
        echo "   curl -s $SCRIPT_URL | bash -s -- \"$id\" \"my-custom-app\" \"my-org\" \"my-repo\" \"dev\" \"verbose\""
        echo ""
        
        return 0
    fi
fi

echo ""
echo "✅ Subscription test completed!"

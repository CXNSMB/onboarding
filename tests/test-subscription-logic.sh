#!/bin/bash

# Test script for the new subscription selection logic
echo "🧪 Testing New Subscription Selection Logic"
echo "=========================================="

# Verbose logging function
log_verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo "🔍 [VERBOSE] $1"
    fi
}

# Check for verbose mode and management group mode
VERBOSE=""
MANAGEMENT_GROUP_MODE=""
MANAGEMENT_GROUP_NAME=""

# Process parameters 6 and 7 for options
for param in "$6" "$7"; do
    if [[ "$param" == "verbose" || "$param" == "-v" || "$param" == "--verbose" ]]; then
        VERBOSE="true"
    elif [[ "$param" == "management-group" || "$param" == "mg" || "$param" == "--management-group" ]]; then
        MANAGEMENT_GROUP_MODE="true"
    elif [[ "$MANAGEMENT_GROUP_MODE" == "true" && ! -z "$param" && "$param" != "verbose" && "$param" != "-v" && "$param" != "--verbose" ]]; then
        # This is a management group name
        MANAGEMENT_GROUP_NAME="$param"
    fi
done

echo "🔍 Simulating Azure CLI connectivity check..."
echo "✅ Connected to Azure CLI"

# Parameters
APP_NAME="${1:-test-app}"
GITHUB_ORG="${2:-test-org}"
GITHUB_REPO="${3:-test-repo}"
GITHUB_REF="${4:-main}"
SUBSCRIPTION_ID="${5}"

echo ""
echo "📋 Test Configuration:"
echo "   App Name: $APP_NAME"
echo "   GitHub: $GITHUB_ORG/$GITHUB_REPO (branch: $GITHUB_REF)"
echo "   Subscription ID: ${SUBSCRIPTION_ID:-'(not provided)'}"
if [[ "$VERBOSE" == "true" ]]; then
    echo "   Verbose Mode: ENABLED"
fi
if [[ "$MANAGEMENT_GROUP_MODE" == "true" ]]; then
    if [[ ! -z "$MANAGEMENT_GROUP_NAME" ]]; then
        echo "   Scope: Management Group ($MANAGEMENT_GROUP_NAME)"
    else
        echo "   Scope: Management Group (root level)"
    fi
fi
echo ""

# Simulate Azure subscriptions response based on test mode
if [[ "$1" == "single" ]]; then
    # Simulate single subscription
    echo "📝 Simulating single subscription scenario..."
    MOCK_SUBSCRIPTIONS=(
        $'Single Test Subscription\t12345678-1234-1234-1234-123456789012\ttrue'
    )
elif [[ "$1" == "multiple" ]]; then
    # Simulate multiple subscriptions
    echo "📝 Simulating multiple subscriptions scenario..."
    MOCK_SUBSCRIPTIONS=(
        $'Production Subscription\t11111111-1111-1111-1111-111111111111\ttrue'
        $'Development Subscription\t22222222-2222-2222-2222-222222222222\tfalse'
        $'Test Subscription\t33333333-3333-3333-3333-333333333333\tfalse'
        $'Staging Subscription\t44444444-4444-4444-4444-444444444444\tfalse'
    )
    # Reset parameters for multiple test
    APP_NAME="${2:-test-app}"
    GITHUB_ORG="${3:-test-org}"
    GITHUB_REPO="${4:-test-repo}"
    GITHUB_REF="${5:-main}"
    SUBSCRIPTION_ID="${6}"
    # Re-process verbose/mg options for multiple test
    VERBOSE=""
    MANAGEMENT_GROUP_MODE=""
    MANAGEMENT_GROUP_NAME=""
    for param in "$7" "$8"; do
        if [[ "$param" == "verbose" || "$param" == "-v" || "$param" == "--verbose" ]]; then
            VERBOSE="true"
        elif [[ "$param" == "management-group" || "$param" == "mg" || "$param" == "--management-group" ]]; then
            MANAGEMENT_GROUP_MODE="true"
        elif [[ "$MANAGEMENT_GROUP_MODE" == "true" && ! -z "$param" && "$param" != "verbose" && "$param" != "-v" && "$param" != "--verbose" ]]; then
            MANAGEMENT_GROUP_NAME="$param"
        fi
    done
else
    echo "❌ Usage: $0 [single|multiple] [other parameters...]"
    echo "   single   - Test single subscription scenario"
    echo "   multiple - Test multiple subscriptions scenario"
    echo ""
    echo "Examples:"
    echo "   $0 single"
    echo "   $0 multiple"
    echo "   $0 multiple test-app test-org test-repo main 22222222-2222-2222-2222-222222222222"
    echo "   $0 multiple test-app test-org test-repo main \"\" verbose"
    exit 1
fi

# Check subscription logic
if [[ ! -z "$SUBSCRIPTION_ID" ]]; then
    # Subscription ID provided, validate and use it
    echo "🔄 Setting subscription to: $SUBSCRIPTION_ID"
    log_verbose "Switching to subscription: $SUBSCRIPTION_ID"
    
    # Find subscription in mock data
    FOUND_SUBSCRIPTION=""
    for subscription in "${MOCK_SUBSCRIPTIONS[@]}"; do
        IFS=$'\t' read -r name id isDefault <<< "$subscription"
        if [[ "$id" == "$SUBSCRIPTION_ID" ]]; then
            FOUND_SUBSCRIPTION="$name"
            break
        fi
    done
    
    if [ -z "$FOUND_SUBSCRIPTION" ]; then
        echo "❌ FAILED - Cannot access subscription: $SUBSCRIPTION_ID"
        echo "Please check if:"
        echo "   1. The subscription ID is correct"
        echo "   2. You have access to this subscription"
        echo "   3. The subscription is active"
        exit 1
    fi
    
    echo "✅ Successfully switched to subscription: $FOUND_SUBSCRIPTION"
    log_verbose "Active subscription is now: $FOUND_SUBSCRIPTION (ID: $SUBSCRIPTION_ID)"
else
    # No subscription ID provided, check available subscriptions
    log_verbose "No subscription ID provided, checking available subscriptions..."
    
    if [ ${#MOCK_SUBSCRIPTIONS[@]} -eq 0 ]; then
        echo "❌ FAILED - No subscriptions found"
        echo "Please check your Azure access permissions"
        exit 1
    elif [ ${#MOCK_SUBSCRIPTIONS[@]} -eq 1 ]; then
        # Only one subscription, use it automatically
        IFS=$'\t' read -r name id isDefault <<< "${MOCK_SUBSCRIPTIONS[0]}"
        echo "📝 Only one subscription found, using: $name"
        log_verbose "Automatically using single subscription: $name (ID: $id)"
        
        if [[ "$isDefault" != "true" ]]; then
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
        
        # Get the script URL
        SCRIPT_URL="https://raw.githubusercontent.com/CXNSMB/onboarding/main/setup-app-registration.sh"
        
        # Generate curl command for each subscription
        for i in "${!MOCK_SUBSCRIPTIONS[@]}"; do
            IFS=$'\t' read -r name id isDefault <<< "${MOCK_SUBSCRIPTIONS[i]}"
            echo "🔹 $name"
            if [[ "$isDefault" == "true" ]]; then
                echo "   [CURRENT]"
            fi
            
            # Build curl command with subscription ID as first parameter
            CURL_CMD="curl -s $SCRIPT_URL | bash -s -- \"$id\" \"$APP_NAME\" \"$GITHUB_ORG\" \"$GITHUB_REPO\" \"$GITHUB_REF\""
            
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
echo "✅ Subscription test completed! Continuing with app registration setup..."
echo "(In real script, the rest of the setup would continue here)"

#!/bin/bash

# Test alleen de subscription gedeelte van het script
echo "🧪 Test subscription switching functionaliteit"
echo "=============================================="

# Verbose logging function
log_verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo "🔍 [VERBOSE] $1"
    fi
}

# Test parameters
APP_NAME="${1:-test-app}"
GITHUB_ORG="${2:-test-org}"
GITHUB_REPO="${3:-test-repo}"
GITHUB_REF="${4:-main}"
SUBSCRIPTION_ID="${5}"
VERBOSE="${6}"

if [[ "$VERBOSE" == "verbose" ]]; then
    VERBOSE="true"
fi

echo "📋 Test Configuration:"
echo "   App Name: $APP_NAME"
echo "   GitHub: $GITHUB_ORG/$GITHUB_REPO (branch: $GITHUB_REF)"
echo "   Subscription ID: ${SUBSCRIPTION_ID:-'(not provided)'}"
echo "   Verbose: ${VERBOSE:-'false'}"
echo ""

# Quick Azure CLI connectivity check
echo "🔍 Checking Azure CLI connectivity..."
if ! az account show >/dev/null 2>&1; then
    echo "❌ FAILED - Not logged into Azure CLI"
    echo "Please run: az login"
    exit 1
fi

# Show current subscription before any changes
CURRENT_BEFORE=$(az account show --query name -o tsv 2>/dev/null)
CURRENT_ID_BEFORE=$(az account show --query id -o tsv 2>/dev/null)
echo "📍 Current subscription before: $CURRENT_BEFORE (ID: $CURRENT_ID_BEFORE)"

# Validate and set subscription if provided
if [[ ! -z "$SUBSCRIPTION_ID" ]]; then
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
    # No subscription ID provided, use current subscription
    CURRENT_SUB=$(az account show --query name -o tsv 2>/dev/null)
    CURRENT_SUB_ID=$(az account show --query id -o tsv 2>/dev/null)
    echo "📝 Using current subscription: $CURRENT_SUB"
    log_verbose "Current subscription ID: $CURRENT_SUB_ID"
fi

# Show final subscription
CURRENT_AFTER=$(az account show --query name -o tsv 2>/dev/null)
CURRENT_ID_AFTER=$(az account show --query id -o tsv 2>/dev/null)
echo "📍 Current subscription after: $CURRENT_AFTER (ID: $CURRENT_ID_AFTER)"

echo ""
echo "✅ Subscription test completed!"

# Reset to original subscription if we changed it
if [[ ! -z "$SUBSCRIPTION_ID" && "$CURRENT_ID_AFTER" != "$CURRENT_ID_BEFORE" ]]; then
    echo "🔄 Resetting to original subscription..."
    az account set --subscription "$CURRENT_ID_BEFORE" >/dev/null 2>&1
    echo "✅ Reset to: $CURRENT_BEFORE"
fi

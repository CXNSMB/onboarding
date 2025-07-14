#!/bin/bash

# Minimale versie van subscription selectie voor testing
echo "🚀 Azure Subscription Selection Test"
echo "===================================="

# Verbose logging function
log_verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo "🔍 [VERBOSE] $1"
    fi
}

# Check for verbose mode
VERBOSE=""
if [[ "$1" == "verbose" || "$1" == "-v" || "$1" == "--verbose" ]]; then
    VERBOSE="true"
fi

echo "🔍 Checking Azure CLI connectivity..."
if ! az account show >/dev/null 2>&1; then
    echo "❌ FAILED - Not logged into Azure CLI"
    echo "Please run: az login"
    
    # Voor testing, gebruik mock data
    echo "📝 Voor testing, gebruiken we mock subscription data..."
    
    # Mock subscription data
    SUBSCRIPTIONS=(
        $'Test Subscription 1\t12345678-1234-1234-1234-123456789012\ttrue'
        $'Test Subscription 2\t87654321-4321-4321-4321-210987654321\tfalse'
        $'Development Subscription\t11111111-2222-3333-4444-555555555555\tfalse'
    )
else
    # Echte Azure data
    echo "✅ Connected to Azure CLI"
    mapfile -t SUBSCRIPTIONS < <(az account list --query "[].{name:name, id:subscriptionId, isDefault:isDefault}" -o tsv)
fi

# Show available subscriptions and allow selection
echo ""
echo "📋 Available Azure Subscriptions:"
echo "=================================="

if [ ${#SUBSCRIPTIONS[@]} -eq 0 ]; then
    echo "❌ FAILED - No subscriptions found"
    echo "Please check your Azure access permissions"
    exit 1
fi

# Display subscriptions with numbers
for i in "${!SUBSCRIPTIONS[@]}"; do
    IFS=$'\t' read -r name id isDefault <<< "${SUBSCRIPTIONS[i]}"
    if [[ "$isDefault" == "true" ]]; then
        echo "$((i+1)). $name (ID: $id) [CURRENT]"
        CURRENT_INDEX=$((i+1))
    else
        echo "$((i+1)). $name (ID: $id)"
    fi
done

echo ""
echo "🎯 Current subscription is marked with [CURRENT]"
echo "📝 Enter the number of the subscription to use (or press Enter for current):"

# Debug info
log_verbose "Checking input method..."
log_verbose "[ -t 0 ] = $([ -t 0 ] && echo "true" || echo "false")"
log_verbose "[ -e /dev/tty ] = $([ -e /dev/tty ] && echo "true" || echo "false")"

# Check if running in interactive mode (stdin is a terminal)
if [ -t 0 ]; then
    log_verbose "Using standard read with prompt"
    read -p "Selection: " SELECTION
else
    log_verbose "STDIN is not a terminal, trying /dev/tty"
    # Non-interactive mode (like curl | bash), read from /dev/tty if available
    if [ -e /dev/tty ]; then
        log_verbose "Using /dev/tty for input"
        echo -n "Selection: "
        read SELECTION </dev/tty
    else
        log_verbose "No /dev/tty available, using default"
        echo "⚠️  Running in non-interactive mode, using current subscription"
        SELECTION=""
    fi
fi

log_verbose "Selection received: '$SELECTION'"

# Validate and set subscription
if [[ -z "$SELECTION" ]]; then
    # Use current subscription
    echo "✅ Using current subscription"
    log_verbose "Keeping current subscription active"
elif [[ "$SELECTION" =~ ^[0-9]+$ ]] && [ "$SELECTION" -ge 1 ] && [ "$SELECTION" -le ${#SUBSCRIPTIONS[@]} ]; then
    # Valid selection
    SELECTED_INDEX=$((SELECTION-1))
    IFS=$'\t' read -r name id isDefault <<< "${SUBSCRIPTIONS[SELECTED_INDEX]}"
    
    echo "🔄 Would switch to subscription: $name"
    log_verbose "Setting active subscription to: $name (ID: $id)"
    
    # In real script, would call: az account set --subscription "$id"
    echo "✅ Successfully selected subscription: $name"
    log_verbose "Active subscription would be: $name (ID: $id)"
else
    echo "❌ FAILED - Invalid selection: $SELECTION"
    echo "Please enter a number between 1 and ${#SUBSCRIPTIONS[@]}"
    exit 1
fi

echo ""
echo "✅ Subscription selection completed!"

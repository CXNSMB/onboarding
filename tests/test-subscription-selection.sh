#!/bin/bash

# Test script voor subscription selectie
echo "🚀 Test Azure Subscription Selection"
echo "====================================="

# Mock Azure CLI response voor testing
echo "🔍 Simulating Azure CLI connectivity check..."

# Simuleer subscription data
MOCK_SUBSCRIPTIONS=(
    $'Test Subscription 1\t12345678-1234-1234-1234-123456789012\ttrue'
    $'Test Subscription 2\t87654321-4321-4321-4321-210987654321\tfalse'
    $'Development Subscription\t11111111-2222-3333-4444-555555555555\tfalse'
)

echo ""
echo "📋 Available Azure Subscriptions:"
echo "=================================="

# Display subscriptions with numbers
for i in "${!MOCK_SUBSCRIPTIONS[@]}"; do
    IFS=$'\t' read -r name id isDefault <<< "${MOCK_SUBSCRIPTIONS[i]}"
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
read -p "Selection: " SELECTION

# Validate and set subscription
if [[ -z "$SELECTION" ]]; then
    # Use current subscription
    echo "✅ Using current subscription"
    echo "Keeping current subscription active"
elif [[ "$SELECTION" =~ ^[0-9]+$ ]] && [ "$SELECTION" -ge 1 ] && [ "$SELECTION" -le ${#MOCK_SUBSCRIPTIONS[@]} ]; then
    # Valid selection
    SELECTED_INDEX=$((SELECTION-1))
    IFS=$'\t' read -r name id isDefault <<< "${MOCK_SUBSCRIPTIONS[SELECTED_INDEX]}"
    
    echo "🔄 Would switch to subscription: $name"
    echo "Setting active subscription to: $name (ID: $id)"
    
    echo "✅ Successfully switched to subscription: $name"
    echo "Active subscription is now: $name (ID: $id)"
else
    echo "❌ FAILED - Invalid selection: $SELECTION"
    echo "Please enter a number between 1 and ${#MOCK_SUBSCRIPTIONS[@]}"
    exit 1
fi

echo ""
echo "✅ Test completed successfully!"

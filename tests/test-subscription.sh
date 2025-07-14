#!/bin/bash

# Test the subscription selection part
echo "📋 Available Azure Subscriptions:"
echo "=================================="

# Mock subscriptions for testing
SUBSCRIPTIONS=(
    "Subscription 1	12345678-1234-1234-1234-123456789012	true"
    "Subscription 2	87654321-4321-4321-4321-210987654321	false"
    "Subscription 3	11223344-5566-7788-9900-112233445566	false"
)

echo "Mock subscriptions array has ${#SUBSCRIPTIONS[@]} items"

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
read -p "Selection: " SELECTION

echo "You selected: '$SELECTION'"
if [[ -z "$SELECTION" ]]; then
    echo "Empty selection - using current subscription"
elif [[ "$SELECTION" =~ ^[0-9]+$ ]]; then
    echo "Numeric selection: $SELECTION"
else
    echo "Invalid selection: $SELECTION"
fi

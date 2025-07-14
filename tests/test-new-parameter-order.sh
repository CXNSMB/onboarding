#!/bin/bash

echo "🧪 Test nieuwe parameter volgorde (subscription-id eerst)"
echo "======================================================"

echo ""
echo "📋 Nieuwe parameter volgorde:"
echo "1. subscription-id (verplicht als meerdere subscriptions)"
echo "2. app-name (optioneel, default: CXNSMB-github-solution-onboarding)"
echo "3. github-org (optioneel, default: CXNSMB)"
echo "4. github-repo (optioneel, default: solution-onboarding)"
echo "5. branch (optioneel, default: main)"
echo "6. verbose|management-group (optioneel)"
echo "7. management-group-name (optioneel als management-group gebruikt wordt)"
echo ""

echo "📝 Voorbeelden van gebruik:"
echo ""

echo "1️⃣  Basis gebruik met subscription ID:"
echo "   curl -s https://raw.githubusercontent.com/CXNSMB/onboarding/main/setup-app-registration.sh | bash -s -- \"12345678-1234-1234-1234-123456789012\" \"my-app\" \"my-org\" \"my-repo\" \"main\""
echo ""

echo "2️⃣  Met alleen subscription ID (andere parameters gebruiken defaults):"
echo "   curl -s https://raw.githubusercontent.com/CXNSMB/onboarding/main/setup-app-registration.sh | bash -s -- \"12345678-1234-1234-1234-123456789012\""
echo ""

echo "3️⃣  Met subscription ID en verbose mode:"
echo "   curl -s https://raw.githubusercontent.com/CXNSMB/onboarding/main/setup-app-registration.sh | bash -s -- \"12345678-1234-1234-1234-123456789012\" \"my-app\" \"my-org\" \"my-repo\" \"main\" \"verbose\""
echo ""

echo "4️⃣  Met subscription ID en management group:"
echo "   curl -s https://raw.githubusercontent.com/CXNSMB/onboarding/main/setup-app-registration.sh | bash -s -- \"12345678-1234-1234-1234-123456789012\" \"my-app\" \"my-org\" \"my-repo\" \"main\" \"management-group\" \"my-mg\""
echo ""

echo "5️⃣  Zonder subscription ID (automatische detectie bij 1 subscription, lijst bij meerdere):"
echo "   curl -s https://raw.githubusercontent.com/CXNSMB/onboarding/main/setup-app-registration.sh | bash -s -- \"\" \"my-app\" \"my-org\" \"my-repo\" \"main\""
echo ""

echo "🔍 Test parameter parsing..."

# Test functie
test_parameters() {
    local sub_id="$1"
    local app_name="${2:-CXNSMB-github-solution-onboarding}"
    local github_org="${3:-CXNSMB}"
    local github_repo="${4:-solution-onboarding}"
    local github_ref="${5:-main}"
    local option1="$6"
    local option2="$7"
    
    echo "  SUBSCRIPTION_ID: ${sub_id:-'(empty)'}"
    echo "  APP_NAME: $app_name"
    echo "  GITHUB_ORG: $github_org"
    echo "  GITHUB_REPO: $github_repo"
    echo "  GITHUB_REF: $github_ref"
    echo "  OPTION1: ${option1:-'(empty)'}"
    echo "  OPTION2: ${option2:-'(empty)'}"
}

echo ""
echo "Test 1: Alle parameters ingevuld"
echo "Commando: script.sh \"test-sub-id\" \"test-app\" \"test-org\" \"test-repo\" \"dev\" \"verbose\""
test_parameters "test-sub-id" "test-app" "test-org" "test-repo" "dev" "verbose"

echo ""
echo "Test 2: Alleen subscription ID"
echo "Commando: script.sh \"test-sub-id\""
test_parameters "test-sub-id"

echo ""
echo "Test 3: Subscription ID + app name"
echo "Commando: script.sh \"test-sub-id\" \"my-custom-app\""
test_parameters "test-sub-id" "my-custom-app"

echo ""
echo "Test 4: Geen subscription ID (empty string)"
echo "Commando: script.sh \"\""
test_parameters ""

echo ""
echo "✅ Parameter parsing test voltooid!"
echo ""

echo "💡 Voordelen van deze parameter volgorde:"
echo "   ✅ Subscription ID is de eerste parameter (meest belangrijke)"
echo "   ✅ Eenvoudiger om alleen subscription ID mee te geven"
echo "   ✅ Andere parameters hebben sensible defaults"
echo "   ✅ Consistent met Azure CLI conventies"

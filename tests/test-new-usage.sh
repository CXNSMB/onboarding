#!/bin/bash

echo "🧪 Test van het aangepaste setup-app-registration script"
echo "========================================================"

echo ""
echo "📋 Voorbeelden van gebruik:"
echo ""

echo "1️⃣  Met subscription ID:"
echo "   curl -s https://raw.githubusercontent.com/CXNSMB/onboarding/main/setup-app-registration.sh | bash -s -- \"my-app\" \"my-org\" \"my-repo\" \"main\" \"12345678-1234-1234-1234-123456789012\""
echo ""

echo "2️⃣  Met subscription ID en verbose mode:"
echo "   curl -s https://raw.githubusercontent.com/CXNSMB/onboarding/main/setup-app-registration.sh | bash -s -- \"my-app\" \"my-org\" \"my-repo\" \"main\" \"12345678-1234-1234-1234-123456789012\" \"verbose\""
echo ""

echo "3️⃣  Met subscription ID en management group:"
echo "   curl -s https://raw.githubusercontent.com/CXNSMB/onboarding/main/setup-app-registration.sh | bash -s -- \"my-app\" \"my-org\" \"my-repo\" \"main\" \"12345678-1234-1234-1234-123456789012\" \"management-group\" \"my-mg\""
echo ""

echo "4️⃣  Zonder subscription ID (gebruikt huidige):"
echo "   curl -s https://raw.githubusercontent.com/CXNSMB/onboarding/main/setup-app-registration.sh | bash -s -- \"my-app\" \"my-org\" \"my-repo\" \"main\""
echo ""

echo "📝 Test met lokaal script..."
echo ""

# Test de parameter parsing
echo "🔍 Test 1: Met subscription ID"
echo "Commando: ./setup-app-registration.sh \"test-app\" \"test-org\" \"test-repo\" \"main\" \"test-subscription-id\""
echo "Parameters:"
echo "  APP_NAME=test-app"
echo "  GITHUB_ORG=test-org" 
echo "  GITHUB_REPO=test-repo"
echo "  GITHUB_REF=main"
echo "  SUBSCRIPTION_ID=test-subscription-id"
echo ""

echo "🔍 Test 2: Met subscription ID en verbose"
echo "Commando: ./setup-app-registration.sh \"test-app\" \"test-org\" \"test-repo\" \"main\" \"test-subscription-id\" \"verbose\""
echo "Parameters:"
echo "  APP_NAME=test-app"
echo "  GITHUB_ORG=test-org"
echo "  GITHUB_REPO=test-repo" 
echo "  GITHUB_REF=main"
echo "  SUBSCRIPTION_ID=test-subscription-id"
echo "  VERBOSE=true"
echo ""

echo "🔍 Test 3: Zonder subscription ID"
echo "Commando: ./setup-app-registration.sh \"test-app\" \"test-org\" \"test-repo\" \"main\""
echo "Parameters:"
echo "  APP_NAME=test-app"
echo "  GITHUB_ORG=test-org"
echo "  GITHUB_REPO=test-repo"
echo "  GITHUB_REF=main"
echo "  SUBSCRIPTION_ID=(empty - gebruikt huidige)"
echo ""

echo "✅ Parameter parsing test voltooid!"
echo ""

echo "💡 Om een subscription ID te vinden, gebruik:"
echo "   az account list --query \"[].{name:name, id:id}\" --output table"

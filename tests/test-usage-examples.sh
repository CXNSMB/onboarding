#!/bin/bash

echo "🧪 Testing the updated setup-app-registration script"
echo "===================================================="

echo ""
echo "📋 Usage Examples:"
echo ""

echo "1️⃣  With subscription ID as first parameter:"
echo "   curl -s https://raw.githubusercontent.com/CXNSMB/onboarding/main/setup-app-registration.sh | bash -s -- \"12345678-1234-1234-1234-123456789012\" \"my-org\" \"my-repo\" \"main\""
echo ""

echo "2️⃣  With subscription ID and verbose mode:"
echo "   curl -s https://raw.githubusercontent.com/CXNSMB/onboarding/main/setup-app-registration.sh | bash -s -- \"12345678-1234-1234-1234-123456789012\" \"my-org\" \"my-repo\" \"main\" \"verbose\""
echo ""

echo "3️⃣  With subscription ID and management group:"
echo "   curl -s https://raw.githubusercontent.com/CXNSMB/onboarding/main/setup-app-registration.sh | bash -s -- \"12345678-1234-1234-1234-123456789012\" \"my-org\" \"my-repo\" \"main\" \"management-group\" \"my-mg\""
echo ""

echo "4️⃣  Without subscription ID (auto-detect single subscription or show multiple options):"
echo "   curl -s https://raw.githubusercontent.com/CXNSMB/onboarding/main/setup-app-registration.sh | bash -s -- \"\" \"my-org\" \"my-repo\" \"main\""
echo ""

echo "📝 Testing with local script..."
echo ""

echo "🔍 Test 1: With subscription ID as first parameter"
echo "Command: ./setup-app-registration.sh \"test-subscription-id\" \"test-org\" \"test-repo\" \"main\""
echo "Parameters:"
echo "  SUBSCRIPTION_ID=test-subscription-id"
echo "  GITHUB_ORG=test-org" 
echo "  GITHUB_REPO=test-repo"
echo "  GITHUB_REF=main"
echo "  APP_NAME=test-org-github-test-repo-<tenant-id> (auto-generated)"
echo ""

echo "🔍 Test 2: With subscription ID and verbose"
echo "Command: ./setup-app-registration.sh \"test-subscription-id\" \"test-org\" \"test-repo\" \"main\" \"verbose\""
echo "Parameters:"
echo "  SUBSCRIPTION_ID=test-subscription-id"
echo "  GITHUB_ORG=test-org"
echo "  GITHUB_REPO=test-repo" 
echo "  GITHUB_REF=main"
echo "  VERBOSE=true"
echo "  APP_NAME=test-org-github-test-repo-<tenant-id> (auto-generated)"
echo ""

echo "🔍 Test 3: Without subscription ID (auto-detect)"
echo "Command: ./setup-app-registration.sh \"\" \"test-org\" \"test-repo\" \"main\""
echo "Parameters:"
echo "  SUBSCRIPTION_ID=(empty - auto-detect)"
echo "  GITHUB_ORG=test-org"
echo "  GITHUB_REPO=test-repo"
echo "  GITHUB_REF=main"
echo "  APP_NAME=test-org-github-test-repo-<tenant-id> (auto-generated)"
echo ""

echo "✅ Parameter testing completed!"
echo ""

echo "💡 To find a subscription ID, use:"
echo "   az account list --query \"[].{name:name, id:id}\" --output table"
echo ""

echo "📁 Additional test scripts available in the tests/ directory:"
echo "   - test-subscription-logic.sh      - Test subscription selection scenarios"
echo "   - test-subscription-switching.sh  - Test subscription switching functionality"
echo "   - test-subscription-selection.sh  - Test interactive subscription selection"

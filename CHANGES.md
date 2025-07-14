# Azure OIDC Setup Script - Summary of Changes

## 📋 What Changed

### ✅ Parameter Order Updated
The subscription ID is now the **first parameter** and the app name is **auto-generated**:

**New Order:**
1. `SUBSCRIPTION_ID` (optional)
2. `GITHUB_ORG` (default: CXNSMB)
3. `GITHUB_REPO` (default: solution-onboarding)
4. `GITHUB_REF` (default: main)
5. `OPTIONS` (verbose, management-group)
6. `MANAGEMENT_GROUP_NAME`

**App Name**: Auto-generated as `{GITHUB_ORG}-github-{GITHUB_REPO}-{TENANT_ID}`

### ✅ Smart Subscription Handling
- **Single subscription**: Automatically uses it without user interaction
- **Multiple subscriptions**: Shows copy-paste ready curl commands for each subscription
- **Specific subscription ID**: Validates and switches to the provided subscription

### ✅ Removed Interactive Input
- No more interactive prompts that don't work with `curl | bash`
- Fully automated workflow suitable for CI/CD pipelines
- Better user experience with clear instructions

### ✅ Organized Test Scripts
All test scripts moved to `/tests/` directory:
- `test-usage-examples.sh` - Usage examples and documentation
- `test-subscription-logic.sh` - Test subscription selection scenarios
- `test-subscription-switching.sh` - Test real Azure CLI switching
- `test-subscription-selection.sh` - Test mock selection logic

## 🚀 Usage Examples

### With Subscription ID (Recommended)
```bash
curl -s https://raw.githubusercontent.com/CXNSMB/onboarding/main/setup-app-registration.sh | bash -s -- "12345678-1234-1234-1234-123456789012" "my-org" "my-repo" "main"
```

### Auto-detect Subscription
```bash
curl -s https://raw.githubusercontent.com/CXNSMB/onboarding/main/setup-app-registration.sh | bash -s -- "" "my-org" "my-repo" "main"
```

### With Verbose Mode
```bash
curl -s https://raw.githubusercontent.com/CXNSMB/onboarding/main/setup-app-registration.sh | bash -s -- "12345678-1234-1234-1234-123456789012" "my-org" "my-repo" "main" "verbose"
```

### With Management Group
```bash
curl -s https://raw.githubusercontent.com/CXNSMB/onboarding/main/setup-app-registration.sh | bash -s -- "12345678-1234-1234-1234-123456789012" "my-org" "my-repo" "main" "management-group" "my-mg"
```

## 📊 Behavior Scenarios

| Scenario | Behavior |
|----------|----------|
| **No subscription ID + 1 subscription** | ✅ Automatically uses the single subscription |
| **No subscription ID + multiple subscriptions** | 📋 Shows curl commands for each subscription |
| **Valid subscription ID provided** | 🔄 Validates and switches to specified subscription |
| **Invalid subscription ID provided** | ❌ Shows error and exits with helpful message |

## 🎯 Benefits

### ✅ **Automation Ready**
- Works perfectly with `curl \| bash`
- No interactive prompts to break automation
- Suitable for CI/CD pipelines

### ✅ **User Friendly**
- Clear copy-paste commands for multiple subscriptions
- Helpful error messages
- Automatic single subscription detection

### ✅ **Predictable**
- Exact control over which subscription is used
- No surprising interactive prompts
- Consistent behavior across environments

### ✅ **Maintainable**
- All test scripts organized in separate directory
- Comprehensive test coverage
- Clear documentation and examples

## 🔍 Testing

Run the test scripts to see the functionality:

```bash
# Show usage examples
./tests/test-usage-examples.sh

# Test single subscription scenario
./tests/test-subscription-logic.sh single

# Test multiple subscriptions scenario  
./tests/test-subscription-logic.sh multiple

# Test with real Azure CLI (if logged in)
./tests/test-subscription-switching.sh
```

## 📝 Getting Subscription ID

To find your subscription ID:

```bash
az account list --query "[].{name:name, id:id}" --output table
```

The script is now optimized for both automation and user experience! 🎉

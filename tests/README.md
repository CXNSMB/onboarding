# Test Scripts

This directory contains test scripts for the Azure OIDC setup script.

## Available Tests

### test-usage-examples.sh
Shows usage examples and parameter combinations for the main setup script.

```bash
./test-usage-examples.sh
```

### test-subscription-logic.sh
Tests the subscription selection logic with different scenarios.

```bash
# Test single subscription scenario
./test-subscription-logic.sh single

# Test multiple subscriptions scenario
./test-subscription-logic.sh multiple

# Test with specific subscription ID
./test-subscription-logic.sh multiple test-app test-org test-repo main 22222222-2222-2222-2222-222222222222

# Test with verbose mode
./test-subscription-logic.sh multiple test-app test-org test-repo main "" verbose
```

### test-subscription-switching.sh
Tests subscription switching functionality with real Azure CLI commands.

```bash
# Test without subscription ID (use current)
./test-subscription-switching.sh

# Test with specific subscription ID
./test-subscription-switching.sh "test-app" "test-org" "test-repo" "main" "subscription-id" "verbose"
```

### test-subscription-selection.sh
Tests interactive subscription selection (mock data).

```bash
./test-subscription-selection.sh
```

## Test Scenarios

### Single Subscription
When only one subscription is available, the script automatically uses it without asking for input.

### Multiple Subscriptions
When multiple subscriptions are available, the script shows each subscription with the complete curl command to run the setup with that specific subscription.

### Specific Subscription ID
When a subscription ID is provided as the first parameter, the script validates and switches to that subscription.

## Parameter Order

The main script now uses this parameter order:

1. `SUBSCRIPTION_ID` (optional - if empty, auto-detects)
2. `GITHUB_ORG` (default: CXNSMB)
3. `GITHUB_REPO` (default: solution-onboarding)
4. `GITHUB_REF` (default: main)
5. `OPTIONS` (verbose, management-group)
6. `MANAGEMENT_GROUP_NAME` (if management-group option is used)

**Note:** The app name is automatically generated as: `{GITHUB_ORG}-github-{GITHUB_REPO}-{TENANT_ID}`

## Example Commands

```bash
# With subscription ID
curl -s https://raw.githubusercontent.com/CXNSMB/onboarding/main/setup-app-registration.sh | bash -s -- "12345678-1234-1234-1234-123456789012" "my-org" "my-repo" "main"

# Auto-detect subscription
curl -s https://raw.githubusercontent.com/CXNSMB/onboarding/main/setup-app-registration.sh | bash -s -- "" "my-org" "my-repo" "main"

# With verbose mode
curl -s https://raw.githubusercontent.com/CXNSMB/onboarding/main/setup-app-registration.sh | bash -s -- "12345678-1234-1234-1234-123456789012" "my-org" "my-repo" "main" "verbose"
```

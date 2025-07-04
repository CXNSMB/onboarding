#!/usr/bin/env pwsh
# Test deployment van onboarding.bicep
# Run this in Azure Cloud Shell

param(
    [string]$AppName = "CXNSMB-github-lh",
    [string]$RoleDefinitionId = "18d7d88d-d35e-4fb5-a5c3-7773c20a72d9",
    [string]$Location = "West Europe"
)

Write-Host "🚀 Testing onboarding.bicep deployment..." -ForegroundColor Green
Write-Host "App Name: $AppName" -ForegroundColor Cyan
Write-Host "Role: $RoleDefinitionId (User Access Administrator)" -ForegroundColor Cyan
Write-Host ""

# Get current subscription info
$subscriptionInfo = az account show --query '{id:id, name:name, tenantId:tenantId}' --output json | ConvertFrom-Json
Write-Host "📋 Current Azure context:" -ForegroundColor Yellow
Write-Host "Subscription: $($subscriptionInfo.name) ($($subscriptionInfo.id))" -ForegroundColor Cyan
Write-Host "Tenant: $($subscriptionInfo.tenantId)" -ForegroundColor Cyan
Write-Host ""

# Deploy the Bicep template
Write-Host "🔧 Deploying onboarding.bicep..." -ForegroundColor Yellow
$deploymentName = "onboarding-test-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

$deploymentResult = az deployment sub create `
    --location $Location `
    --template-file "onboarding.bicep" `
    --name $deploymentName `
    --parameters appName=$AppName roleDefinitionId=$RoleDefinitionId `
    --query 'properties.outputs' `
    --output json

if ($LASTEXITCODE -ne 0) {
    Write-Error "❌ Failed to deploy Bicep template"
    exit 1
}

$outputs = $deploymentResult | ConvertFrom-Json

Write-Host "✅ Bicep template deployed successfully!" -ForegroundColor Green
Write-Host ""

# Extract and display outputs
$appId = $outputs.appRegistrationId.value
$spId = $outputs.servicePrincipalId.value
$federatedCredCommand = $outputs.createFederatedCredentialCommand.value
$githubSecrets = $outputs.githubSecrets.value

Write-Host "📋 Deployment Results:" -ForegroundColor Yellow
Write-Host "App Registration ID: $appId" -ForegroundColor Cyan
Write-Host "Service Principal ID: $spId" -ForegroundColor Cyan
Write-Host ""

# Show the federated credential command
Write-Host "🔗 Next Step - Run this command to create the federated credential:" -ForegroundColor Yellow
Write-Host ""
Write-Host $federatedCredCommand -ForegroundColor Green
Write-Host ""

# Show GitHub secrets
Write-Host "📝 GitHub Actions Secrets:" -ForegroundColor Yellow
Write-Host "AZURE_CLIENT_ID: $($githubSecrets.AZURE_CLIENT_ID)" -ForegroundColor Cyan
Write-Host "AZURE_TENANT_ID: $($githubSecrets.AZURE_TENANT_ID)" -ForegroundColor Cyan
Write-Host "AZURE_SUBSCRIPTION_ID: $($githubSecrets.AZURE_SUBSCRIPTION_ID)" -ForegroundColor Cyan
Write-Host ""

# Security reminder
Write-Host "⚠️  Security Note:" -ForegroundColor Yellow
Write-Host "This service principal has User Access Administrator with security restrictions." -ForegroundColor White
Write-Host "It CANNOT assign these forbidden roles:" -ForegroundColor White
Write-Host "- Owner" -ForegroundColor Red
Write-Host "- User Access Administrator" -ForegroundColor Red  
Write-Host "- RBAC Administrator" -ForegroundColor Red
Write-Host ""

Write-Host "✅ Test completed! Now run the federated credential command above." -ForegroundColor Green

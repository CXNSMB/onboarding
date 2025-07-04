#!/usr/bin/env pwsh
# Complete Azure setup for GitHub Actions OIDC
# Run this in Azure Cloud Shell or local machine with Azure CLI

param(
    [string]$AppName = "CXNSMB-github-lh",
    [string]$GitHubRepo = "CXNSMB/onboarding", 
    [string]$GitHubRef = "refs/heads/main",
    [string]$Location = "West Europe",
    [string]$ResourceGroupName = ""
)

# Set error handling
$ErrorActionPreference = "Stop"

Write-Host "🚀 Starting Azure setup for GitHub Actions OIDC..." -ForegroundColor Green
Write-Host "App Name: $AppName" -ForegroundColor Cyan
Write-Host "GitHub Repo: $GitHubRepo" -ForegroundColor Cyan
Write-Host "GitHub Ref: $GitHubRef" -ForegroundColor Cyan
Write-Host "Location: $Location" -ForegroundColor Cyan
Write-Host ""

# Get current subscription info
Write-Host "📋 Getting Azure context..." -ForegroundColor Yellow
$subscriptionInfo = az account show --query '{id:id, name:name, tenantId:tenantId}' --output json | ConvertFrom-Json
Write-Host "Subscription: $($subscriptionInfo.name) ($($subscriptionInfo.id))" -ForegroundColor Cyan
Write-Host "Tenant: $($subscriptionInfo.tenantId)" -ForegroundColor Cyan
Write-Host ""

# Create resource group if not specified
if ([string]::IsNullOrEmpty($ResourceGroupName)) {
    $uniqueString = (az account show --query id --output tsv).Substring(0,8)
    $ResourceGroupName = "rg-$AppName-$uniqueString"
}

Write-Host "🏗️  Creating resource group: $ResourceGroupName" -ForegroundColor Yellow
az group create --name $ResourceGroupName --location $Location --tags purpose="GitHub Actions OIDC" project="CXNSMB-onboarding"

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to create resource group"
    exit 1
}

Write-Host "✅ Resource group created successfully" -ForegroundColor Green
Write-Host ""

# Deploy Bicep template
Write-Host "🔧 Deploying Bicep template..." -ForegroundColor Yellow
$deploymentName = "github-oidc-setup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

$deploymentResult = az deployment group create `
    --resource-group $ResourceGroupName `
    --template-file "complete-setup.bicep" `
    --name $deploymentName `
    --parameters appName=$AppName githubRepo=$GitHubRepo githubRef=$GitHubRef `
    --query 'properties.outputs' `
    --output json

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to deploy Bicep template"
    exit 1
}

$outputs = $deploymentResult | ConvertFrom-Json

Write-Host "✅ Bicep template deployed successfully" -ForegroundColor Green
Write-Host ""

# Extract outputs
$clientId = $outputs.managedIdentityClientId.value
$principalId = $outputs.managedIdentityPrincipalId.value
$federatedCredCommand = $outputs.federatedCredentialCommand.value
$roleAssignmentCommand = $outputs.roleAssignmentCommand.value

Write-Host "🔐 Creating role assignment with security conditions..." -ForegroundColor Yellow
Write-Host "Command: $roleAssignmentCommand" -ForegroundColor Gray

# Execute role assignment command
Invoke-Expression $roleAssignmentCommand

if ($LASTEXITCODE -ne 0) {
    Write-Warning "Role assignment may have failed or already exists"
} else {
    Write-Host "✅ Role assignment created successfully" -ForegroundColor Green
}
Write-Host ""

Write-Host "🔗 Creating federated identity credential..." -ForegroundColor Yellow
Write-Host "Command: $federatedCredCommand" -ForegroundColor Gray

# Execute federated credential command
Invoke-Expression $federatedCredCommand

if ($LASTEXITCODE -ne 0) {
    Write-Warning "Federated credential creation may have failed or already exists"
} else {
    Write-Host "✅ Federated credential created successfully" -ForegroundColor Green
}
Write-Host ""

# Verify setup
Write-Host "🔍 Verifying setup..." -ForegroundColor Yellow
Write-Host ""

Write-Host "Managed Identity:" -ForegroundColor Cyan
az identity show --ids "/subscriptions/$($subscriptionInfo.id)/resourceGroups/$ResourceGroupName/providers/Microsoft.ManagedIdentity/userAssignedManagedIdentities/mi-$AppName" --query '{name:name, clientId:clientId, principalId:principalId}' --output table

Write-Host ""
Write-Host "Role Assignments:" -ForegroundColor Cyan
az role assignment list --assignee $principalId --output table

Write-Host ""
Write-Host "🎉 Setup completed successfully!" -ForegroundColor Green
Write-Host ""

# Output GitHub Actions configuration
Write-Host "📝 GitHub Actions Configuration:" -ForegroundColor Yellow
Write-Host "Add these secrets to your GitHub repository:" -ForegroundColor White
Write-Host ""
Write-Host "AZURE_CLIENT_ID: $clientId" -ForegroundColor Cyan
Write-Host "AZURE_TENANT_ID: $($subscriptionInfo.tenantId)" -ForegroundColor Cyan  
Write-Host "AZURE_SUBSCRIPTION_ID: $($subscriptionInfo.id)" -ForegroundColor Cyan
Write-Host ""

# Security reminder
Write-Host "⚠️  Security Note:" -ForegroundColor Yellow
Write-Host "This managed identity has User Access Administrator permissions with security restrictions." -ForegroundColor White
Write-Host "It CANNOT assign these forbidden roles:" -ForegroundColor White
Write-Host "- Owner (8e3af657-a8ff-443c-a75c-2fe8c4bcb635)" -ForegroundColor Red
Write-Host "- User Access Administrator (18d7d88d-d35e-4fb5-a5c3-7773c20a72d9)" -ForegroundColor Red
Write-Host "- RBAC Administrator (f58310d9-a9f6-439a-9e8d-f62e7b41a168)" -ForegroundColor Red
Write-Host ""
Write-Host "Safe roles to assign:" -ForegroundColor White
Write-Host "- Contributor (b24988ac-6180-42a0-ab88-20f7382dd24c)" -ForegroundColor Green
Write-Host "- Reader (acdd72a7-3385-48ef-bd42-f606fba81ae7)" -ForegroundColor Green
Write-Host "- Storage Account Contributor (17d1049b-9a84-46fb-8f53-869881c3d3ab)" -ForegroundColor Green
Write-Host ""

# Example workflow
Write-Host "📋 Example GitHub Actions workflow:" -ForegroundColor Yellow
@'
name: Azure Deployment
on:
  push:
    branches: [ main ]

jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Azure Login
      uses: azure/login@v1
      with:
        client-id: ${{ secrets.AZURE_CLIENT_ID }}
        tenant-id: ${{ secrets.AZURE_TENANT_ID }}
        subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
    
    - name: Deploy to Azure
      run: |
        az --version
        # Example: Deploy with safe role assignments
        az deployment group create \
          --resource-group "my-resource-group" \
          --template-file "main.bicep" \
          --parameters roleDefinitionId="b24988ac-6180-42a0-ab88-20f7382dd24c"
'@

Write-Host ""
Write-Host "✅ All done! Your GitHub Actions can now authenticate to Azure using OIDC." -ForegroundColor Green

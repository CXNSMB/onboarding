#!/usr/bin/env pwsh
# Bootstrap script voor GitHub Actions OIDC setup
# Handelt het chicken-and-egg probleem af met RBAC permissions

param(
    [string]$AppName = "CXNSMB-github-lh",
    [string]$GitHubRepo = "CXNSMB/onboarding",
    [string]$GitHubRef = "refs/heads/main",
    [string]$RoleDefinitionId = "18d7d88d-d35e-4fb5-a5c3-7773c20a72d9",
    [string]$Location = "West Europe"
)

Write-Host "🚀 Bootstrap setup voor GitHub Actions OIDC..." -ForegroundColor Green
Write-Host "App Name: $AppName" -ForegroundColor Cyan
Write-Host "GitHub Repo: $GitHubRepo" -ForegroundColor Cyan
Write-Host "Role: User Access Administrator" -ForegroundColor Cyan
Write-Host ""

# Get current subscription info
$subscriptionInfo = az account show --query '{id:id, name:name, tenantId:tenantId}' --output json | ConvertFrom-Json
$subscriptionId = $subscriptionInfo.id
$tenantId = $subscriptionInfo.tenantId

Write-Host "📋 Current Azure context:" -ForegroundColor Yellow
Write-Host "Subscription: $($subscriptionInfo.name) ($subscriptionId)" -ForegroundColor Cyan
Write-Host "Tenant: $tenantId" -ForegroundColor Cyan
Write-Host ""

# Step 1: Check if App Registration already exists
Write-Host "🔍 Checking if App Registration exists..." -ForegroundColor Yellow
$existingApp = az ad app list --query "[?displayName=='$AppName'].appId" --output tsv

if ($existingApp) {
    Write-Host "✅ App Registration already exists: $existingApp" -ForegroundColor Green
    $appId = $existingApp
} else {
    Write-Host "📌 Creating App Registration..." -ForegroundColor Yellow
    $appId = az ad app create --display-name $AppName --query appId --output tsv
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "❌ Failed to create App Registration"
        exit 1
    }
    
    Write-Host "✅ App Registration created: $appId" -ForegroundColor Green
}

# Step 2: Check if Service Principal exists
Write-Host "🔄 Checking Service Principal..." -ForegroundColor Yellow
$spId = az ad sp list --query "[?appId=='$appId'].id" --output tsv

if ($spId) {
    Write-Host "✅ Service Principal already exists: $spId" -ForegroundColor Green
} else {
    Write-Host "📌 Creating Service Principal..." -ForegroundColor Yellow
    $spId = az ad sp create --id $appId --query id --output tsv
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "❌ Failed to create Service Principal"
        exit 1
    }
    
    Write-Host "✅ Service Principal created: $spId" -ForegroundColor Green
}

# Step 3: Create initial RBAC assignment (without conditions) to bootstrap permissions
Write-Host "🔓 Creating initial RBAC assignment..." -ForegroundColor Yellow

# Check if assignment already exists
$existingAssignment = az role assignment list --assignee $spId --role $RoleDefinitionId --scope "/subscriptions/$subscriptionId" --query "[0].name" --output tsv

if ($existingAssignment) {
    Write-Host "⚠️  RBAC assignment already exists, will update with security conditions..." -ForegroundColor Yellow
    
    # Check if it has conditions
    $hasConditions = az role assignment list --assignee $spId --role $RoleDefinitionId --scope "/subscriptions/$subscriptionId" --query "[0].condition" --output tsv
    
    if ($hasConditions -and $hasConditions -ne "null") {
        Write-Host "✅ RBAC assignment already has conditions" -ForegroundColor Green
    } else {
        Write-Host "🔄 Updating RBAC assignment to add security conditions..." -ForegroundColor Yellow
        
        # Delete old assignment without conditions
        az role assignment delete --assignee $spId --role $RoleDefinitionId --scope "/subscriptions/$subscriptionId"
        
        # Create new assignment with conditions
        $condition = '(!(ActionMatches{"Microsoft.Authorization/roleAssignments/write"})) OR (ActionMatches{"Microsoft.Authorization/roleAssignments/write"} AND NOT (Resource[Microsoft.Authorization/roleAssignments:RoleDefinitionId] StringEquals "8e3af657-a8ff-443c-a75c-2fe8c4bcb635" OR Resource[Microsoft.Authorization/roleAssignments:RoleDefinitionId] StringEquals "18d7d88d-d35e-4fb5-a5c3-7773c20a72d9" OR Resource[Microsoft.Authorization/roleAssignments:RoleDefinitionId] StringEquals "f58310d9-a9f6-439a-9e8d-f62e7b41a168"))'
        
        az role assignment create --assignee $spId --role $RoleDefinitionId --scope "/subscriptions/$subscriptionId" --condition $condition --condition-version "2.0"
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ RBAC assignment updated with security conditions" -ForegroundColor Green
        } else {
            Write-Warning "⚠️  Failed to update RBAC assignment with conditions"
        }
    }
} else {
    Write-Host "📌 Creating initial RBAC assignment with security conditions..." -ForegroundColor Yellow
    
    $condition = '(!(ActionMatches{"Microsoft.Authorization/roleAssignments/write"})) OR (ActionMatches{"Microsoft.Authorization/roleAssignments/write"} AND NOT (Resource[Microsoft.Authorization/roleAssignments:RoleDefinitionId] StringEquals "8e3af657-a8ff-443c-a75c-2fe8c4bcb635" OR Resource[Microsoft.Authorization/roleAssignments:RoleDefinitionId] StringEquals "18d7d88d-d35e-4fb5-a5c3-7773c20a72d9" OR Resource[Microsoft.Authorization/roleAssignments:RoleDefinitionId] StringEquals "f58310d9-a9f6-439a-9e8d-f62e7b41a168"))'
    
    az role assignment create --assignee $spId --role $RoleDefinitionId --scope "/subscriptions/$subscriptionId" --condition $condition --condition-version "2.0"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ RBAC assignment created with security conditions" -ForegroundColor Green
    } else {
        Write-Error "❌ Failed to create RBAC assignment"
        exit 1
    }
}

# Step 4: Create federated credential
Write-Host "🔗 Creating federated credential..." -ForegroundColor Yellow

# Check if credential already exists
$existingCred = az ad app federated-credential list --id $appId --query "[?name=='github-oidc'].name" --output tsv

if ($existingCred) {
    Write-Host "✅ Federated credential already exists" -ForegroundColor Green
} else {
    $federatedCredParams = @{
        name = "github-oidc"
        issuer = "https://token.actions.githubusercontent.com"
        subject = "repo:$GitHubRepo`:ref:$GitHubRef"
        description = "GitHub Actions OIDC federated credential"
        audiences = @("api://AzureADTokenExchange")
    } | ConvertTo-Json -Compress
    
    az ad app federated-credential create --id $appId --parameters $federatedCredParams
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Federated credential created successfully" -ForegroundColor Green
    } else {
        Write-Error "❌ Failed to create federated credential"
        exit 1
    }
}

# Step 5: Verify setup
Write-Host ""
Write-Host "🔍 Verifying setup..." -ForegroundColor Yellow

Write-Host "App Registration:" -ForegroundColor Cyan
az ad app show --id $appId --query "{displayName:displayName, appId:appId}" --output table

Write-Host ""
Write-Host "Service Principal:" -ForegroundColor Cyan
az ad sp show --id $spId --query "{displayName:displayName, appId:appId}" --output table

Write-Host ""
Write-Host "Role Assignments:" -ForegroundColor Cyan
az role assignment list --assignee $spId --output table

Write-Host ""
Write-Host "Federated Credentials:" -ForegroundColor Cyan
az ad app federated-credential list --id $appId --output table

Write-Host ""
Write-Host "🎉 Setup completed successfully!" -ForegroundColor Green
Write-Host ""

# Output GitHub Actions configuration
Write-Host "📝 GitHub Actions Configuration:" -ForegroundColor Yellow
Write-Host "Add these secrets to your GitHub repository:" -ForegroundColor White
Write-Host ""
Write-Host "AZURE_CLIENT_ID: $appId" -ForegroundColor Cyan
Write-Host "AZURE_TENANT_ID: $tenantId" -ForegroundColor Cyan
Write-Host "AZURE_SUBSCRIPTION_ID: $subscriptionId" -ForegroundColor Cyan
Write-Host ""

# Security reminder
Write-Host "⚠️  Security Note:" -ForegroundColor Yellow
Write-Host "This service principal has User Access Administrator with security restrictions." -ForegroundColor White
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

Write-Host "✅ All done! Your GitHub Actions can now authenticate to Azure using OIDC." -ForegroundColor Green

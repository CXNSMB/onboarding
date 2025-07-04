# Two-stage deployment script for Azure App Registration with OIDC

# Stage 1: Deploy App Registration and Service Principal
Write-Host "Stage 1: Deploying App Registration and Service Principal..." -ForegroundColor Green
$deployment1 = az deployment sub create `
  --location "West Europe" `
  --template-file "onboarding.bicep" `
  --name "onboarding-stage1" `
  --query "properties.outputs.appregid.value" `
  --output tsv

if ($LASTEXITCODE -ne 0) {
    Write-Error "Stage 1 deployment failed!"
    exit 1
}

Write-Host "App Registration created with ID: $deployment1" -ForegroundColor Yellow

# Stage 2: Deploy Federated Identity Credential
Write-Host "Stage 2: Deploying Federated Identity Credential..." -ForegroundColor Green
az deployment sub create `
  --location "West Europe" `
  --template-file "federated-credential-alt.bicep" `
  --name "onboarding-stage2" `
  --parameters appId=$deployment1

if ($LASTEXITCODE -ne 0) {
    Write-Error "Stage 2 deployment failed!"
    exit 1
}

Write-Host "Deployment completed successfully!" -ForegroundColor Green
Write-Host "App Registration ID: $deployment1" -ForegroundColor Yellow

# Alternative approach: Use Azure CLI to create federated credential
# This is more reliable than Bicep for Microsoft Graph preview features

param(
    [string]$AppId = "97ae714c-4457-4df7-96d7-63aeee083bb9",
    [string]$GitHubRepo = "CXNSMB/onboarding",
    [string]$GitHubRef = "refs/heads/main"
)

Write-Host "Creating federated identity credential for App ID: $AppId" -ForegroundColor Green

# Create the federated credential using Azure CLI
$credentialConfig = @{
    name = "github-oidc"
    issuer = "https://token.actions.githubusercontent.com"
    subject = "repo:$GitHubRepo`:ref:$GitHubRef"
    description = "GitHub Actions OIDC federated credential"
    audiences = @("api://AzureADTokenExchange")
} | ConvertTo-Json -Depth 3

Write-Host "Credential configuration:" -ForegroundColor Yellow
Write-Host $credentialConfig

# Create the federated credential
try {
    az ad app federated-credential create --id $AppId --parameters $credentialConfig
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Federated credential created successfully!" -ForegroundColor Green
        
        # Verify it was created
        Write-Host "Verifying federated credentials..." -ForegroundColor Yellow
        az ad app federated-credential list --id $AppId --output table
    } else {
        Write-Error "Failed to create federated credential!"
        exit 1
    }
} catch {
    Write-Error "Error creating federated credential: $_"
    exit 1
}

Write-Host "Setup completed successfully!" -ForegroundColor Green

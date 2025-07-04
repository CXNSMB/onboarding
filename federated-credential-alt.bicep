@description('App ID van de bestaande App Registration')
param appId string

@description('GitHub repo in formaat org/repo')
param githubRepo string = 'CXNSMB/onboarding'

@description('GitHub ref, bv. refs/heads/main')
param githubRef string = 'refs/heads/main'

targetScope = 'subscription'

extension microsoftGraphV1

// 🔗 Direct aanmaken van federated credential met expliciete parent reference
resource federatedCredential 'Microsoft.Graph/applications/federatedIdentityCredentials@v1.0' = {
  // De name moet de volledige path zijn: appId/credentialName
  name: '${appId}/github-oidc'
  audiences: [
    'api://AzureADTokenExchange'
  ]
  issuer: 'https://token.actions.githubusercontent.com'
  subject: 'repo:${githubRepo}:ref:${githubRef}'
  description: 'GitHub Actions OIDC federated credential'
}

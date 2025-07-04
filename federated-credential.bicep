@description('App ID van de bestaande App Registration')
param appId string = '97ae714c-4457-4df7-96d7-63aeee083bb9'

@description('GitHub repo in formaat org/repo')
param githubRepo string = 'CXNSMB/onboarding'

@description('GitHub ref, bv. refs/heads/main')
param githubRef string = 'refs/heads/main'

targetScope = 'subscription'

extension microsoftGraphV1

// 🔗 Standalone federated credential resource with full path name
resource federatedCredential 'Microsoft.Graph/applications/federatedIdentityCredentials@v1.0' = {
  name: '${appId}/github-oidc'
  audiences: [
    'api://AzureADTokenExchange'
  ]
  issuer: 'https://token.actions.githubusercontent.com'
  subject: 'repo:${githubRepo}:ref:${githubRef}'
  description: 'GitHub Actions OIDC federated credential'
}

@description('GitHub repo in formaat org/repo')
param githubRepo string = 'CXNSMB/onboarding'

@description('GitHub ref, bv. refs/heads/main')
param githubRef string = 'refs/heads/main'

@description('App ID')
param appreg string = '36a54633-6448-4d07-a178-f9f8dd3e5b65'

targetScope = 'subscription'
extension microsoftGraphV1

    resource childSymbolicname 'Microsoft.Graph/applications/federatedIdentityCredentials@v1.0' = {
    audiences: [
      'api://AzureADTokenExchange'
    ]
    issuer: 'https://token.actions.githubusercontent.com'
    subject: 'repo:${githubRepo}:ref:${githubRef}'
    description: 'GitHub Actions OIDC federated credential'
    name: '${appreg}/github-oidc'
    
  }

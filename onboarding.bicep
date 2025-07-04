@description('Naam van de App Registration')
param appName string = 'CXNSMB-github-lighthouse'

@description('GitHub organization name')
param githubOrg string = 'CXNSMB'

@description('GitHub repository name')
param githubRepo string = 'onboarding'

@description('GitHub branch or environment (e.g. main, develop, or environment name)')
param githubRef string = 'main'

targetScope = 'subscription'

extension microsoftGraphV1

var roleDefinitionId string = '18d7d88d-d35e-4fb5-a5c3-7773c20a72d9'



// 📌 App registratie
resource appReg 'Microsoft.Graph/applications@v1.0' = {
  displayName:appName
  uniqueName:'${appName}-${uniqueString(subscription().subscriptionId)}'
  notes: 'This apps keeps tehXNSMB lighthouse up to date'
  api:{
    requestedAccessTokenVersion:2
  }
}
output appregid string = appReg.appId


// 🔄 Service principal aanmaken
resource sp 'Microsoft.Graph/servicePrincipals@v1.0' = {
  appId:appReg.appId
}

// 🔐 Federated credential voor GitHub Actions OIDC
resource federatedCredential 'Microsoft.Graph/applications/federatedIdentityCredentials@v1.0' = {
  name: '${appReg.uniqueName}/github-actions-${githubRepo}-${githubRef}'
  description: 'Federated credential for GitHub Actions OIDC from ${githubOrg}/${githubRepo} on ${githubRef}'
  audiences: ['api://AzureADTokenExchange']
  issuer: 'https://token.actions.githubusercontent.com'
  subject: 'repo:${githubOrg}/${githubRepo}:ref:refs/heads/${githubRef}'
}

// 🔓 RBAC role assignment op de subscription
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(subscription().subscriptionId, appName, roleDefinitionId)
  properties: {
    principalId: sp.id
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
    description: 'GitHub Actions service principal - cannot assign/delete Owner, User Access Admin and RBAC Admin roles'
    condition: '((!(ActionMatches{\'Microsoft.Authorization/roleAssignments/write\'})) OR (@Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAllValues:GuidNotEquals {8e3af657-a8ff-443c-a75c-2fe8c4bcb635, 18d7d88d-d35e-4fb5-a5c3-7773c20a72d9, f58310d9-a9f6-439a-9e8d-f62e7b41a168})) AND ((!(ActionMatches{\'Microsoft.Authorization/roleAssignments/delete\'})) OR (@Resource[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAllValues:GuidNotEquals {8e3af657-a8ff-443c-a75c-2fe8c4bcb635, 18d7d88d-d35e-4fb5-a5c3-7773c20a72d9, f58310d9-a9f6-439a-9e8d-f62e7b41a168}))'
    conditionVersion: '2.0'
  }
}



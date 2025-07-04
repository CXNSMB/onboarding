targetScope = 'resourceGroup'

@description('Name for the App Registration and Service Principal')
param appName string = 'CXNSMB-github-lh'

@description('GitHub repository in format owner/repo')
param githubRepo string = 'CXNSMB/onboarding'

@description('GitHub reference (branch/tag/environment)')
param githubRef string = 'refs/heads/main'

@description('Location for resources')
param location string = resourceGroup().location

// Role definitions
var userAccessAdministratorRoleId = '18d7d88d-d35e-4fb5-a5c3-7773c20a72d9'

// ❌ Forbidden roles that this app should NOT be able to assign
var forbiddenRoles = [
  '8e3af657-a8ff-443c-a75c-2fe8c4bcb635' // Owner
  '18d7d88d-d35e-4fb5-a5c3-7773c20a72d9' // User Access Administrator  
  'f58310d9-a9f6-439a-9e8d-f62e7b41a168' // RBAC Administrator
]

// Create managed identity for the GitHub Actions
resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedManagedIdentities@2022-01-31-preview' = {
  name: 'mi-${appName}'
  location: location
  tags: {
    purpose: 'GitHub Actions authentication'
    project: 'CXNSMB-onboarding'
  }
}

// Note: Role assignment at subscription scope needs to be deployed at subscription level
// This will be handled by the deployment script

// Output all the information needed for GitHub Actions setup
output subscriptionId string = subscription().subscriptionId
output tenantId string = subscription().tenantId
output resourceGroupName string = resourceGroup().name
output managedIdentityClientId string = managedIdentity.properties.clientId
output managedIdentityPrincipalId string = managedIdentity.properties.principalId
output managedIdentityName string = managedIdentity.name

// 🔗 Output the exact Azure CLI command to create the federated credential
output federatedCredentialCommand string = 'az ad app federated-credential create --id ${managedIdentity.properties.clientId} --parameters "{\\"name\\": \\"github-oidc\\", \\"issuer\\": \\"https://token.actions.githubusercontent.com\\", \\"subject\\": \\"repo:${githubRepo}:ref:${githubRef}\\", \\"description\\": \\"GitHub Actions OIDC federated credential\\", \\"audiences\\": [\\"api://AzureADTokenExchange\\"]}"'

// 🔗 Output the exact Azure CLI command to create the role assignment with security conditions
output roleAssignmentCommand string = 'az role assignment create --assignee ${managedIdentity.properties.principalId} --role ${userAccessAdministratorRoleId} --scope "/subscriptions/${subscription().subscriptionId}" --condition "(!(ActionMatches{\\"Microsoft.Authorization/roleAssignments/write\\"})) OR (ActionMatches{\\"Microsoft.Authorization/roleAssignments/write\\"} AND NOT (Resource[Microsoft.Authorization/roleAssignments:RoleDefinitionId] StringEquals \\"8e3af657-a8ff-443c-a75c-2fe8c4bcb635\\" OR Resource[Microsoft.Authorization/roleAssignments:RoleDefinitionId] StringEquals \\"18d7d88d-d35e-4fb5-a5c3-7773c20a72d9\\" OR Resource[Microsoft.Authorization/roleAssignments:RoleDefinitionId] StringEquals \\"f58310d9-a9f6-439a-9e8d-f62e7b41a168\\"))" --condition-version "2.0"'

// 📝 Output GitHub Actions secrets configuration
output githubSecretsInfo object = {
  AZURE_CLIENT_ID: managedIdentity.properties.clientId
  AZURE_TENANT_ID: subscription().tenantId
  AZURE_SUBSCRIPTION_ID: subscription().subscriptionId
}

// ⚠️ Security information
output securityInfo object = {
  message: 'This managed identity has User Access Administrator permissions with security restrictions'
  forbiddenRoles: forbiddenRoles
  allowedRoles: [
    {
      name: 'Contributor'
      id: 'b24988ac-6180-42a0-ab88-20f7382dd24c'
      description: 'Can manage resources but not access or role assignments'
    }
    {
      name: 'Reader'
      id: 'acdd72a7-3385-48ef-bd42-f606fba81ae7'
      description: 'Can view resources but not modify them'
    }
    {
      name: 'Storage Account Contributor'
      id: '17d1049b-9a84-46fb-8f53-869881c3d3ab'
      description: 'Can manage storage accounts'
    }
  ]
}

// 🎯 Output example deployment command
output exampleDeploymentCommand string = 'az deployment sub create --location "${location}" --template-file "complete-setup.bicep" --parameters appName="${appName}" githubRepo="${githubRepo}" githubRef="${githubRef}"'

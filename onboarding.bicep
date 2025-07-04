@description('Naam van de App Registration')
param appName string = 'CXNSMB-github-lh'

@description('RBAC rol om toe te wijzen aan de federated identity')
param roleDefinitionId string = '18d7d88d-d35e-4fb5-a5c3-7773c20a72d9'

targetScope = 'subscription'

extension microsoftGraphV1

// // ❌ Verboden rollen
// var forbiddenRoles = [
//   '8e3af657-a8ff-443c-a75c-2fe8c4bcb635' // Owner
//   '18d7d88d-d35e-4fb5-a5c3-7773c20a72d9' // User Access Administrator
//   'f58310d9-a9f6-439a-9e8d-f62e7b41a168' // RBAC Admin (optioneel)
// ]
// extension microsoftGraphV1

// //@assert(!contains(forbiddenRoles, roleDefinitionId), 'Deze rol mag niet toegekend worden. Kies een minder machtige rol zoals Contributor of Reader.')
// param roleValidation bool = true



// 📌 App registratie
resource appReg 'Microsoft.Graph/applications@v1.0' = {
  displayName:appName
  uniqueName:appName
  notes: 'This apps keeps teh CXNSMB lighthouse up to date'
  api:{
    requestedAccessTokenVersion:2
  }
}
output appregid string = appReg.appId


// 🔄 Service principal aanmaken
resource sp 'Microsoft.Graph/servicePrincipals@v1.0' = {
  appId:appReg.appId
}

// 🔓 RBAC role assignment op de subscription met security conditions
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(subscription().subscriptionId, appName, roleDefinitionId)
  properties: {
    principalId: sp.id
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
    description: 'GitHub Actions service principal with restricted role assignment permissions'
    
    // 🔒 Security condition: Prevent assignment of forbidden roles
    condition: '''(
      (
        !(ActionMatches{"Microsoft.Authorization/roleAssignments/write"})
      )
      OR
      (
        ActionMatches{"Microsoft.Authorization/roleAssignments/write"}
        AND
        NOT (
          Resource[Microsoft.Authorization/roleAssignments:RoleDefinitionId] StringEquals "8e3af657-a8ff-443c-a75c-2fe8c4bcb635"
          OR
          Resource[Microsoft.Authorization/roleAssignments:RoleDefinitionId] StringEquals "18d7d88d-d35e-4fb5-a5c3-7773c20a72d9"
          OR
          Resource[Microsoft.Authorization/roleAssignments:RoleDefinitionId] StringEquals "f58310d9-a9f6-439a-9e8d-f62e7b41a168"
        )
      )
    )'''
    conditionVersion: '2.0'
  }
}

// 📝 Outputs voor GitHub Actions setup
output subscriptionId string = subscription().subscriptionId
output tenantId string = subscription().tenantId
output servicePrincipalId string = sp.id
output appRegistrationId string = appReg.appId

// 🔗 Command om federated credential aan te maken
output createFederatedCredentialCommand string = 'az ad app federated-credential create --id ${appReg.appId} --parameters "{\\"name\\": \\"github-oidc\\", \\"issuer\\": \\"https://token.actions.githubusercontent.com\\", \\"subject\\": \\"repo:CXNSMB/onboarding:ref:refs/heads/main\\", \\"description\\": \\"GitHub Actions OIDC federated credential\\", \\"audiences\\": [\\"api://AzureADTokenExchange\\"]}"'

// 📋 GitHub Actions secrets
output githubSecrets object = {
  AZURE_CLIENT_ID: appReg.appId
  AZURE_TENANT_ID: subscription().tenantId
  AZURE_SUBSCRIPTION_ID: subscription().subscriptionId
}

// ⚠️ Security informatie
output securityInfo object = {
  message: 'This service principal has User Access Administrator with security restrictions'
  forbiddenRoles: [
    '8e3af657-a8ff-443c-a75c-2fe8c4bcb635' // Owner
    '18d7d88d-d35e-4fb5-a5c3-7773c20a72d9' // User Access Administrator
    'f58310d9-a9f6-439a-9e8d-f62e7b41a168' // RBAC Administrator
  ]
  allowedRoles: [
    'b24988ac-6180-42a0-ab88-20f7382dd24c' // Contributor
    'acdd72a7-3385-48ef-bd42-f606fba81ae7' // Reader
    '17d1049b-9a84-46fb-8f53-869881c3d3ab' // Storage Account Contributor
  ]
}

@description('Service Principal Object ID (from the CLI setup script)')
param servicePrincipalObjectId string

@description('Name for the role assignment (for identification)')
param roleAssignmentName string = 'GitHub-Actions-RBAC'

targetScope = 'subscription'

var roleDefinitionId string = '18d7d88d-d35e-4fb5-a5c3-7773c20a72d9' // User Access Administrator

// 🔓 RBAC role assignment op de subscription
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(subscription().subscriptionId, servicePrincipalObjectId, roleDefinitionId)
  properties: {
    principalId: servicePrincipalObjectId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
    description: 'GitHub Actions service principal - cannot assign/delete Owner, User Access Admin and RBAC Admin roles'
    condition: '((!(ActionMatches{\'Microsoft.Authorization/roleAssignments/write\'})) OR (@Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAllValues:GuidNotEquals {8e3af657-a8ff-443c-a75c-2fe8c4bcb635, 18d7d88d-d35e-4fb5-a5c3-7773c20a72d9, f58310d9-a9f6-439a-9e8d-f62e7b41a168})) AND ((!(ActionMatches{\'Microsoft.Authorization/roleAssignments/delete\'})) OR (@Resource[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAllValues:GuidNotEquals {8e3af657-a8ff-443c-a75c-2fe8c4bcb635, 18d7d88d-d35e-4fb5-a5c3-7773c20a72d9, f58310d9-a9f6-439a-9e8d-f62e7b41a168}))'
    conditionVersion: '2.0'
  }
}

output roleAssignmentId string = roleAssignment.id
output roleAssignmentName string = roleAssignment.name

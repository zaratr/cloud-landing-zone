// Custom RBAC definitions and assignments without owner permissions
@description('Base name prefix for resources')
param namePrefix string

@description('Platform Admin principal object ID')
param platformAdminObjectId string

@description('Application Operator principal object ID')
param appOperatorObjectId string

@description('Auditor principal object ID')
param auditorObjectId string

@description('Scope for assignments (subscription or management group)')
param rgScope string

var platformAdminRoleName = '${namePrefix}-platform-admin'
var appOperatorRoleName = '${namePrefix}-app-operator'
var auditorRoleName = '${namePrefix}-auditor'

resource platformAdminDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: guid(rgScope, platformAdminRoleName)
  scope: subscription()
  properties: {
    roleName: platformAdminRoleName
    description: 'Platform administrator with elevated management permissions excluding role assignments/ownership.'
    assignableScopes: [ rgScope ]
    permissions: [
      {
        actions: [
          '*/read',
          'Microsoft.Authorization/locks/*',
          'Microsoft.Support/*',
          'Microsoft.Resources/deployments/*',
          'Microsoft.Network/*',
          'Microsoft.KeyVault/*',
          'Microsoft.OperationalInsights/*'
        ]
        notActions: [
          'Microsoft.Authorization/roleAssignments/*',
          'Microsoft.Authorization/roleDefinitions/*'
        ]
      }
    ]
  }
}

resource appOperatorDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: guid(rgScope, appOperatorRoleName)
  scope: subscription()
  properties: {
    roleName: appOperatorRoleName
    description: 'Application operator for deploying and managing workloads without broad IAM privileges.'
    assignableScopes: [ rgScope ]
    permissions: [
      {
        actions: [
          'Microsoft.Resources/subscriptions/resourceGroups/read',
          'Microsoft.Resources/deployments/*',
          'Microsoft.Compute/*',
          'Microsoft.Network/virtualNetworks/subnets/*',
          'Microsoft.Network/networkInterfaces/*',
          'Microsoft.KeyVault/vaults/*',
          'Microsoft.ContainerService/*'
        ]
        notActions: [
          'Microsoft.Authorization/*',
          'Microsoft.Network/publicIPAddresses/*'
        ]
      }
    ]
  }
}

resource auditorDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: guid(rgScope, auditorRoleName)
  scope: subscription()
  properties: {
    roleName: auditorRoleName
    description: 'Read-only auditor role for compliance and inspection.'
    assignableScopes: [ rgScope ]
    permissions: [
      {
        actions: [ '*/read' ]
        notActions: []
      }
    ]
  }
}

resource platformAdminAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(platformAdminObjectId, platformAdminDefinition.name, rgScope)
  scope: subscription()
  properties: {
    principalId: platformAdminObjectId
    roleDefinitionId: platformAdminDefinition.id
    principalType: 'ServicePrincipal'
  }
}

resource appOperatorAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(appOperatorObjectId, appOperatorDefinition.name, rgScope)
  scope: subscription()
  properties: {
    principalId: appOperatorObjectId
    roleDefinitionId: appOperatorDefinition.id
    principalType: 'ServicePrincipal'
  }
}

resource auditorAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(auditorObjectId, auditorDefinition.name, rgScope)
  scope: subscription()
  properties: {
    principalId: auditorObjectId
    roleDefinitionId: auditorDefinition.id
    principalType: 'ServicePrincipal'
  }
}

// Azure Landing Zone - subscription level orchestrator
// Target scope is subscription to create resource groups and deploy modular components.
targetScope = 'subscription'

@description('Organization or business unit prefix for naming (e.g., contoso)')
param orgPrefix string

@description('Environment designator (e.g., prod, staging)')
param environment string

@description('Primary Azure region for deployment')
param location string = 'eastus2'

@description('Allowed Azure regions for governance policy')
param allowedRegions array = [
  'eastus2'
  'centralus'
  'westus3'
]

@description('Object ID for Platform Admin role assignment (AAD principal)')
param platformAdminObjectId string

@description('Object ID for Application Operator role assignment (AAD principal)')
param appOperatorObjectId string

@description('Object ID for Auditor role assignment (AAD principal)')
param auditorObjectId string

@description('Optional tags to apply to all resources')
param globalTags object = {
  owner: 'platform-team'
  environment: environment
  costCenter: '0000'
}

var baseName = toLower('${orgPrefix}-${environment}')
var rgNetworkingName = '${baseName}-net-rg'
var rgIdentityName = '${baseName}-id-rg'
var rgSharedName = '${baseName}-shared-rg'
var rgWorkloadsName = '${baseName}-apps-rg'

resource rgNetworking 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: rgNetworkingName
  location: location
  tags: globalTags
}

resource rgIdentity 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: rgIdentityName
  location: location
  tags: globalTags
}

resource rgShared 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: rgSharedName
  location: location
  tags: globalTags
}

resource rgWorkloads 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: rgWorkloadsName
  location: location
  tags: globalTags
}

module logging 'modules/logging/main.bicep' = {
  name: 'logging'
  scope: resourceGroup(rgShared.name)
  params: {
    namePrefix: baseName
    location: location
    tags: globalTags
  }
}

module identity 'modules/identity/main.bicep' = {
  name: 'identity'
  params: {
    namePrefix: baseName
    platformAdminObjectId: platformAdminObjectId
    appOperatorObjectId: appOperatorObjectId
    auditorObjectId: auditorObjectId
    rgScope: subscription().id
  }
}

module networking 'modules/networking/main.bicep' = {
  name: 'networking'
  scope: resourceGroup(rgNetworking.name)
  params: {
    namePrefix: baseName
    location: location
    tags: globalTags
    workspaceResourceId: logging.outputs.workspaceResourceId
  }
}

module security 'modules/security/main.bicep' = {
  name: 'security'
  scope: resourceGroup(rgShared.name)
  params: {
    namePrefix: baseName
    location: location
    tags: globalTags
    workspaceResourceId: logging.outputs.workspaceResourceId
  }
}

module policy 'modules/policy/main.bicep' = {
  name: 'policy'
  params: {
    namePrefix: baseName
    allowedRegions: allowedRegions
    tags: globalTags
    activityLogWorkspaceResourceId: logging.outputs.workspaceResourceId
  }
}

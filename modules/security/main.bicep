// Security baseline resources (Key Vault hardened configuration)
@description('Base name prefix for resources')
param namePrefix string

@description('Deployment region')
param location string

@description('Tags to apply')
param tags object

@description('Log Analytics workspace resource ID')
param workspaceResourceId string

@description('Whether to enable a private endpoint for Key Vault')
param enableKeyVaultPrivateEndpoint bool = false

@description('Subnet resource ID for private endpoints (required when enableKeyVaultPrivateEndpoint is true)')
param privateEndpointSubnetId string = ''

var keyVaultName = toLower('${namePrefix}-kvl')

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    enableSoftDelete: true
    enablePurgeProtection: true
    publicNetworkAccess: 'Disabled'
    sku: {
      family: 'A'
      name: 'standard'
    }
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
    }
  }
}

resource keyVaultDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${keyVaultName}-diag'
  scope: keyVault
  properties: {
    workspaceId: workspaceResourceId
    logs: [
      {
        category: 'AuditEvent'
        enabled: true
      }
    ]
  }
}

// Optional private endpoint for Key Vault when required
resource keyVaultPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-11-01' = if (enableKeyVaultPrivateEndpoint) {
  name: '${namePrefix}-kvl-pe'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'keyVaultPrivateLink'
        properties: {
          privateLinkServiceId: keyVault.id
          groupIds: [ 'vault' ]
        }
      }
    ]
  }
}

output keyVaultId string = keyVault.id

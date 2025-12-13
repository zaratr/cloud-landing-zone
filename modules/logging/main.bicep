// Centralized logging and monitoring baseline
@description('Base name prefix for resources')
param namePrefix string

@description('Deployment region')
param location string

@description('Tags to apply')
param tags object

@description('Retention in days for Log Analytics')
param logRetentionInDays int = 30

var workspaceName = '${namePrefix}-law'

resource workspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: workspaceName
  location: location
  tags: tags
  properties: {
    retentionInDays: logRetentionInDays
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
  sku: {
    name: 'PerGB2018'
  }
}

output workspaceId string = workspace.id
output workspaceResourceId string = workspace.id

// Governance policies and diagnostic enforcement
@description('Base name prefix for policy naming')
param namePrefix string

@description('Allowed Azure regions for deployment')
param allowedRegions array

@description('Baseline tags required on resources')
param tags object

@description('Log Analytics workspace resource ID for activity logs')
param activityLogWorkspaceResourceId string

var tagPolicyName = '${namePrefix}-require-tags'
var denyPublicIpPolicyName = '${namePrefix}-deny-public-ip'
var allowedRegionsPolicyName = '${namePrefix}-allowed-regions'

resource requireTagsDefinition 'Microsoft.Authorization/policyDefinitions@2021-06-01' = {
  name: tagPolicyName
  properties: {
    policyType: 'Custom'
    mode: 'All'
    displayName: 'Require standard tags'
    description: 'Deny resources without required business tags.'
    parameters: {}
    policyRule: {
      if: {
        anyOf: [
          {
            field: 'tags.owner'
            equals: ''
          }
          {
            field: 'tags.environment'
            equals: ''
          }
          {
            field: 'tags.costCenter'
            equals: ''
          }
        ]
      }
      then: {
        effect: 'deny'
      }
    }
  }
}

resource denyPublicIpDefinition 'Microsoft.Authorization/policyDefinitions@2021-06-01' = {
  name: denyPublicIpPolicyName
  properties: {
    policyType: 'Custom'
    mode: 'Indexed'
    displayName: 'Deny public IP creation'
    description: 'Prevent creation of public IP addresses for workloads.'
    policyRule: {
      if: {
        field: 'type'
        equals: 'Microsoft.Network/publicIPAddresses'
      }
      then: {
        effect: 'deny'
      }
    }
  }
}

resource allowedRegionsDefinition 'Microsoft.Authorization/policyDefinitions@2021-06-01' = {
  name: allowedRegionsPolicyName
  properties: {
    policyType: 'Custom'
    mode: 'All'
    displayName: 'Allowed regions for resources'
    description: 'Permit deployments only to approved Azure regions.'
    parameters: {
      listOfAllowedLocations: {
        type: 'Array'
        defaultValue: allowedRegions
        metadata: {
          description: 'Approved Azure regions'
        }
      }
    }
    policyRule: {
      if: {
        field: 'location'
        notIn: '[parameters(''listOfAllowedLocations'')]'
      }
      then: {
        effect: 'deny'
      }
    }
  }
}

resource requireTagsAssignment 'Microsoft.Authorization/policyAssignments@2021-06-01' = {
  name: '${namePrefix}-tags-assignment'
  scope: subscription()
  properties: {
    displayName: 'Enforce standard tags'
    policyDefinitionId: requireTagsDefinition.id
    nonComplianceMessages: [
      {
        message: 'All resources must include owner, environment, and costCenter tags.'
      }
    ]
  }
}

resource denyPublicIpAssignment 'Microsoft.Authorization/policyAssignments@2021-06-01' = {
  name: '${namePrefix}-deny-public-ip-assignment'
  scope: subscription()
  properties: {
    displayName: 'Deny public IPs'
    policyDefinitionId: denyPublicIpDefinition.id
  }
}

resource allowedRegionsAssignment 'Microsoft.Authorization/policyAssignments@2021-06-01' = {
  name: '${namePrefix}-allowed-regions-assignment'
  scope: subscription()
  properties: {
    displayName: 'Restrict locations'
    policyDefinitionId: allowedRegionsDefinition.id
    parameters: {
      listOfAllowedLocations: {
        value: allowedRegions
      }
    }
  }
}

resource activityLogDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${namePrefix}-activitylogs-diag'
  scope: subscription()
  properties: {
    workspaceId: activityLogWorkspaceResourceId
    logs: [
      {
        category: 'Administrative'
        enabled: true
      }
      {
        category: 'Policy'
        enabled: true
      }
      {
        category: 'Security'
        enabled: true
      }
      {
        category: 'ServiceHealth'
        enabled: true
      }
      {
        category: 'Alert'
        enabled: true
      }
      {
        category: 'Recommendation'
        enabled: true
      }
      {
        category: 'ResourceHealth'
        enabled: true
      }
    ]
  }
}

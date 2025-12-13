// Networking baseline with hub-style VNet, segmented subnets, and NSG protections
@description('Base name prefix for resources')
param namePrefix string

@description('Deployment region')
param location string

@description('Tags to apply')
param tags object

@description('Existing Log Analytics workspace resource ID for diagnostics')
param workspaceResourceId string

@description('Address space for the virtual network')
param addressSpace array = [
  '10.20.0.0/16'
]

@description('CIDR for public subnet (ingress controlled)')
param publicSubnetCidr string = '10.20.0.0/24'

@description('CIDR for private workload subnet')
param privateSubnetCidr string = '10.20.1.0/24'

@description('CIDR for private endpoint subnet')
param privateEndpointSubnetCidr string = '10.20.2.0/27'

var vnetName = '${namePrefix}-hub-vnet'
var publicSubnetName = '${namePrefix}-public-snet'
var privateSubnetName = '${namePrefix}-private-snet'
var privateEndpointSubnetName = '${namePrefix}-pe-snet'
var publicNsgName = '${namePrefix}-public-nsg'
var privateNsgName = '${namePrefix}-private-nsg'

resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: addressSpace
    }
    subnets: [
      {
        name: publicSubnetName
        properties: {
          addressPrefix: publicSubnetCidr
          networkSecurityGroup: {
            id: publicNsg.id
          }
        }
      }
      {
        name: privateSubnetName
        properties: {
          addressPrefix: privateSubnetCidr
          networkSecurityGroup: {
            id: privateNsg.id
          }
        }
      }
      {
        name: privateEndpointSubnetName
        properties: {
          addressPrefix: privateEndpointSubnetCidr
          privateEndpointNetworkPolicies: 'Disabled'
          networkSecurityGroup: {
            id: privateNsg.id
          }
        }
      }
    ]
  }
}

resource publicNsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: publicNsgName
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowAzureLoadBalancerHealthProbe'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'AzureLoadBalancer'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'AllowOutboundInternet'
        properties: {
          priority: 300
          direction: 'Outbound'
          access: 'Allow'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'Internet'
        }
      }
    ]
  }
}

resource privateNsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: privateNsgName
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'DenyInboundDefault'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'AllowPrivateEastWest'
        properties: {
          priority: 200
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
        }
      }
      {
        name: 'DenyInternetEgress'
        properties: {
          priority: 300
          direction: 'Outbound'
          access: 'Deny'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'Internet'
        }
      }
    ]
  }
}

resource publicNsgDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${publicNsgName}-diag'
  scope: publicNsg
  properties: {
    workspaceId: workspaceResourceId
    logs: [
      {
        category: 'NetworkSecurityGroupEvent'
        enabled: true
      }
      {
        category: 'NetworkSecurityGroupRuleCounter'
        enabled: true
      }
    ]
  }
}

resource privateNsgDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${privateNsgName}-diag'
  scope: privateNsg
  properties: {
    workspaceId: workspaceResourceId
    logs: [
      {
        category: 'NetworkSecurityGroupEvent'
        enabled: true
      }
      {
        category: 'NetworkSecurityGroupRuleCounter'
        enabled: true
      }
    ]
  }
}

output vnetId string = vnet.id
output publicSubnetId string = vnet.properties.subnets[0].id
output privateSubnetId string = vnet.properties.subnets[1].id
output privateEndpointSubnetId string = vnet.properties.subnets[2].id

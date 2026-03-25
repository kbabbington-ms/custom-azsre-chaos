// =============================================================================
// Virtual Network Module
// =============================================================================
// Creates a VNet with subnets for AKS and other services. Network configuration
// is important for SRE Agent - ensure the cluster is not completely isolated
// from inbound traffic to allow SRE Agent access.
// =============================================================================

@description('Name of the virtual network')
param vnetName string

@description('Azure region for deployment')
param location string

@description('Tags to apply to resources')
param tags object

@description('Address prefix for the VNet')
param addressPrefix string = '10.0.0.0/16'

@description('Address prefix for the AKS subnet')
param aksSubnetPrefix string = '10.0.0.0/22'

@description('Address prefix for services subnet (private endpoints)')
param servicesSubnetPrefix string = '10.0.4.0/24'

// =============================================================================
// RESOURCES
// =============================================================================

// NSG for AKS subnet - required by Azure Policy
// Allows HTTP inbound for Kubernetes LoadBalancer services (store-front, store-admin)
resource aksNsg 'Microsoft.Network/networkSecurityGroups@2024-01-01' = {
  name: '${vnetName}-snet-aks-nsg'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowHTTPInbound'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '80'
        }
      }
    ]
  }
}

// NSG for services subnet - required by Azure Policy
resource servicesNsg 'Microsoft.Network/networkSecurityGroups@2024-01-01' = {
  name: '${vnetName}-snet-services-nsg'
  location: location
  tags: tags
  properties: {
    securityRules: []
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2024-01-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
    subnets: [
      {
        name: 'snet-aks'
        properties: {
          addressPrefix: aksSubnetPrefix
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
          networkSecurityGroup: {
            id: aksNsg.id
          }
        }
      }
      {
        name: 'snet-services'
        properties: {
          addressPrefix: servicesSubnetPrefix
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
          networkSecurityGroup: {
            id: servicesNsg.id
          }
        }
      }
    ]
  }
}

// =============================================================================
// OUTPUTS
// =============================================================================

output vnetId string = vnet.id
output vnetName string = vnet.name
output aksSubnetId string = vnet.properties.subnets[0].id
output servicesSubnetId string = vnet.properties.subnets[1].id

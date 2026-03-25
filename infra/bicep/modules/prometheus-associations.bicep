// =============================================================================
// Prometheus DCE/DCR Associations Module
// =============================================================================
// Deploys data collection endpoint and rule associations on the AKS cluster.
// Separated from observability.bicep to handle cross-RG scoping — AKS lives
// in the infra RG while the DCE/DCR resources are in the monitor RG.
// =============================================================================

@description('Name of the AKS cluster')
param aksClusterName string

@description('Data collection endpoint resource ID (in monitor RG)')
param dataCollectionEndpointId string

@description('Data collection rule resource ID (in monitor RG)')
param dataCollectionRuleId string

@description('Prometheus workspace name (used for DCR association naming)')
param prometheusName string

// Reference the existing AKS cluster (deployed in same RG as this module)
resource aksCluster 'Microsoft.ContainerService/managedClusters@2024-02-01' existing = {
  name: aksClusterName
}

// DCE association - must be named 'configurationAccessEndpoint' per Azure requirements
resource aksPrometheusDceAssociation 'Microsoft.Insights/dataCollectionRuleAssociations@2022-06-01' = {
  name: 'configurationAccessEndpoint'
  scope: aksCluster
  properties: {
    description: 'Data collection endpoint association for Prometheus metrics'
    dataCollectionEndpointId: dataCollectionEndpointId
  }
}

// DCR association
resource aksPrometheusDcrAssociation 'Microsoft.Insights/dataCollectionRuleAssociations@2022-06-01' = {
  name: '${prometheusName}-dcr-association'
  scope: aksCluster
  properties: {
    description: 'Data collection rule association for Prometheus metrics'
    dataCollectionRuleId: dataCollectionRuleId
  }
}

output dcrAssociationId string = aksPrometheusDcrAssociation.id

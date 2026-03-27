// =============================================================================
// Azure SRE Agent Demo Lab - Main Bicep Template
// =============================================================================
// This template deploys an AKS cluster with a multi-pod sample application,
// along with supporting infrastructure for demonstrating Azure SRE Agent
// capabilities for diagnostics and troubleshooting.
// =============================================================================

targetScope = 'subscription'

// =============================================================================
// PARAMETERS
// =============================================================================

@description('Name of the workload (used for naming resources)')
@minLength(3)
@maxLength(10)
param workloadName string = 'srelab'

@description('Azure region for infrastructure deployment')
@allowed([
  'centralus'
  'eastus2'
  'swedencentral'
  'australiaeast'
])
param location string = 'centralus'

@description('Azure region for SRE Agent resource (must be a supported region: eastus2, swedencentral, australiaeast)')
@allowed([
  'eastus2'
  'swedencentral'
  'australiaeast'
])
param sreAgentLocation string = 'eastus2'

@description('Name of the resource group for infrastructure and chaos resources')
param infraResourceGroupName string

@description('Name of the resource group for monitoring resources')
param monitorResourceGroupName string

@description('Name of the resource group for SRE Agent resources')
param sreResourceGroupName string

@description('Optional custom name for the AKS node resource group (MC_ group). Leave empty for Azure default naming.')
param nodeResourceGroupName string = ''

@description('Deploy full observability stack (Managed Grafana, Prometheus)')
param deployObservability bool = true

@description('Deploy baseline Azure Monitor alert rules for AKS and app telemetry')
param deployAlerts bool = false

@description('Deploy Azure SRE Agent for AI-powered diagnostics and remediation')
param deploySreAgent bool = true

@description('Deploy Azure Chaos Studio experiments for automated fault injection')
param deployChaosStudio bool = true

@description('Deploy default Action Group for alert notifications and incident routing')
param deployActionGroup bool = false

@description('Action Group short name (max 12 characters)')
@maxLength(12)
param actionGroupShortName string = 'srelabops'

@description('Email recipients for action group notifications')
param actionGroupEmailReceivers array = []

@description('SMS recipients for action group notifications')
param actionGroupSmsReceivers array = []

@secure()
@description('Optional webhook/Logic App callback URL for default Action Group incident routing')
param incidentWebhookServiceUri string = ''

@description('Optional action group resource IDs to notify when alerts fire')
param alertActionGroupIds array = []

@description('AKS Kubernetes version')
param kubernetesVersion string = '1.32'

@description('AKS system node pool VM size')
@allowed([
  'Standard_D2s_v5'
  'Standard_D4s_v5'
  'Standard_D2as_v5'
  'Standard_D4as_v5'
  'Standard_D2s_v6'
  'Standard_D4s_v6'
])
param systemNodeVmSize string = 'Standard_D2s_v6'

@description('AKS user node pool VM size for workloads')
@allowed([
  'Standard_D2s_v5'
  'Standard_D4s_v5'
  'Standard_D2as_v5'
  'Standard_D4as_v5'
  'Standard_D2s_v6'
  'Standard_D4s_v6'
])
param userNodeVmSize string = 'Standard_D2s_v6'

@description('System node pool node count')
@minValue(1)
@maxValue(5)
param systemNodeCount int = 2

@description('User node pool node count')
@minValue(1)
@maxValue(10)
param userNodeCount int = 3

@description('Tags to apply to all resources')
param tags object = {
  LifecycleCheck: ''
  CreatedDate: '3/23/2026'
  RGMonthlyCost: '1000'
  Industry: 'All'
  DeploymentProgress: ''
  Owner: ''
  CreatedBy: ''
  Environment: 'Demo'
  Partner: 'NA'
  DeploymentStatus: ''
}

// =============================================================================
// VARIABLES
// =============================================================================

var uniqueSuffix = uniqueString(subscription().subscriptionId, infraResourceGroupName)

// Naming convention for resources
var names = {
  aks: 'aks-${workloadName}'
  acr: 'acr${workloadName}${take(uniqueSuffix, 6)}'
  logAnalytics: 'log-${workloadName}'
  appInsights: 'appi-${workloadName}'
  grafana: 'grafana-${workloadName}-${take(uniqueSuffix, 6)}'
  prometheus: 'prometheus-${workloadName}'
  keyVault: 'kv-${workloadName}-${take(uniqueSuffix, 6)}'
  managedIdentity: 'id-${workloadName}'
  vnet: 'vnet-${workloadName}'
  sreAgent: 'sre-${workloadName}'
  dashboard: 'dash-${workloadName}'
}

// =============================================================================
// RESOURCE GROUPS (created by the deployment)
// =============================================================================

resource infraRg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: infraResourceGroupName
  location: location
  tags: tags
}

resource monitorRg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: monitorResourceGroupName
  location: location
  tags: tags
}

resource sreRg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: sreResourceGroupName
  location: location
  tags: tags
}

// =============================================================================
// MODULES
// =============================================================================

// Log Analytics Workspace (required for AKS monitoring and SRE Agent)
module logAnalytics 'modules/log-analytics.bicep' = {
  scope: monitorRg
  name: 'deploy-log-analytics'
  params: {
    name: names.logAnalytics
    location: location
    tags: tags
    retentionInDays: 30
  }
}

// Application Insights (for application-level telemetry)
module appInsights 'modules/app-insights.bicep' = {
  scope: monitorRg
  name: 'deploy-app-insights'
  params: {
    name: names.appInsights
    location: location
    tags: tags
    workspaceId: logAnalytics.outputs.workspaceId
  }
}

// Virtual Network for AKS
module network 'modules/network.bicep' = {
  scope: infraRg
  name: 'deploy-network'
  params: {
    vnetName: names.vnet
    location: location
    tags: tags
    addressPrefix: '10.0.0.0/16'
    aksSubnetPrefix: '10.0.0.0/22'
    servicesSubnetPrefix: '10.0.4.0/24'
  }
}

// Azure Container Registry
module containerRegistry 'modules/container-registry.bicep' = {
  scope: infraRg
  name: 'deploy-acr'
  params: {
    name: names.acr
    location: location
    tags: tags
    sku: 'Basic'
  }
}

// Azure Kubernetes Service
module aks 'modules/aks.bicep' = {
  scope: infraRg
  name: 'deploy-aks'
  params: {
    name: names.aks
    location: location
    tags: tags
    kubernetesVersion: kubernetesVersion
    systemNodeVmSize: systemNodeVmSize
    userNodeVmSize: userNodeVmSize
    systemNodeCount: systemNodeCount
    userNodeCount: userNodeCount
    vnetSubnetId: network.outputs.aksSubnetId
    logAnalyticsWorkspaceId: logAnalytics.outputs.workspaceId
    acrId: containerRegistry.outputs.acrId
    nodeResourceGroupName: nodeResourceGroupName
  }
}

// Key Vault for secrets management
module keyVault 'modules/key-vault.bicep' = {
  scope: infraRg
  name: 'deploy-keyvault'
  params: {
    name: names.keyVault
    location: location
    tags: tags
    enableRbacAuthorization: true
  }
}

// Azure SRE Agent (optional) — deployed to SRE RG with its own supported region
module sreAgent 'modules/sre-agent.bicep' = if (deploySreAgent) {
  scope: sreRg
  name: 'deploy-sre-agent'
  params: {
    agentName: names.sreAgent
    location: sreAgentLocation
    tags: tags
    accessLevel: 'High'
    appInsightsAppId: appInsights.outputs.appId
    appInsightsConnectionString: appInsights.outputs.connectionString
    uniqueSuffix: uniqueSuffix
  }
}

// Observability Stack - Managed Grafana and Prometheus (optional)
module observability 'modules/observability.bicep' = if (deployObservability) {
  scope: monitorRg
  name: 'deploy-observability'
  params: {
    grafanaName: names.grafana
    prometheusName: names.prometheus
    location: location
    tags: tags
    aksClusterId: aks.outputs.aksId
    infraResourceGroupName: infraResourceGroupName
  }
}

// Prometheus DCE/DCR associations — must deploy to infra RG where AKS resides
module prometheusAssociations 'modules/prometheus-associations.bicep' = if (deployObservability) {
  scope: infraRg
  name: 'deploy-prometheus-associations'
  params: {
    aksClusterName: names.aks
    dataCollectionEndpointId: observability!.outputs.dataCollectionEndpointId
    dataCollectionRuleId: observability!.outputs.dataCollectionRuleId
    prometheusName: names.prometheus
  }
  dependsOn: [
    aks
    observability
  ]
}

// Operations Dashboard
module dashboard 'modules/dashboard.bicep' = {
  scope: monitorRg
  name: 'deploy-dashboard'
  params: {
    name: names.dashboard
    location: location
    tags: tags
    aksClusterId: aks.outputs.aksId
    logAnalyticsWorkspaceId: logAnalytics.outputs.workspaceId
    appInsightsId: appInsights.outputs.appInsightsId
    keyVaultId: keyVault.outputs.keyVaultId
    acrId: containerRegistry.outputs.acrId
    subscriptionId: subscription().subscriptionId
    resourceGroupName: infraResourceGroupName
    grafanaDashboardUrl: deployObservability ? observability!.outputs.grafanaEndpoint : ''
  }
}

// Chaos Studio - Automated fault injection experiments
module chaosStudio 'modules/chaos-studio.bicep' = if (deployChaosStudio) {
  scope: infraRg
  name: 'deploy-chaos-studio'
  params: {
    location: location
    tags: tags
    aksClusterName: names.aks
    namePrefix: 'chaos-${workloadName}'
  }
  dependsOn: [
    aks
  ]
}

module defaultActionGroup 'modules/action-group.bicep' = if (deployActionGroup) {
  scope: monitorRg
  name: 'deploy-default-action-group'
  params: {
    name: 'ag-${workloadName}'
    location: location
    tags: tags
    shortName: actionGroupShortName
    emailReceivers: actionGroupEmailReceivers
    smsReceivers: actionGroupSmsReceivers
    webhookServiceUri: incidentWebhookServiceUri
  }
}

var effectiveAlertActionGroupIds = deployActionGroup
  ? concat(alertActionGroupIds, [defaultActionGroup!.outputs.actionGroupId])
  : alertActionGroupIds

module alerts 'modules/alerts.bicep' = if (deployAlerts) {
  scope: monitorRg
  name: 'deploy-alerts'
  params: {
    namePrefix: 'alert-${workloadName}'
    location: location
    tags: tags
    logAnalyticsWorkspaceId: logAnalytics.outputs.workspaceId
    appNamespace: 'pets'
    actionGroupIds: effectiveAlertActionGroupIds
  }
}

// =============================================================================
// OUTPUTS
// =============================================================================

output infraResourceGroupName string = infraRg.name
output monitorResourceGroupName string = monitorRg.name
output sreResourceGroupName string = sreRg.name
output aksClusterName string = aks.outputs.aksName
output aksClusterFqdn string = aks.outputs.aksFqdn
output aksNodeResourceGroup string = aks.outputs.aksNodeResourceGroup
output acrLoginServer string = containerRegistry.outputs.loginServer
output logAnalyticsWorkspaceId string = logAnalytics.outputs.workspaceId
output appInsightsId string = appInsights.outputs.appInsightsId
output appInsightsConnectionString string = appInsights.outputs.connectionString
output keyVaultUri string = keyVault.outputs.vaultUri
output grafanaDashboardUrl string = deployObservability ? observability!.outputs.grafanaEndpoint : ''
output azureMonitorWorkspaceId string = deployObservability ? observability!.outputs.azureMonitorWorkspaceId : ''
output prometheusDataCollectionEndpointId string = deployObservability
  ? observability!.outputs.dataCollectionEndpointId
  : ''
output prometheusDataCollectionRuleId string = deployObservability ? observability!.outputs.dataCollectionRuleId : ''
output prometheusDcrAssociationId string = deployObservability
  ? prometheusAssociations!.outputs.dcrAssociationId
  : ''
output defaultActionGroupId string = deployActionGroup ? defaultActionGroup!.outputs.actionGroupId : ''
output defaultActionGroupHasWebhook bool = deployActionGroup ? defaultActionGroup!.outputs.hasWebhookReceiver : false
output podRestartAlertId string = deployAlerts ? alerts!.outputs.podRestartAlertId : ''
output http5xxAlertId string = deployAlerts ? alerts!.outputs.http5xxAlertId : ''
output podFailureAlertId string = deployAlerts ? alerts!.outputs.podFailureAlertId : ''
output crashLoopOomAlertId string = deployAlerts ? alerts!.outputs.crashLoopOomAlertId : ''
output highCpuAlertId string = deployAlerts ? alerts!.outputs.highCpuAlertId : ''
output probeFailureAlertId string = deployAlerts ? alerts!.outputs.probeFailureAlertId : ''
output networkErrorAlertId string = deployAlerts ? alerts!.outputs.networkErrorAlertId : ''
output sreAgentId string = deploySreAgent ? sreAgent!.outputs.agentId : ''
output sreAgentPortalUrl string = deploySreAgent ? sreAgent!.outputs.agentPortalUrl : ''
output sreAgentName string = deploySreAgent ? sreAgent!.outputs.agentName : ''
output sreAgentManagedIdentityId string = deploySreAgent ? sreAgent!.outputs.managedIdentityId : ''
output sreAgentManagedIdentityPrincipalId string = deploySreAgent ? sreAgent!.outputs.managedIdentityPrincipalId : ''
output sreAgentSystemPrincipalId string = deploySreAgent ? sreAgent!.outputs.systemAssignedPrincipalId : ''
output dashboardId string = dashboard.outputs.dashboardId
output chaosExperimentNames object = deployChaosStudio ? chaosStudio!.outputs.experimentNames : {}

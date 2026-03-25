// =============================================================================
// Bicep Parameters File - SRE Agent Sandbox
// =============================================================================
// Deploy with: az deployment sub create --location centralus --template-file main.bicep
// =============================================================================

using 'main.bicep'

// Core parameters are passed by scripts/deploy.ps1 via --parameters

// Pre-staged resource group names
// Format: {ENV}-{PROJECT}-{WORKLOAD}-{REGION}-RG (uppercase)
param infraResourceGroupName = ''
param monitorResourceGroupName = ''
param sreResourceGroupName = ''

// Optional: custom name for AKS node resource group (MC_ group)
// Leave empty to use Azure default naming: MC_<infraRG>_<aksName>_<location>
param nodeResourceGroupName = ''

// Observability stack (Grafana + Prometheus)
param deployObservability = true

// Baseline alert rules
param deployAlerts = true

// Deploy Azure SRE Agent (programmatic deployment now supported)
param deploySreAgent = true

// Deploy Chaos Studio experiments for automated fault injection
param deployChaosStudio = true

// Default action group for incident routing
param deployActionGroup = true

// Action group notification recipients
param actionGroupEmailReceivers = [
  {
    name: 'YourName-Email'
    emailAddress: 'yourname@example.com'
    useCommonAlertSchema: true
  }
]

param actionGroupSmsReceivers = [
  {
    name: 'YourName-SMS'
    countryCode: '1'
    phoneNumber: '0000000000'
  }
]

// AKS Configuration - cost-optimized for demo
param kubernetesVersion = '1.32'
param systemNodeVmSize = 'Standard_D2s_v6'
param userNodeVmSize = 'Standard_D2s_v6'
param systemNodeCount = 2
param userNodeCount = 3

// Tags
param tags = {
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

// =============================================================================
// Azure Chaos Studio Module
// =============================================================================
// Deploys Chaos Studio Target, Capabilities, and Experiments against the AKS
// cluster to automate breakable fault injection scenarios with Chaos Mesh.
//
// Experiments (all on-demand, pets namespace only):
//   1. OOMKilled       - Memory stress on order-service   → triggers crashloop-oom alert        [HIGH RISK]
//   2. CrashLoop       - Pod kill on product-service      → triggers pod-restarts alert
//   3. High CPU        - CPU stress on store-front         → triggers high-cpu alert
//   4. Probe Failure   - HTTP 500 on store-admin:8081      → triggers probe-failure alert
//   5. Network Block   - Network partition on makeline-svc → triggers network-container-errors alert [HIGH RISK]
//   6. MongoDB Down    - Pod kill on mongodb               → triggers pod-failures alert           [HIGH RISK]
// =============================================================================

@description('Azure region for deployment')
param location string

@description('Tags to apply to resources')
param tags object

@description('Name of the AKS cluster')
param aksClusterName string

@description('Name prefix for chaos resources')
param namePrefix string

@description('Duration of each experiment in ISO 8601 format')
param experimentDuration string = 'PT10M'

@description('Duration of stress experiments (shorter to limit blast radius)')
param stressDuration string = 'PT5M'

// =============================================================================
// CHAOS STUDIO TARGET & CAPABILITIES
// =============================================================================

// Enable the AKS cluster as a Chaos Studio target (service-direct / Chaos Mesh)
resource chaosTarget 'Microsoft.Chaos/targets@2024-01-01' = {
  name: 'Microsoft-AzureKubernetesServiceChaosMesh'
  location: location
  scope: aksCluster
  properties: {}
}

// Reference the existing AKS cluster
resource aksCluster 'Microsoft.ContainerService/managedClusters@2024-02-01' existing = {
  name: aksClusterName
}

// Enable Chaos Mesh capabilities on the target
resource capabilityPodChaos 'Microsoft.Chaos/targets/capabilities@2024-01-01' = {
  parent: chaosTarget
  name: 'PodChaos-2.2'
}

resource capabilityStressChaos 'Microsoft.Chaos/targets/capabilities@2024-01-01' = {
  parent: chaosTarget
  name: 'StressChaos-2.2'
}

resource capabilityNetworkChaos 'Microsoft.Chaos/targets/capabilities@2024-01-01' = {
  parent: chaosTarget
  name: 'NetworkChaos-2.2'
}

resource capabilityHTTPChaos 'Microsoft.Chaos/targets/capabilities@2024-01-01' = {
  parent: chaosTarget
  name: 'HTTPChaos-2.2'
}

// =============================================================================
// MANAGED IDENTITY FOR EXPERIMENTS
// =============================================================================

resource chaosIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${namePrefix}-chaos-id'
  location: location
  tags: tags
}

// Grant the chaos identity "Azure Kubernetes Service Cluster Admin Role" on the AKS cluster
// Required for credential access to the cluster
resource chaosAksAdminRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aksCluster.id, chaosIdentity.id, 'aks-cluster-admin-chaos')
  scope: aksCluster
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '0ab0b1a8-8aac-4efd-b8c2-3ee1fb270be8') // Azure Kubernetes Service Cluster Admin Role
    principalId: chaosIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// Grant the chaos identity "Azure Kubernetes Service RBAC Cluster Admin" on the AKS cluster
// Required for Kubernetes data plane operations: pods, namespaces, CRDs, cluster roles, etc.
resource chaosAksRbacAdmin 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aksCluster.id, chaosIdentity.id, 'aks-rbac-cluster-admin-chaos')
  scope: aksCluster
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b1ff04bb-8a4e-4dc4-8eb5-8693973ce19b') // Azure Kubernetes Service RBAC Cluster Admin
    principalId: chaosIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// =============================================================================
// EXPERIMENT 1: OOMKilled - Memory Stress on order-service [HIGH RISK]
// =============================================================================

resource expOomKilled 'Microsoft.Chaos/experiments@2024-01-01' = {
  name: '${namePrefix}-oom-killed'
  location: location
  tags: union(tags, { scenario: 'oom-killed', risk: 'High' })
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${chaosIdentity.id}': {}
    }
  }
  properties: {
    selectors: [
      {
        type: 'List'
        id: 'selector-oom'
        targets: [
          {
            type: 'ChaosTarget'
            id: chaosTarget.id
          }
        ]
      }
    ]
    steps: [
      {
        name: 'step1-oom-stress'
        branches: [
          {
            name: 'branch1'
            actions: [
              {
                type: 'continuous'
                name: 'urn:csci:microsoft:azureKubernetesServiceChaosMesh:stressChaos/2.2'
                selectorId: 'selector-oom'
                duration: stressDuration
                parameters: [
                  {
                    key: 'jsonSpec'
                    value: '{"mode":"one","selector":{"namespaces":["pets"],"labelSelectors":{"app":"order-service"}},"stressors":{"memory":{"workers":1,"size":"200MB"}}}'
                  }
                ]
              }
            ]
          }
        ]
      }
    ]
  }
  dependsOn: [chaosAksAdminRole, chaosAksRbacAdmin, capabilityStressChaos]
}

// =============================================================================
// EXPERIMENT 2: CrashLoop - Pod Kill on product-service
// =============================================================================

resource expCrashLoop 'Microsoft.Chaos/experiments@2024-01-01' = {
  name: '${namePrefix}-crash-loop'
  location: location
  tags: union(tags, { scenario: 'crash-loop' })
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${chaosIdentity.id}': {}
    }
  }
  properties: {
    selectors: [
      {
        type: 'List'
        id: 'selector-crash'
        targets: [
          {
            type: 'ChaosTarget'
            id: chaosTarget.id
          }
        ]
      }
    ]
    steps: [
      {
        name: 'step1-pod-kill'
        branches: [
          {
            name: 'branch1'
            actions: [
              {
                type: 'continuous'
                name: 'urn:csci:microsoft:azureKubernetesServiceChaosMesh:podChaos/2.2'
                selectorId: 'selector-crash'
                duration: experimentDuration
                parameters: [
                  {
                    key: 'jsonSpec'
                    value: '{"action":"pod-kill","mode":"one","selector":{"namespaces":["pets"],"labelSelectors":{"app":"product-service"}},"gracePeriod":0}'
                  }
                ]
              }
            ]
          }
        ]
      }
    ]
  }
  dependsOn: [chaosAksAdminRole, chaosAksRbacAdmin, capabilityPodChaos]
}

// =============================================================================
// EXPERIMENT 3: High CPU - CPU Stress on store-front
// =============================================================================

resource expHighCpu 'Microsoft.Chaos/experiments@2024-01-01' = {
  name: '${namePrefix}-high-cpu'
  location: location
  tags: union(tags, { scenario: 'high-cpu' })
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${chaosIdentity.id}': {}
    }
  }
  properties: {
    selectors: [
      {
        type: 'List'
        id: 'selector-cpu'
        targets: [
          {
            type: 'ChaosTarget'
            id: chaosTarget.id
          }
        ]
      }
    ]
    steps: [
      {
        name: 'step1-cpu-stress'
        branches: [
          {
            name: 'branch1'
            actions: [
              {
                type: 'continuous'
                name: 'urn:csci:microsoft:azureKubernetesServiceChaosMesh:stressChaos/2.2'
                selectorId: 'selector-cpu'
                duration: stressDuration
                parameters: [
                  {
                    key: 'jsonSpec'
                    value: '{"mode":"one","selector":{"namespaces":["pets"],"labelSelectors":{"app":"store-front"}},"stressors":{"cpu":{"workers":2,"load":50}}}'
                  }
                ]
              }
            ]
          }
        ]
      }
    ]
  }
  dependsOn: [chaosAksAdminRole, chaosAksRbacAdmin, capabilityStressChaos]
}

// =============================================================================
// EXPERIMENT 4: Probe Failure - HTTP Chaos returning 500 on store-admin health
// =============================================================================

resource expProbeFailure 'Microsoft.Chaos/experiments@2024-01-01' = {
  name: '${namePrefix}-probe-failure'
  location: location
  tags: union(tags, { scenario: 'probe-failure' })
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${chaosIdentity.id}': {}
    }
  }
  properties: {
    selectors: [
      {
        type: 'List'
        id: 'selector-probe'
        targets: [
          {
            type: 'ChaosTarget'
            id: chaosTarget.id
          }
        ]
      }
    ]
    steps: [
      {
        name: 'step1-http-fault'
        branches: [
          {
            name: 'branch1'
            actions: [
              {
                type: 'continuous'
                name: 'urn:csci:microsoft:azureKubernetesServiceChaosMesh:httpChaos/2.2'
                selectorId: 'selector-probe'
                duration: experimentDuration
                parameters: [
                  {
                    key: 'jsonSpec'
                    value: '{"mode":"all","selector":{"namespaces":["pets"],"labelSelectors":{"app":"store-admin"}},"target":"Request","port":8081,"path":"/health","method":"GET","replace":{"code":500,"body":"eyJzdGF0dXMiOiJ1bmhlYWx0aHkifQ=="}}'
                  }
                ]
              }
            ]
          }
        ]
      }
    ]
  }
  dependsOn: [chaosAksAdminRole, chaosAksRbacAdmin, capabilityHTTPChaos]
}

// =============================================================================
// EXPERIMENT 5: Network Block - Network Partition on makeline-service [HIGH RISK]
// =============================================================================

resource expNetworkBlock 'Microsoft.Chaos/experiments@2024-01-01' = {
  name: '${namePrefix}-network-block'
  location: location
  tags: union(tags, { scenario: 'network-block', risk: 'High' })
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${chaosIdentity.id}': {}
    }
  }
  properties: {
    selectors: [
      {
        type: 'List'
        id: 'selector-net'
        targets: [
          {
            type: 'ChaosTarget'
            id: chaosTarget.id
          }
        ]
      }
    ]
    steps: [
      {
        name: 'step1-network-partition'
        branches: [
          {
            name: 'branch1'
            actions: [
              {
                type: 'continuous'
                name: 'urn:csci:microsoft:azureKubernetesServiceChaosMesh:networkChaos/2.2'
                selectorId: 'selector-net'
                duration: experimentDuration
                parameters: [
                  {
                    key: 'jsonSpec'
                    value: '{"action":"partition","mode":"all","selector":{"namespaces":["pets"],"labelSelectors":{"app":"makeline-service"}},"direction":"both"}'
                  }
                ]
              }
            ]
          }
        ]
      }
    ]
  }
  dependsOn: [chaosAksAdminRole, chaosAksRbacAdmin, capabilityNetworkChaos]
}

// =============================================================================
// EXPERIMENT 6: MongoDB Down - Pod Kill on mongodb [HIGH RISK]
// =============================================================================

resource expMongodbDown 'Microsoft.Chaos/experiments@2024-01-01' = {
  name: '${namePrefix}-mongodb-down'
  location: location
  tags: union(tags, { scenario: 'mongodb-down', risk: 'High' })
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${chaosIdentity.id}': {}
    }
  }
  properties: {
    selectors: [
      {
        type: 'List'
        id: 'selector-mongo'
        targets: [
          {
            type: 'ChaosTarget'
            id: chaosTarget.id
          }
        ]
      }
    ]
    steps: [
      {
        name: 'step1-kill-mongodb'
        branches: [
          {
            name: 'branch1'
            actions: [
              {
                type: 'continuous'
                name: 'urn:csci:microsoft:azureKubernetesServiceChaosMesh:podChaos/2.2'
                selectorId: 'selector-mongo'
                duration: experimentDuration
                parameters: [
                  {
                    key: 'jsonSpec'
                    value: '{"action":"pod-kill","mode":"all","selector":{"namespaces":["pets"],"labelSelectors":{"app":"mongodb"}},"gracePeriod":0}'
                  }
                ]
              }
            ]
          }
        ]
      }
    ]
  }
  dependsOn: [chaosAksAdminRole, chaosAksRbacAdmin, capabilityPodChaos]
}

// =============================================================================
// OUTPUTS
// =============================================================================

output chaosIdentityPrincipalId string = chaosIdentity.properties.principalId
output experimentIds object = {
  oomKilled: expOomKilled.id
  crashLoop: expCrashLoop.id
  highCpu: expHighCpu.id
  probeFailure: expProbeFailure.id
  networkBlock: expNetworkBlock.id
  mongodbDown: expMongodbDown.id
}
output experimentNames object = {
  oomKilled: expOomKilled.name
  crashLoop: expCrashLoop.name
  highCpu: expHighCpu.name
  probeFailure: expProbeFailure.name
  networkBlock: expNetworkBlock.name
  mongodbDown: expMongodbDown.name
}

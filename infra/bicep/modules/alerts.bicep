// =============================================================================
// Alerts Module
// =============================================================================
// Deploys Azure Monitor scheduled query alerts for the SRE demo app.
// Each alert maps 1:1 to a Chaos Studio experiment:
//
//   Experiment 1 (OOMKilled)     → crashloop-oom          (KubeEvents: OOMKilled/BackOff)
//   Experiment 2 (CrashLoop)     → pod-restarts           (KubePodInventory: RestartCount)
//   Experiment 3 (High CPU)      → high-cpu               (Perf: cpuUsageNanoCores)
//   Experiment 4 (Probe Failure) → probe-failure          (KubeEvents: Unhealthy)
//   Experiment 5 (Network Block) → network-container-errors (KubePodInventory: ContainersNotReady)
//   Experiment 6 (MongoDB Down)  → pod-failures           (KubePodInventory: Failed/Pending)
//   (bonus)                      → http-5xx               (ContainerLog: error patterns)
// =============================================================================

@description('Prefix used for alert names')
param namePrefix string

@description('Azure region for deployment')
param location string

@description('Tags to apply to resources')
param tags object

@description('Log Analytics workspace resource ID')
param logAnalyticsWorkspaceId string

@description('Application namespace to monitor')
param appNamespace string = 'pets'

@description('Optional action group resource IDs for alert notifications')
param actionGroupIds array = []

var alertActions = {
  actionGroups: actionGroupIds
  customProperties: {
    source: 'azure-sre-agent-sandbox'
    workload: 'pet-store'
  }
}

// ---- Chaos experiment #2: CrashLoop (product-service pod kill) ----
resource podRestartAlert 'Microsoft.Insights/scheduledQueryRules@2023-12-01' = {
  name: '${namePrefix}-pod-restarts'
  location: location
  tags: tags
  kind: 'LogAlert'
  properties: {
    displayName: 'Pet Store - Pod restart spike (Exp 2: CrashLoop)'
    description: 'Triggers when restart activity is detected in the application namespace. Maps to Chaos experiment 2 (CrashLoop on product-service).'
    enabled: true
    severity: 2
    scopes: [
      logAnalyticsWorkspaceId
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT1M'
    autoMitigate: true
    skipQueryValidation: true
    criteria: {
      allOf: [
        {
          query: 'KubePodInventory | where TimeGenerated > ago(2m) | where Namespace == "${appNamespace}" | where ContainerRestartCount > 0'
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: 0
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    actions: alertActions
  }
}

// ---- Bonus alert: HTTP 5xx from container logs (fires from multiple experiments) ----
resource http5xxAlert 'Microsoft.Insights/scheduledQueryRules@2023-12-01' = {
  name: '${namePrefix}-http-5xx'
  location: location
  tags: tags
  kind: 'LogAlert'
  properties: {
    displayName: 'Pet Store - HTTP 5xx / application errors'
    description: 'Triggers when application error patterns are detected in container logs or Kubernetes warning events.'
    enabled: true
    severity: 1
    scopes: [
      logAnalyticsWorkspaceId
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    autoMitigate: true
    skipQueryValidation: true
    criteria: {
      allOf: [
        {
          query: 'KubeEvents | where TimeGenerated > ago(5m) | where Namespace == "${appNamespace}" | where Type == "Warning" | where Reason in ("Failed", "FailedMount", "FailedAttachVolume", "FailedScheduling", "NetworkNotReady")'
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: 0
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    actions: alertActions
  }
}

// ---- Chaos experiment #6: MongoDB Down (mongodb pod kill) ----
resource podFailureAlert 'Microsoft.Insights/scheduledQueryRules@2023-12-01' = {
  name: '${namePrefix}-pod-failures'
  location: location
  tags: tags
  kind: 'LogAlert'
  properties: {
    displayName: 'Pet Store - Failed or pending pods (Exp 6: MongoDB Down)'
    description: 'Triggers when failed or pending pods are detected. Maps to Chaos experiment 6 (mongodb pod kill causing cascading failures).'
    enabled: true
    severity: 2
    scopes: [
      logAnalyticsWorkspaceId
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT1M'
    autoMitigate: true
    skipQueryValidation: true
    criteria: {
      allOf: [
        {
          query: 'KubePodInventory | where TimeGenerated > ago(2m) | where Namespace == "${appNamespace}" | where PodStatus in ("Failed", "Pending")'
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: 0
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    actions: alertActions
  }
}

// ---- Chaos experiment #1: OOMKilled (order-service memory stress) ----
resource crashLoopOomAlert 'Microsoft.Insights/scheduledQueryRules@2023-12-01' = {
  name: '${namePrefix}-crashloop-oom'
  location: location
  tags: tags
  kind: 'LogAlert'
  properties: {
    displayName: 'Pet Store - CrashLoop/OOM detected (Exp 1: OOMKilled)'
    description: 'Triggers when CrashLoopBackOff or OOM-related Kubernetes events are detected. Maps to Chaos experiment 1 (OOMKilled on order-service).'
    enabled: true
    severity: 1
    scopes: [
      logAnalyticsWorkspaceId
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT1M'
    autoMitigate: true
    skipQueryValidation: true
    criteria: {
      allOf: [
        {
          query: 'KubeEvents | where TimeGenerated > ago(2m) | where Namespace == "${appNamespace}" | where Reason in ("BackOff", "OOMKilled", "CrashLoopBackOff")'
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: 0
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    actions: alertActions
  }
}

// ---- Chaos experiment #3: High CPU (store-front CPU stress) ----
resource highCpuAlert 'Microsoft.Insights/scheduledQueryRules@2023-12-01' = {
  name: '${namePrefix}-high-cpu'
  location: location
  tags: tags
  kind: 'LogAlert'
  properties: {
    displayName: 'Pet Store - High CPU utilization (Exp 3: High CPU)'
    description: 'Triggers when container CPU usage exceeds threshold in the application namespace. Maps to Chaos experiment 3 (CPU stress on store-front).'
    enabled: true
    severity: 2
    scopes: [
      logAnalyticsWorkspaceId
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    autoMitigate: true
    skipQueryValidation: true
    criteria: {
      allOf: [
        {
          query: 'Perf | where TimeGenerated > ago(5m) | where ObjectName == "K8SContainer" | where CounterName == "cpuUsageNanoCores" | extend podNamespace = tostring(split(InstanceName, "/")[0]) | where podNamespace == "${appNamespace}" | summarize AvgCPU = avg(CounterValue) by bin(TimeGenerated, 1m), Computer, InstanceName | where AvgCPU > 800000000'
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: 0
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    actions: alertActions
  }
}

// ---- Chaos experiment #4: Probe Failure (store-admin HTTP 500 on health) ----
resource probeFailureAlert 'Microsoft.Insights/scheduledQueryRules@2023-12-01' = {
  name: '${namePrefix}-probe-failure'
  location: location
  tags: tags
  kind: 'LogAlert'
  properties: {
    displayName: 'Pet Store - Liveness/readiness probe failures (Exp 4: Probe Failure)'
    description: 'Triggers when Kubernetes Unhealthy events (probe failures) are detected. Maps to Chaos experiment 4 (HTTP 500 on store-admin health).'
    enabled: true
    severity: 1
    scopes: [
      logAnalyticsWorkspaceId
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT1M'
    autoMitigate: true
    skipQueryValidation: true
    criteria: {
      allOf: [
        {
          query: 'KubeEvents | where TimeGenerated > ago(2m) | where Namespace == "${appNamespace}" | where Reason == "Unhealthy"'
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: 0
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    actions: alertActions
  }
}

// ---- Chaos experiments #5: Network Block (makeline-service network partition) ----
resource networkErrorAlert 'Microsoft.Insights/scheduledQueryRules@2023-12-01' = {
  name: '${namePrefix}-network-container-errors'
  location: location
  tags: tags
  kind: 'LogAlert'
  properties: {
    displayName: 'Pet Store - Network errors or containers not ready (Exp 5: Network Block)'
    description: 'Triggers when containers become not-ready or network-related errors are detected. Maps to Chaos experiment 5 (network partition on makeline-service).'
    enabled: true
    severity: 1
    scopes: [
      logAnalyticsWorkspaceId
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT1M'
    autoMitigate: true
    skipQueryValidation: true
    criteria: {
      allOf: [
        {
          query: 'KubePodInventory | where TimeGenerated > ago(2m) | where Namespace == "${appNamespace}" | where ContainerStatus != "Running" and ContainerStatus != "Terminated" and ContainerStatus != "" | where ContainerStatusReason in ("ContainersNotReady", "CrashLoopBackOff", "Error", "ImagePullBackOff")'
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: 0
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    actions: alertActions
  }
}

output podRestartAlertId string = podRestartAlert.id
output http5xxAlertId string = http5xxAlert.id
output podFailureAlertId string = podFailureAlert.id
output crashLoopOomAlertId string = crashLoopOomAlert.id
output highCpuAlertId string = highCpuAlert.id
output probeFailureAlertId string = probeFailureAlert.id
output networkErrorAlertId string = networkErrorAlert.id

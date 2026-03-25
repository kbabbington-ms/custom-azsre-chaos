// =============================================================================
// Azure Portal Dashboard Module
// =============================================================================
// Deploys an Azure Portal shared dashboard with operational views for the
// SRE Agent Demo Lab: AKS health, pod metrics, App Insights, Log Analytics,
// and Key Vault status.
// =============================================================================

@description('Name of the dashboard')
param name string

@description('Azure region for deployment')
param location string

@description('Tags to apply to resources')
param tags object

@description('AKS cluster resource ID')
param aksClusterId string

@description('Log Analytics workspace resource ID')
param logAnalyticsWorkspaceId string

@description('Application Insights resource ID')
param appInsightsId string

@description('Key Vault resource ID')
param keyVaultId string

@description('Container Registry resource ID')
param acrId string

@description('Subscription ID')
param subscriptionId string

@description('Resource group name')
param resourceGroupName string

@description('Grafana dashboard URL')
param grafanaDashboardUrl string

// =============================================================================
// DASHBOARD
// =============================================================================

resource dashboard 'Microsoft.Portal/dashboards@2020-09-01-preview' = {
  name: name
  location: location
  tags: union(tags, {
    'hidden-title': 'SRE Agent Demo Lab - Operations Dashboard'
  })
  properties: {
    lenses: [
      {
        order: 0
        parts: [
          // ── Row 0: Title ──
          {
            position: { x: 0, y: 0, colSpan: 12, rowSpan: 1 }
            metadata: {
              type: 'Extension/HubsExtension/PartType/MarkdownPart'
              inputs: []
              settings: {
                content: {
                  settings: {
                    content: '## 🛡️ SRE Agent Demo Lab – Operations Dashboard\n---'
                    title: ''
                    subtitle: ''
                    markdownSource: 1
                    markdownUri: ''
                  }
                }
              }
            }
          }
          // ── Row 1: AKS Cluster Health Header ──
          {
            position: { x: 0, y: 1, colSpan: 12, rowSpan: 1 }
            metadata: {
              type: 'Extension/HubsExtension/PartType/MarkdownPart'
              inputs: []
              settings: {
                content: {
                  settings: {
                    content: '### 🚀 AKS Cluster Health'
                    title: ''
                    subtitle: ''
                    markdownSource: 1
                    markdownUri: ''
                  }
                }
              }
            }
          }
          // AKS – Node CPU %
          {
            position: { x: 0, y: 2, colSpan: 4, rowSpan: 3 }
            metadata: {
              type: 'Extension/HubsExtension/PartType/MonitorChartPart'
              inputs: [
                { name: 'sharedTimeRange', isOptional: true }
              ]
              settings: {
                content: {
                  options: {
                    chart: {
                      title: 'Node CPU Utilization %'
                      titleKind: 2
                      metrics: [
                        {
                          resourceMetadata: { id: aksClusterId }
                          name: 'node_cpu_usage_percentage'
                          aggregationType: 4
                          namespace: 'Microsoft.ContainerService/managedClusters'
                          metricVisualization: { displayName: 'Node CPU %', resourceDisplayName: 'AKS' }
                        }
                      ]
                      visualization: {
                        chartType: 2
                        legendVisualization: { isVisible: true, position: 2, hideSubtitle: false }
                        axisVisualization: { x: { isVisible: true }, y: { isVisible: true } }
                      }
                      timespan: { relative: { duration: 3600000 } }
                    }
                  }
                }
              }
            }
          }
          // AKS – Node Memory %
          {
            position: { x: 4, y: 2, colSpan: 4, rowSpan: 3 }
            metadata: {
              type: 'Extension/HubsExtension/PartType/MonitorChartPart'
              inputs: [
                { name: 'sharedTimeRange', isOptional: true }
              ]
              settings: {
                content: {
                  options: {
                    chart: {
                      title: 'Node Memory Utilization %'
                      titleKind: 2
                      metrics: [
                        {
                          resourceMetadata: { id: aksClusterId }
                          name: 'node_memory_working_set_percentage'
                          aggregationType: 4
                          namespace: 'Microsoft.ContainerService/managedClusters'
                          metricVisualization: { displayName: 'Node Memory %', resourceDisplayName: 'AKS' }
                        }
                      ]
                      visualization: {
                        chartType: 2
                        legendVisualization: { isVisible: true, position: 2, hideSubtitle: false }
                        axisVisualization: { x: { isVisible: true }, y: { isVisible: true } }
                      }
                      timespan: { relative: { duration: 3600000 } }
                    }
                  }
                }
              }
            }
          }
          // AKS – Node Count
          {
            position: { x: 8, y: 2, colSpan: 4, rowSpan: 3 }
            metadata: {
              type: 'Extension/HubsExtension/PartType/MonitorChartPart'
              inputs: [
                { name: 'sharedTimeRange', isOptional: true }
              ]
              settings: {
                content: {
                  options: {
                    chart: {
                      title: 'Node Count'
                      titleKind: 2
                      metrics: [
                        {
                          resourceMetadata: { id: aksClusterId }
                          name: 'kube_node_status_condition'
                          aggregationType: 7
                          namespace: 'Microsoft.ContainerService/managedClusters'
                          metricVisualization: { displayName: 'Node Status', resourceDisplayName: 'AKS' }
                        }
                      ]
                      visualization: {
                        chartType: 2
                        legendVisualization: { isVisible: true, position: 2, hideSubtitle: false }
                        axisVisualization: { x: { isVisible: true }, y: { isVisible: true } }
                      }
                      timespan: { relative: { duration: 3600000 } }
                    }
                  }
                }
              }
            }
          }
          // ── Row 2: Pod & Container Header ──
          {
            position: { x: 0, y: 5, colSpan: 12, rowSpan: 1 }
            metadata: {
              type: 'Extension/HubsExtension/PartType/MarkdownPart'
              inputs: []
              settings: {
                content: {
                  settings: {
                    content: '### 📦 Pod & Container Metrics'
                    title: ''
                    subtitle: ''
                    markdownSource: 1
                    markdownUri: ''
                  }
                }
              }
            }
          }
          // Pods Ready
          {
            position: { x: 0, y: 6, colSpan: 4, rowSpan: 3 }
            metadata: {
              type: 'Extension/HubsExtension/PartType/MonitorChartPart'
              inputs: [
                { name: 'sharedTimeRange', isOptional: true }
              ]
              settings: {
                content: {
                  options: {
                    chart: {
                      title: 'Pods in Ready State'
                      titleKind: 2
                      metrics: [
                        {
                          resourceMetadata: { id: aksClusterId }
                          name: 'kube_pod_status_ready'
                          aggregationType: 4
                          namespace: 'Microsoft.ContainerService/managedClusters'
                          metricVisualization: { displayName: 'Pods Ready', resourceDisplayName: 'AKS' }
                        }
                      ]
                      visualization: {
                        chartType: 2
                        legendVisualization: { isVisible: true, position: 2, hideSubtitle: false }
                        axisVisualization: { x: { isVisible: true }, y: { isVisible: true } }
                      }
                      timespan: { relative: { duration: 3600000 } }
                    }
                  }
                }
              }
            }
          }
          // Pod Phase
          {
            position: { x: 4, y: 6, colSpan: 4, rowSpan: 3 }
            metadata: {
              type: 'Extension/HubsExtension/PartType/MonitorChartPart'
              inputs: [
                { name: 'sharedTimeRange', isOptional: true }
              ]
              settings: {
                content: {
                  options: {
                    chart: {
                      title: 'Pod Phase Status'
                      titleKind: 2
                      metrics: [
                        {
                          resourceMetadata: { id: aksClusterId }
                          name: 'kube_pod_status_phase'
                          aggregationType: 4
                          namespace: 'Microsoft.ContainerService/managedClusters'
                          metricVisualization: { displayName: 'Pod Phase', resourceDisplayName: 'AKS' }
                        }
                      ]
                      visualization: {
                        chartType: 1
                        legendVisualization: { isVisible: true, position: 2, hideSubtitle: false }
                        axisVisualization: { x: { isVisible: true }, y: { isVisible: true } }
                      }
                      timespan: { relative: { duration: 3600000 } }
                    }
                  }
                }
              }
            }
          }
          // Container CPU Millicores
          {
            position: { x: 8, y: 6, colSpan: 4, rowSpan: 3 }
            metadata: {
              type: 'Extension/HubsExtension/PartType/MonitorChartPart'
              inputs: [
                { name: 'sharedTimeRange', isOptional: true }
              ]
              settings: {
                content: {
                  options: {
                    chart: {
                      title: 'Container CPU (Millicores)'
                      titleKind: 2
                      metrics: [
                        {
                          resourceMetadata: { id: aksClusterId }
                          name: 'node_cpu_usage_millicores'
                          aggregationType: 4
                          namespace: 'Microsoft.ContainerService/managedClusters'
                          metricVisualization: { displayName: 'CPU Millicores', resourceDisplayName: 'AKS' }
                        }
                      ]
                      visualization: {
                        chartType: 2
                        legendVisualization: { isVisible: true, position: 2, hideSubtitle: false }
                        axisVisualization: { x: { isVisible: true }, y: { isVisible: true } }
                      }
                      timespan: { relative: { duration: 3600000 } }
                    }
                  }
                }
              }
            }
          }
          // ── Row 3: Application Insights Header ──
          {
            position: { x: 0, y: 9, colSpan: 12, rowSpan: 1 }
            metadata: {
              type: 'Extension/HubsExtension/PartType/MarkdownPart'
              inputs: []
              settings: {
                content: {
                  settings: {
                    content: '### 📊 Application Insights'
                    title: ''
                    subtitle: ''
                    markdownSource: 1
                    markdownUri: ''
                  }
                }
              }
            }
          }
          // App Insights – Server Requests
          {
            position: { x: 0, y: 10, colSpan: 4, rowSpan: 3 }
            metadata: {
              type: 'Extension/HubsExtension/PartType/MonitorChartPart'
              inputs: [
                { name: 'sharedTimeRange', isOptional: true }
              ]
              settings: {
                content: {
                  options: {
                    chart: {
                      title: 'Server Requests'
                      titleKind: 2
                      metrics: [
                        {
                          resourceMetadata: { id: appInsightsId }
                          name: 'requests/count'
                          aggregationType: 7
                          namespace: 'microsoft.insights/components'
                          metricVisualization: { displayName: 'Request Count', resourceDisplayName: 'App Insights' }
                        }
                      ]
                      visualization: {
                        chartType: 2
                        legendVisualization: { isVisible: true, position: 2, hideSubtitle: false }
                        axisVisualization: { x: { isVisible: true }, y: { isVisible: true } }
                      }
                      timespan: { relative: { duration: 3600000 } }
                    }
                  }
                }
              }
            }
          }
          // App Insights – Failed Requests
          {
            position: { x: 4, y: 10, colSpan: 4, rowSpan: 3 }
            metadata: {
              type: 'Extension/HubsExtension/PartType/MonitorChartPart'
              inputs: [
                { name: 'sharedTimeRange', isOptional: true }
              ]
              settings: {
                content: {
                  options: {
                    chart: {
                      title: 'Failed Requests'
                      titleKind: 2
                      metrics: [
                        {
                          resourceMetadata: { id: appInsightsId }
                          name: 'requests/failed'
                          aggregationType: 7
                          namespace: 'microsoft.insights/components'
                          metricVisualization: { displayName: 'Failed Requests', resourceDisplayName: 'App Insights' }
                        }
                      ]
                      visualization: {
                        chartType: 2
                        legendVisualization: { isVisible: true, position: 2, hideSubtitle: false }
                        axisVisualization: { x: { isVisible: true }, y: { isVisible: true } }
                      }
                      timespan: { relative: { duration: 3600000 } }
                    }
                  }
                }
              }
            }
          }
          // App Insights – Response Time
          {
            position: { x: 8, y: 10, colSpan: 4, rowSpan: 3 }
            metadata: {
              type: 'Extension/HubsExtension/PartType/MonitorChartPart'
              inputs: [
                { name: 'sharedTimeRange', isOptional: true }
              ]
              settings: {
                content: {
                  options: {
                    chart: {
                      title: 'Avg Response Time (ms)'
                      titleKind: 2
                      metrics: [
                        {
                          resourceMetadata: { id: appInsightsId }
                          name: 'requests/duration'
                          aggregationType: 4
                          namespace: 'microsoft.insights/components'
                          metricVisualization: { displayName: 'Avg Response Time', resourceDisplayName: 'App Insights' }
                        }
                      ]
                      visualization: {
                        chartType: 2
                        legendVisualization: { isVisible: true, position: 2, hideSubtitle: false }
                        axisVisualization: { x: { isVisible: true }, y: { isVisible: true } }
                      }
                      timespan: { relative: { duration: 3600000 } }
                    }
                  }
                }
              }
            }
          }
          // ── Row 4: Log Analytics Header ──
          {
            position: { x: 0, y: 13, colSpan: 12, rowSpan: 1 }
            metadata: {
              type: 'Extension/HubsExtension/PartType/MarkdownPart'
              inputs: []
              settings: {
                content: {
                  settings: {
                    content: '### 📋 Log Analytics – Container Logs & Events'
                    title: ''
                    subtitle: ''
                    markdownSource: 1
                    markdownUri: ''
                  }
                }
              }
            }
          }
          // Log Analytics – Non-Running Pods KQL
          {
            position: { x: 0, y: 14, colSpan: 6, rowSpan: 4 }
            metadata: {
              type: 'Extension/Microsoft_OperationsManagementSuite_Workspace/PartType/LogsDashboardPart'
              inputs: [
                { name: 'resourceTypeMode', isOptional: true }
                { name: 'ComponentId', isOptional: true, value: logAnalyticsWorkspaceId }
              ]
              settings: {
                content: {
                  Query: 'KubePodInventory\n| where Namespace == "pets"\n| where PodStatus != "Running" and PodStatus != "Succeeded"\n| summarize Count=count() by PodStatus, Name, bin(TimeGenerated, 5m)\n| order by TimeGenerated desc\n| take 50'
                  ControlType: 'AnalyticsGrid'
                  SpecificChart: ''
                  PartTitle: 'Non-Running Pods (pets namespace)'
                  Dimensions: {}
                  DashboardPartTitle: 'Non-Running Pods'
                  Version: '2.0'
                }
              }
            }
          }
          // Log Analytics – Failure Events KQL
          {
            position: { x: 6, y: 14, colSpan: 6, rowSpan: 4 }
            metadata: {
              type: 'Extension/Microsoft_OperationsManagementSuite_Workspace/PartType/LogsDashboardPart'
              inputs: [
                { name: 'resourceTypeMode', isOptional: true }
                { name: 'ComponentId', isOptional: true, value: logAnalyticsWorkspaceId }
              ]
              settings: {
                content: {
                  Query: 'KubeEvents\n| where Namespace == "pets"\n| where Reason in ("BackOff", "Unhealthy", "Failed", "FailedScheduling", "OOMKilling")\n| summarize Count=count() by Reason, Name, bin(TimeGenerated, 5m)\n| order by TimeGenerated desc\n| take 50'
                  ControlType: 'AnalyticsGrid'
                  SpecificChart: ''
                  PartTitle: 'Failure Events (pets namespace)'
                  Dimensions: {}
                  DashboardPartTitle: 'Failure Events'
                  Version: '2.0'
                }
              }
            }
          }
          // ── Row 5: Container Restart Trends Header ──
          {
            position: { x: 0, y: 18, colSpan: 12, rowSpan: 1 }
            metadata: {
              type: 'Extension/HubsExtension/PartType/MarkdownPart'
              inputs: []
              settings: {
                content: {
                  settings: {
                    content: '### 🔄 Container Restart Trends'
                    title: ''
                    subtitle: ''
                    markdownSource: 1
                    markdownUri: ''
                  }
                }
              }
            }
          }
          // Container Restarts by Pod (chart)
          {
            position: { x: 0, y: 19, colSpan: 6, rowSpan: 4 }
            metadata: {
              type: 'Extension/Microsoft_OperationsManagementSuite_Workspace/PartType/LogsDashboardPart'
              inputs: [
                { name: 'resourceTypeMode', isOptional: true }
                { name: 'ComponentId', isOptional: true, value: logAnalyticsWorkspaceId }
              ]
              settings: {
                content: {
                  Query: 'KubePodInventory\n| where Namespace == "pets"\n| where ContainerRestartCount > 0\n| summarize TotalRestarts=sum(ContainerRestartCount) by Name, bin(TimeGenerated, 5m)\n| render timechart'
                  ControlType: 'FrameControlChart'
                  SpecificChart: 'StackedColumn'
                  PartTitle: 'Container Restarts by Pod'
                  Dimensions: { xAxis: { name: 'TimeGenerated', type: 'datetime' }, yAxis: [{ name: 'TotalRestarts', type: 'long' }], splitBy: [{ name: 'Name', type: 'string' }] }
                  DashboardPartTitle: 'Container Restarts by Pod'
                  Version: '2.0'
                }
              }
            }
          }
          // OOM & CrashLoop Events Timeline (chart)
          {
            position: { x: 6, y: 19, colSpan: 6, rowSpan: 4 }
            metadata: {
              type: 'Extension/Microsoft_OperationsManagementSuite_Workspace/PartType/LogsDashboardPart'
              inputs: [
                { name: 'resourceTypeMode', isOptional: true }
                { name: 'ComponentId', isOptional: true, value: logAnalyticsWorkspaceId }
              ]
              settings: {
                content: {
                  Query: 'KubeEvents\n| where Namespace == "pets"\n| where Reason in ("OOMKilling", "OOMKilled", "BackOff", "Killing", "Unhealthy")\n| summarize Count=count() by Reason, bin(TimeGenerated, 5m)\n| render timechart'
                  ControlType: 'FrameControlChart'
                  SpecificChart: 'StackedColumn'
                  PartTitle: 'OOM & CrashLoop Events'
                  Dimensions: { xAxis: { name: 'TimeGenerated', type: 'datetime' }, yAxis: [{ name: 'Count', type: 'long' }], splitBy: [{ name: 'Reason', type: 'string' }] }
                  DashboardPartTitle: 'OOM & CrashLoop Events'
                  Version: '2.0'
                }
              }
            }
          }
          // ── Row 6: Memory & Resource Pressure Header ──
          {
            position: { x: 0, y: 23, colSpan: 12, rowSpan: 1 }
            metadata: {
              type: 'Extension/HubsExtension/PartType/MarkdownPart'
              inputs: []
              settings: {
                content: {
                  settings: {
                    content: '### 💾 Memory & Resource Pressure'
                    title: ''
                    subtitle: ''
                    markdownSource: 1
                    markdownUri: ''
                  }
                }
              }
            }
          }
          // Container Memory Usage
          {
            position: { x: 0, y: 24, colSpan: 4, rowSpan: 3 }
            metadata: {
              type: 'Extension/HubsExtension/PartType/MonitorChartPart'
              inputs: [
                { name: 'sharedTimeRange', isOptional: true }
              ]
              settings: {
                content: {
                  options: {
                    chart: {
                      title: 'Container Memory Working Set'
                      titleKind: 2
                      metrics: [
                        {
                          resourceMetadata: { id: aksClusterId }
                          name: 'node_memory_working_set_percentage'
                          aggregationType: 4
                          namespace: 'Microsoft.ContainerService/managedClusters'
                          metricVisualization: { displayName: 'Memory Working Set %', resourceDisplayName: 'AKS' }
                        }
                      ]
                      visualization: {
                        chartType: 2
                        legendVisualization: { isVisible: true, position: 2, hideSubtitle: false }
                        axisVisualization: { x: { isVisible: true }, y: { isVisible: true } }
                      }
                      timespan: { relative: { duration: 3600000 } }
                    }
                  }
                }
              }
            }
          }
          // Network In Bytes
          {
            position: { x: 4, y: 24, colSpan: 4, rowSpan: 3 }
            metadata: {
              type: 'Extension/HubsExtension/PartType/MonitorChartPart'
              inputs: [
                { name: 'sharedTimeRange', isOptional: true }
              ]
              settings: {
                content: {
                  options: {
                    chart: {
                      title: 'Network In (Bytes)'
                      titleKind: 2
                      metrics: [
                        {
                          resourceMetadata: { id: aksClusterId }
                          name: 'node_network_in_bytes'
                          aggregationType: 4
                          namespace: 'Microsoft.ContainerService/managedClusters'
                          metricVisualization: { displayName: 'Network In Bytes', resourceDisplayName: 'AKS' }
                        }
                      ]
                      visualization: {
                        chartType: 2
                        legendVisualization: { isVisible: true, position: 2, hideSubtitle: false }
                        axisVisualization: { x: { isVisible: true }, y: { isVisible: true } }
                      }
                      timespan: { relative: { duration: 3600000 } }
                    }
                  }
                }
              }
            }
          }
          // Network Out Bytes
          {
            position: { x: 8, y: 24, colSpan: 4, rowSpan: 3 }
            metadata: {
              type: 'Extension/HubsExtension/PartType/MonitorChartPart'
              inputs: [
                { name: 'sharedTimeRange', isOptional: true }
              ]
              settings: {
                content: {
                  options: {
                    chart: {
                      title: 'Network Out (Bytes)'
                      titleKind: 2
                      metrics: [
                        {
                          resourceMetadata: { id: aksClusterId }
                          name: 'node_network_out_bytes'
                          aggregationType: 4
                          namespace: 'Microsoft.ContainerService/managedClusters'
                          metricVisualization: { displayName: 'Network Out Bytes', resourceDisplayName: 'AKS' }
                        }
                      ]
                      visualization: {
                        chartType: 2
                        legendVisualization: { isVisible: true, position: 2, hideSubtitle: false }
                        axisVisualization: { x: { isVisible: true }, y: { isVisible: true } }
                      }
                      timespan: { relative: { duration: 3600000 } }
                    }
                  }
                }
              }
            }
          }
          // ── Row 7: Quick Links Header ──
          {
            position: { x: 0, y: 27, colSpan: 12, rowSpan: 1 }
            metadata: {
              type: 'Extension/HubsExtension/PartType/MarkdownPart'
              inputs: []
              settings: {
                content: {
                  settings: {
                    content: '### 🔗 Quick Links'
                    title: ''
                    subtitle: ''
                    markdownSource: 1
                    markdownUri: ''
                  }
                }
              }
            }
          }
          // Quick Links Table
          {
            position: { x: 0, y: 28, colSpan: 12, rowSpan: 3 }
            metadata: {
              type: 'Extension/HubsExtension/PartType/MarkdownPart'
              inputs: []
              settings: {
                content: {
                  settings: {
                    content: '| Resource | Link |\n|---|---|\n| **AKS Cluster** | [Open in Portal](https://portal.azure.com/#@${subscriptionId}/resource${aksClusterId}/overview) |\n| **Grafana Dashboard** | [Open Grafana](${grafanaDashboardUrl}) |\n| **Application Insights** | [Open in Portal](https://portal.azure.com/#@${subscriptionId}/resource${appInsightsId}/overview) |\n| **Log Analytics** | [Open in Portal](https://portal.azure.com/#@${subscriptionId}/resource${logAnalyticsWorkspaceId}/overview) |\n| **Key Vault** | [Open in Portal](https://portal.azure.com/#@${subscriptionId}/resource${keyVaultId}/overview) |\n| **Container Registry** | [Open in Portal](https://portal.azure.com/#@${subscriptionId}/resource${acrId}/overview) |\n| **SRE Agent Portal** | [Open SRE Agent](https://aka.ms/sreagent/portal) |\n| **Resource Group** | [Open in Portal](https://portal.azure.com/#@${subscriptionId}/resource/subscriptions/${subscriptionId}/resourceGroups/${resourceGroupName}/overview) |'
                    title: ''
                    subtitle: ''
                    markdownSource: 1
                    markdownUri: ''
                  }
                }
              }
            }
          }
        ]
      }
    ]
  }
}

// =============================================================================
// OUTPUTS
// =============================================================================

output dashboardId string = dashboard.id
output dashboardName string = dashboard.name

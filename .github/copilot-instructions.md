# Azure SRE Agent Demo Lab - Copilot Instructions

## Project Overview

This repository contains a fully automated Azure SRE Agent demo lab environment using a **3 Resource Group** architecture. It deploys:

- **Azure Kubernetes Service (AKS)** with a multi-pod Pet Store e-commerce application (Central US)
- **Azure Chaos Studio** with 6 automated fault-injection experiments
- **Azure Container Registry** for container images
- **Azure Key Vault** for secrets management
- **Observability stack**: Log Analytics, Application Insights, Managed Grafana, Prometheus, Azure Monitor
- **Azure SRE Agent** for AI-powered incident diagnosis (East US 2)
- **10 breakable scenarios** for demonstrating SRE Agent capabilities

The app uses in-cluster MongoDB and RabbitMQ with Azure Managed Disk storage.

## Architecture — 3 Resource Group Model

| Resource Group | Purpose | Region | Contents |
|---|---|---|---|
| `{ENV}-{PROJECT}-AKS-{REGION}-RG` | Infrastructure | Central US | AKS, ACR, Key Vault, Chaos Studio experiments |
| `{ENV}-{PROJECT}-MON-{REGION}-RG` | Monitoring | Central US | Log Analytics, App Insights, Grafana, Alert Rules, Action Groups, Dashboards |
| `{ENV}-{PROJECT}-SRE-{REGION}-RG` | SRE Agent | East US 2 | SRE Agent resource |

Default naming convention uses `{ENV}-{PROJECT}-{WORKLOAD}-{REGION_ABBR}-RG`.

## Technology Stack

- **Infrastructure as Code**: Bicep (modular templates in `infra/bicep/`)
- **Chaos Engineering**: Azure Chaos Studio (experiments in `infra/bicep/modules/chaos-studio.bicep`)
- **Container Orchestration**: Kubernetes (manifests in `k8s/`)
- **Scripting**: PowerShell (deployment and chaos scripts in `scripts/`)
- **Dev Environment**: Dev Containers with Azure CLI, kubectl, azd

## Key Directories

```
├── infra/bicep/                    # Bicep IaC templates
│   ├── main.bicep                  # Main deployment orchestration (3-RG)
│   ├── main.bicepparam             # Parameters file
│   └── modules/
│       ├── aks.bicep               # AKS cluster
│       ├── acr.bicep               # Container registry
│       ├── keyvault.bicep          # Key Vault
│       ├── log-analytics.bicep     # Log Analytics workspace
│       ├── app-insights.bicep      # Application Insights
│       ├── grafana.bicep           # Managed Grafana
│       ├── action-group.bicep      # Alert action groups (location: global)
│       ├── alert-rules.bicep       # Metric and log-based alerts
│       ├── chaos-studio.bicep      # 6 Chaos Studio experiments
│       ├── sre-agent.bicep         # Azure SRE Agent
│       ├── dashboard.bicep         # Azure Portal dashboard
│       └── prometheus-associations.bicep  # Prometheus data collection
├── k8s/
│   ├── base/                       # Healthy application manifests
│   └── scenarios/                  # 4 kubectl breakable scenarios
├── scripts/
│   ├── deploy.ps1                  # Infrastructure deployment
│   ├── destroy.ps1                 # Teardown
│   ├── configure-rbac.ps1          # RBAC for SRE Agent across all 3 RGs
│   └── run-chaos-scenarios.ps1     # Chaos Studio experiment orchestration
├── docs/                           # Documentation
│   ├── BREAKABLE-SCENARIOS.md      # All 10 scenarios detail
│   ├── CHAOS-AND-SRE-GUIDE.md     # Consolidated chaos + SRE prompts guide
│   ├── SRE-AGENT-SETUP.md         # SRE Agent configuration
│   ├── PROMPTS-GUIDE.md           # Curated SRE Agent prompts
│   ├── SRE-AGENT-PROMPTS.md       # Full prompt library by discipline
│   └── COSTS.md                   # Cost breakdown
└── .devcontainer/                  # Dev container configuration
```

## Chaos Studio Experiments

Six scenarios are automated via Azure Chaos Studio and triggered with `run-chaos-scenarios.ps1`:

| Experiment | Target | Fault Type |
|---|---|---|
| `chaos-*-oom-killed` | order-service | Memory stress → OOMKilled |
| `chaos-*-crash-loop` | product-service | Pod kill → CrashLoopBackOff |
| `chaos-*-high-cpu` | order-service | CPU stress → throttling |
| `chaos-*-probe-failure` | HTTP endpoints | HTTP 500 → liveness probe failure |
| `chaos-*-mongodb-down` | mongodb | Database offline → cascading failure |
| `chaos-*-service-mismatch` | order-service | Selector change → zero endpoints |

Four additional scenarios use kubectl manifests in `k8s/scenarios/`:
- `image-pull-backoff.yaml` — bad image reference
- `pending-pods.yaml` — impossible resource requests
- `network-block.yaml` — NetworkPolicy blocks ingress
- `missing-config.yaml` — non-existent ConfigMap reference

## Common Operations

### Deploy Infrastructure
```powershell
.\scripts\deploy.ps1 -Location centralus -Yes
```

### Trigger a Chaos Experiment
```powershell
.\scripts\run-chaos-scenarios.ps1 -Scenario oom-killed -Action start -ResourceGroupName <infraRG>
.\scripts\run-chaos-scenarios.ps1 -Scenario list   # List all available scenarios
```

### Apply a kubectl Scenario
```bash
kubectl apply -f k8s/scenarios/image-pull-backoff.yaml
```

### Restore Healthy State
```bash
kubectl apply -f k8s/base/application.yaml
```

### Configure RBAC for SRE Agent (all 3 RGs)
```powershell
.\scripts\configure-rbac.ps1 -InfraRG <aksRG> -MonitoringRG <monRG> -SreAgentRG <sreRG>
```

### Destroy Infrastructure
```powershell
.\scripts\destroy.ps1 -InfraRGName <aksRG> -MonitoringRGName <monRG> -SreAgentRGName <sreRG>
```

### SRE Agent
SRE Agent deploys via Bicep (`Microsoft.App/agents@2025-05-01-preview`) to East US 2.
- Portal: https://aka.ms/sreagent/portal
- **Critical**: Both the user-assigned identity AND the system-assigned identity need RBAC across all 3 RGs. Run `configure-rbac.ps1` after deployment.

### SRE Agent Starter Prompts

For AKS issues:
- "Why are pods crashing in the pets namespace?"
- "Show me the health status of my AKS cluster"
- "What's causing high CPU usage on my nodes?"

For general diagnosis:
- "What issues are affecting my application?"
- "Trace the dependency chain — what broke first?"

## Important Constraints

1. **SRE Agent Regions**: SRE Agent only deploys to eastus2, swedencentral, or australiaeast
2. **AKS Region**: AKS can deploy to any region (default: centralus)
3. **AKS Networking**: Must NOT be private cluster for SRE Agent access
4. **Authentication**: Use device code auth in dev containers (`az login --use-device-code`)
5. **RBAC**: Both system-assigned and user-assigned identities on SRE Agent need Reader + AKS roles across all 3 RGs
6. **Action Groups**: Must use `location: 'global'` (not a regional location)
7. **Chaos Studio**: Experiments depend on AKS cluster — ensure cluster is fully deployed before running

## Cost Considerations

- **Full deployment with SRE Agent**: ~$32-38/day (~$950-1,150/month)
- **Chaos Studio**: $0-5/month (pay-per-experiment-minute)
- **See**: `docs/COSTS.md` for detailed breakdown

## When Helping with This Project

1. **For Bicep changes**: Follow modular patterns in `infra/bicep/modules/`, deploy to correct RG scope
2. **For K8s manifests**: Use namespace `pets`, label with `sre-demo: breakable`
3. **For scripts**: Use PowerShell, include error handling, support `-WhatIf`
4. **For docs**: Keep formatting consistent, include code examples
5. **For new scenarios**: Add Chaos Studio experiments to `chaos-studio.bicep` or kubectl manifests to `k8s/scenarios/`, and update `docs/BREAKABLE-SCENARIOS.md` and `docs/CHAOS-AND-SRE-GUIDE.md`
6. **For new alerts**: Add to `alert-rules.bicep`, deploy to monitoring RG

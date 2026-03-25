# Azure SRE Agent Demo Lab with Chaos Engineering 🔧

A fully automated Azure environment for demonstrating **Azure SRE Agent** capabilities with **Chaos Studio** fault injection. Deploy a breakable multi-service application on AKS, inject failures automatically, and let SRE Agent diagnose and fix the issues!

## What This Lab Provides

- **Azure Kubernetes Service (AKS)** with a multi-pod e-commerce demo application (Pet Store)
- **10 breakable scenarios** — 6 automated via Chaos Studio, 4 via kubectl manifests
- **Azure SRE Agent** deployed automatically via Bicep for AI-powered diagnostics
- **Azure Chaos Studio** experiments pre-provisioned for automated fault injection
- **Full observability stack**: Log Analytics, Application Insights, Managed Grafana, Prometheus
- **Pre-built dashboards**: Azure Portal dashboard + Grafana dashboards (Operations & Logs)
- **3-resource-group architecture** with enterprise naming conventions
- **Ready-to-use scripts** for deployment, RBAC, chaos scenarios, validation, and teardown

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                     Azure Subscription                              │
│                                                                     │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐  │
│  │  Infra RG         │  │  Monitor RG       │  │  SRE Agent RG    │  │
│  │  (Central US)     │  │  (Central US)     │  │  (East US 2)     │  │
│  │                   │  │                   │  │                  │  │
│  │  • AKS Cluster    │  │  • Log Analytics  │  │  • SRE Agent     │  │
│  │  • ACR             │  │  • App Insights   │  │                  │  │
│  │  • Key Vault       │  │  • Grafana        │  │                  │  │
│  │  • VNet / Subnets  │  │  • Prometheus     │  │                  │  │
│  │  • Chaos Studio    │  │  • Action Group   │  │                  │  │
│  │                   │  │  • Alert Rules     │  │                  │  │
│  │                   │  │  • Portal Dashboard│  │                  │  │
│  └──────────────────┘  └──────────────────┘  └──────────────────┘  │
│                                                                     │
│  ┌──────────────────┐                                               │
│  │  AKS Node RG      │  (auto-managed by Azure)                    │
│  │  MC_<infraRG>_...  │                                             │
│  └──────────────────┘                                               │
└─────────────────────────────────────────────────────────────────────┘
```

## Quick Start

### Prerequisites

- Azure subscription with Owner access
- [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli) v2.80+
- PowerShell 7+ or Windows PowerShell
- [kubectl](https://kubernetes.io/docs/tasks/tools/) installed

### Deploy

```powershell
# 1. Login to Azure
az login --use-device-code

# 2. Deploy infrastructure (~15-25 minutes)
cd scripts
.\deploy.ps1 -Location centralus -Yes

# 3. Configure RBAC (run after deployment)
.\configure-rbac.ps1 -ResourceGroupName <infraRG> -MonitorResourceGroupName <monRG> -SreResourceGroupName <sreRG>

# 4. Get AKS credentials and deploy the application
az aks get-credentials --resource-group <infraRG> --name aks-<workloadName>
kubectl apply -f ../k8s/base/application.yaml
```

> **Note**: SRE Agent requires specific regions (`eastus2`, `swedencentral`, `australiaeast`). The lab deploys AKS to your chosen location and SRE Agent to `eastus2` by default.

### Customize Resource Group Names

Resource groups follow an enterprise naming convention by default: `{ENV}-{PROJECT}-{WORKLOAD}-{REGION}-RG`. You can override them in [infra/bicep/main.bicepparam](infra/bicep/main.bicepparam) or via CLI parameters:

```powershell
.\deploy.ps1 -Location centralus `
  -InfraResourceGroupName "MY-INFRA-RG" `
  -MonitorResourceGroupName "MY-MON-RG" `
  -SreResourceGroupName "MY-SRE-RG"
```

## Chaos Engineering Scenarios

### Automated (Chaos Studio)

These scenarios use pre-provisioned Azure Chaos Studio experiments:

```powershell
# Run a single scenario
.\run-chaos-scenarios.ps1 -Scenario oom-killed -Action start -ResourceGroupName <infraRG>

# List all available scenarios
.\run-chaos-scenarios.ps1 -Scenario list

# Run all Chaos Studio scenarios sequentially
.\run-chaos-scenarios.ps1 -Scenario all-chaos -Action start -ResourceGroupName <infraRG>
```

### Manual (kubectl)

```bash
# Apply a manifest-based scenario
kubectl apply -f k8s/scenarios/image-pull-backoff.yaml

# Restore healthy state
kubectl apply -f k8s/base/application.yaml
```

### All 10 Scenarios

| # | Scenario | Method | Description | SRE Agent Diagnoses |
|---|----------|--------|-------------|---------------------|
| 1 | OOMKilled | Chaos Studio | Memory stress on pods | Memory exhaustion, limit recommendations |
| 2 | CrashLoop | Chaos Studio | Pod kill causing restarts | Exit codes, log analysis |
| 3 | ImagePullBackOff | kubectl | Invalid image reference | Registry/image troubleshooting |
| 4 | HighCPU | Chaos Studio | CPU stress on pods | Performance analysis |
| 5 | PendingPods | kubectl | Insufficient resources | Scheduling analysis |
| 6 | ProbeFailure | Chaos Studio | Health endpoints return 500 | Probe configuration |
| 7 | NetworkBlock | kubectl | NetworkPolicy blocking traffic | Connectivity analysis |
| 8 | MissingConfig | kubectl | Non-existent ConfigMap | Configuration troubleshooting |
| 9 | MongoDBDown | Chaos Studio | Database offline | Dependency tracing, root cause |
| 10 | ServiceMismatch | Chaos Studio | Wrong Service selector | Endpoint/selector analysis |

## Using SRE Agent

After deployment:

1. Open the **SRE Agent Portal** at [aka.ms/sreagent/portal](https://aka.ms/sreagent/portal)
2. Select your SRE Agent resource
3. Run a chaos scenario, then ask SRE Agent to diagnose:
   - *"Why are pods crashing in the pets namespace?"*
   - *"What's causing high CPU usage on order-service?"*
   - *"Diagnose the CrashLoopBackOff error"*
   - *"Show me the root cause of the MongoDB failures"*

See [docs/SRE-AGENT-SETUP.md](docs/SRE-AGENT-SETUP.md) for detailed setup and [docs/PROMPTS-GUIDE.md](docs/PROMPTS-GUIDE.md) for a full prompt catalog.

## Dashboards

### Azure Portal Dashboard
Deployed automatically — includes cluster health, pod status, container restart trends, OOM/CrashLoop events, memory/network pressure, and quick links to Grafana.

### Grafana Dashboards
Two pre-built dashboards are included in the `grafana/` directory:

| Dashboard | Data Source | Panels |
|-----------|------------|--------|
| **AKS Operations** (`sre-demo-dashboard.json`) | Prometheus | CPU/Memory usage, Pod health, Network I/O, Chaos impact |
| **Logs & Alerts** (`sre-demo-logs-dashboard.json`) | Azure Monitor | Failure events, Non-running pods, Restart trends, Top consumers |

Import via Grafana UI or API after deployment.

## Cost Estimate

| Configuration | Daily Cost | Monthly Cost |
|--------------|------------|--------------|
| Default deployment | ~$22-28 | ~$650-850 |
| + SRE Agent | ~$32-38 | ~$950-1,150 |

See [docs/COSTS.md](docs/COSTS.md) for detailed breakdown and optimization tips.

## Project Structure

```
├── infra/bicep/              # Infrastructure as Code
│   ├── main.bicep            # Orchestrator (subscription-scoped)
│   ├── main.bicepparam       # Parameter file
│   └── modules/
│       ├── aks.bicep          # AKS cluster + node pools
│       ├── observability.bicep # Grafana + Prometheus
│       ├── chaos-studio.bicep  # 6 Chaos experiments
│       ├── dashboard.bicep     # Azure Portal dashboard
│       ├── sre-agent.bicep     # SRE Agent
│       ├── alerts.bicep        # 7 alert rules
│       └── ...                 # Network, ACR, KV, etc.
├── k8s/
│   ├── base/application.yaml  # Healthy Pet Store app
│   └── scenarios/             # 10 breakable scenario manifests
├── grafana/                   # Grafana dashboard JSON exports
├── scripts/
│   ├── deploy.ps1             # One-click deployment
│   ├── configure-rbac.ps1     # RBAC role assignments
│   ├── run-chaos-scenarios.ps1 # Chaos scenario orchestration
│   ├── validate-deployment.ps1 # Health checks
│   └── destroy.ps1            # Teardown
└── docs/                      # Setup guides and prompt catalogs
```

## Scripts Reference

| Script | Description |
|--------|-------------|
| `deploy.ps1` | Deploy all infrastructure (Bicep) + optional RBAC |
| `configure-rbac.ps1` | Assign RBAC roles for SRE Agent and current user |
| `run-chaos-scenarios.ps1` | Start/stop/check Chaos Studio experiments and kubectl scenarios |
| `validate-deployment.ps1` | Verify resources, AKS, pods, and connectivity |
| `destroy.ps1` | Tear down all resource groups |

## Documentation

- [SRE Agent Setup Guide](docs/SRE-AGENT-SETUP.md)
- [Breakable Scenarios Guide](docs/BREAKABLE-SCENARIOS.md)
- [Prompts Guide](docs/PROMPTS-GUIDE.md)
- [SRE Agent Prompts](docs/SRE-AGENT-PROMPTS.md)
- [Cost Estimation](docs/COSTS.md)

## Contributing

Contributions welcome! Feel free to open issues or submit PRs.

## License

MIT License — see [LICENSE](LICENSE) for details.

---

**Important Notes:**

- SRE Agent is currently in **Preview**
- SRE Agent is available in **East US 2**, **Sweden Central**, and **Australia East**
- AKS cluster must **not** be a private cluster for SRE Agent access
- Chaos Studio experiments require the AKS cluster to have the Chaos target extension enabled (handled by the Bicep deployment)
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-03-25

### Added
- **3-Resource Group Architecture**: Infra (AKS, ACR, KV, VNet), Monitor (Log Analytics, App Insights, Grafana, Prometheus), and SRE Agent in separate resource groups with enterprise naming conventions.
- **Azure Chaos Studio Integration**: 6 pre-provisioned chaos experiments (OOM, CrashLoop, HighCPU, ProbeFailure, MongoDBDown, ServiceMismatch) deployable via Bicep.
- **Chaos Scenario Orchestration Script** (`run-chaos-scenarios.ps1`): Unified CLI for all 10 breakable scenarios with start/stop/status actions.
- **Grafana Dashboards**: AKS Operations dashboard (Prometheus, 20 panels) and Logs & Alerts dashboard (Azure Monitor, 10 panels).
- **Azure Portal Dashboard** (`dashboard.bicep`): Cluster overview, pod health, container restart trends, OOM & CrashLoop events, memory/network pressure, and Grafana quick links.
- **Prometheus Monitoring**: Azure Monitor managed Prometheus with data collection rules and endpoint associations across resource groups.
- **Alert Rules**: 7 baseline alert rules for CPU, memory, pod restarts, OOMKilled events, node readiness, pending pods, and container failures.
- **Configurable Resource Group Names**: Override default enterprise naming via parameters or CLI flags.
- **RBAC Configuration Script** (`configure-rbac.ps1`): Assigns roles for SRE Agent managed identity and current user across all 3 resource groups.
- **Deployment Validation Script** (`validate-deployment.ps1`): Health checks for Azure resources, AKS cluster, pods, and services.
- **10 Breakable Scenarios**: OOMKilled, CrashLoop, ImagePullBackOff, HighCPU, PendingPods, ProbeFailure, NetworkBlock, MissingConfig, MongoDBDown, ServiceMismatch.
- **Pet Store Application**: Multi-service e-commerce demo (store-front, order-service, product-service, makeline-service, store-admin, ai-service, virtual-customer, virtual-worker, rabbitmq, mongodb).

### Infrastructure
- AKS with system + user node pools (Standard_D2s_v6)
- Azure Container Registry with AcrPull role for AKS
- Key Vault with RBAC authorization
- Virtual Network with dedicated subnets for AKS and services
- Application Insights with Log Analytics workspace integration
- Managed Grafana with Prometheus and Azure Monitor data sources
- Azure SRE Agent (deployed to East US 2 by default)

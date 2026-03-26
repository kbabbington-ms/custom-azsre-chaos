# M365 Copilot Prompt — Video Series Creation

> Copy everything below the line into M365 Copilot.

---

**Context: What This Project Is**

I have built a fully automated Azure demo lab called "Azure SRE Agent with Chaos Engineering". It is a hands-on environment that demonstrates how **Azure SRE Agent** (an AI-powered site reliability engineering tool, currently in Preview) can diagnose and remediate real Kubernetes failures that are injected by **Azure Chaos Studio**.

**Technical Architecture (deeply detailed):**

The entire lab deploys via **Bicep** (Azure's Infrastructure as Code language) as a single subscription-scoped deployment that provisions **3 resource groups** following enterprise naming conventions (`{ENV}-{PROJECT}-{WORKLOAD}-{REGION}-RG`):

1. **Infrastructure RG (Central US)**: Azure Kubernetes Service (AKS) cluster with Standard_D2s_v6 nodes (system pool: 2 nodes, user pool: 3 nodes, Kubernetes 1.32), Azure Container Registry (ACR) with AcrPull RBAC for AKS, Azure Key Vault with RBAC authorization mode, a Virtual Network with dedicated subnets, and **6 Azure Chaos Studio experiments** pre-provisioned as Bicep resources that target AKS workloads.

2. **Monitoring RG (Central US)**: Log Analytics workspace, Application Insights, Azure Managed Grafana (with both Prometheus and Azure Monitor data sources), Azure Monitor managed Prometheus with data collection rules/endpoint associations, 7 metric/log-based alert rules (CPU, memory, pod restarts, OOMKilled events, node readiness, pending pods, container failures), an Action Group, and an Azure Portal dashboard with 6 blade sections (cluster overview, pod health, container restarts, OOM/CrashLoop events, memory/network pressure, and Grafana quick links).

3. **SRE Agent RG (East US 2)**: Azure SRE Agent resource (`Microsoft.App/agents@2025-05-01-preview`) — deployed to East US 2 because SRE Agent is only available in East US 2, Sweden Central, and Australia East. It has both a user-assigned managed identity and a system-assigned managed identity, both requiring RBAC (Reader, AKS RBAC Cluster Admin, Monitoring Reader, Log Analytics Reader) across all 3 resource groups.

**The Application**: A **Pet Store** e-commerce demo running 12 pods across 10 microservices in the `pets` Kubernetes namespace: store-front, order-service, product-service, makeline-service, store-admin, ai-service, virtual-customer, virtual-worker, RabbitMQ (message queue), and MongoDB (database). Services communicate over ClusterIP services and RabbitMQ queues, with MongoDB providing persistence for the order pipeline.

**The 10 Breakable Scenarios** — each simulates a real-world Kubernetes failure pattern:

*6 Automated via Azure Chaos Studio (triggered via a PowerShell orchestration script `run-chaos-scenarios.ps1`):*
- **OOMKilled** — Memory stress on order-service pods until the Linux OOM Killer terminates the container
- **CrashLoopBackOff** — Repeated pod kills on product-service causing exponential back-off
- **High CPU** — CPU stress injection causing throttling and degraded response times
- **Probe Failure** — HTTP 500 injection on health endpoints causing liveness probe failures and unnecessary restarts
- **MongoDB Down** — Database pod termination creating a cascading failure (makeline-service loses its data store, orders queue in RabbitMQ, requires multi-hop root cause analysis)
- **Service Mismatch** — Service selector changed to a non-existent label, resulting in zero endpoints. Pods are all Running/Ready, no errors, no restarts — the most deceptive failure because everything *looks* healthy but orders silently fail.

*4 Manual via kubectl manifests:*
- **ImagePullBackOff** — Bad container image reference
- **Pending Pods** — Resource requests (32Gi memory, 8 CPU) that no node can satisfy
- **Network Block** — NetworkPolicy that blocks all ingress to order-service
- **Missing Config** — Reference to a non-existent ConfigMap causing ContainerCreateError

**The SRE Agent Workflow**: After injecting a failure, you navigate to the Azure SRE Agent portal (https://aka.ms/sreagent/portal) and use natural language prompts to diagnose the issue. The prompts are designed in a layered conversation pattern: Discovery ("something seems wrong with my order-service") → Diagnosis ("why is it restarting?") → Root Cause ("what memory limit should I set?") → Remediation ("increase memory to 256Mi") → Verification ("is it stable now?"). SRE Agent connects to the AKS cluster via its managed identity and runs kubectl commands, queries Azure Monitor, and analyzes logs autonomously.

**Observability**: Two Grafana dashboards provide real-time visibility — an Operations dashboard (20 Prometheus panels covering CPU, memory, network, pod restarts, container states) and a Logs & Alerts dashboard (10 Azure Monitor panels for KQL-based log queries and alert status). An Azure Portal dashboard provides a single-pane view without leaving the Azure Portal.

**The Story Arc**: This lab answers the question: "When things go wrong in production Kubernetes environments, can an AI agent diagnose and fix the problem as well as a senior SRE?" The progression moves from simple, visible failures (OOMKilled — easy to spot) through intermediate challenges (CPU contention, networking policies) to advanced scenarios requiring multi-hop reasoning (MongoDB cascading failure) and silent failures where the AI must go beyond surface-level status checks (Service Mismatch).

---

**My Request:**

Using all of the technical context above, create an outline for a **video series of 5-minute episodes**. Each video must:
- Cover a **complete, self-contained topic** — a viewer can watch any single video and get full value
- **Progress through a narrative arc** when watched in order — building from foundational concepts to advanced demonstrations
- Be exactly 5 minutes — plan the content density accordingly (approximately 750 words of narration per video)
- Include a suggested **title**, **opening hook** (first 15 seconds to grab attention), **key talking points with timestamps**, **on-screen visuals/demos to show**, and a **closing teaser** that bridges to the next episode

**Suggested Episode Structure** (adjust as you see fit):

1. **Episode 1 — The Problem**: Why Kubernetes reliability is hard. The cost of downtime. What SRE teams do today. Introduce the concept of an AI SRE Agent. Show the Pet Store app healthy.
2. **Episode 2 — The Lab**: How the 3-RG architecture works. Walk through the Bicep deployment. Show what gets provisioned. The "one-click deploy" story.
3. **Episode 3 — Breaking Things (Chaos Studio)**: What is chaos engineering? Show Chaos Studio experiments. Trigger OOMKilled live. Watch the failure propagate on the Grafana dashboard.
4. **Episode 4 — AI Diagnosis (SRE Agent in Action)**: Live demo of SRE Agent diagnosing OOMKilled and MongoDB cascading failure. Show the natural language conversation flow. Compare to what a human SRE would do.
5. **Episode 5 — The Hard Ones**: Service Mismatch (everything looks green but nothing works). Show SRE Agent's ability to reason beyond pod status. Network Block scenario. Advanced prompt engineering for SRE.
6. **Episode 6 — Observability Stack**: Grafana dashboards, Prometheus metrics, Azure Monitor alerts, Portal dashboard. How to correlate SRE Agent findings with dashboards.
7. **Episode 7 — Making It Your Own**: How to fork the repo, customize scenarios, add new experiments, extend for your own workloads. Call to action.

For each episode, give me the full outline with timestamps, narration guidance, and specific technical details to show on screen. Reference exact commands, exact scenario names, and exact Azure resource names from the architecture above.

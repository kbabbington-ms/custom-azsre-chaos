# Chaos Engineering & SRE Agent Demo Guide

A consolidated guide that walks through each breakable scenario — how to trigger it, what Chaos Studio does behind the scenes, and exactly what to ask Azure SRE Agent at each step.

## Overview

This lab provides **10 breakable scenarios** that simulate real-world Kubernetes failures. Six are automated through **Azure Chaos Studio** experiments, and four are applied via kubectl manifests. Each scenario is paired with curated **SRE Agent prompts** that demonstrate AI-powered diagnosis and remediation.

### How the Pieces Fit Together

```
┌─────────────────────────────────────────────────────────────────┐
│                     Chaos Engineering Flow                       │
│                                                                 │
│  1. Trigger          2. Observe           3. Diagnose & Fix     │
│  ┌──────────────┐   ┌──────────────┐    ┌──────────────────┐   │
│  │ Chaos Studio │   │ kubectl +    │    │ SRE Agent Portal │   │
│  │ Experiment   │──>│ Dashboards   │──> │ Natural Language  │   │
│  │ (or kubectl) │   │ + Alerts     │    │ Diagnosis + Fix   │   │
│  └──────────────┘   └──────────────┘    └──────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

### Quick Command Reference

```powershell
# List all scenarios
.\scripts\run-chaos-scenarios.ps1 -Scenario list

# Start a Chaos Studio experiment
.\scripts\run-chaos-scenarios.ps1 -Scenario <name> -Action start -ResourceGroupName <infraRG>

# Check experiment status
.\scripts\run-chaos-scenarios.ps1 -Scenario <name> -Action status -ResourceGroupName <infraRG>

# Stop an experiment early
.\scripts\run-chaos-scenarios.ps1 -Scenario <name> -Action stop -ResourceGroupName <infraRG>

# Apply a kubectl scenario
kubectl apply -f k8s/scenarios/<name>.yaml

# Restore healthy state (fixes all kubectl scenarios)
kubectl apply -f k8s/base/application.yaml
```

---

## Scenario 1: OOMKilled - Memory Exhaustion

| | |
|---|---|
| **Method** | Chaos Studio |
| **Experiment** | `chaos-<workloadName>-oom-killed` |
| **Target Service** | order-service |
| **Failure Type** | Memory stress → OOMKilled → pod restarts |
| **Difficulty** | Beginner |

### What Chaos Studio Does
The experiment injects memory stress on order-service pods, consuming memory until the pod exceeds its limit. The Linux OOM Killer terminates the container, Kubernetes restarts it, and the cycle repeats for the experiment duration.

### Trigger
```powershell
.\scripts\run-chaos-scenarios.ps1 -Scenario oom-killed -Action start -ResourceGroupName <infraRG>
```

### What You'll See
```bash
kubectl get pods -n pets -w                    # Pods cycling through OOMKilled → Running → OOMKilled
kubectl describe pod -l app=order-service -n pets  # "Last State: Terminated (OOMKilled)"
```

### SRE Agent Conversation Flow

| Step | Prompt | What SRE Agent Does |
|------|--------|---------------------|
| **Discovery** | *"Something seems wrong with my order-service. Can you take a look?"* | Discovers OOMKilled events, reports restart count |
| **Diagnosis** | *"Why is the order-service pod restarting repeatedly?"* | Identifies memory limit (too low), shows consumption vs. limit |
| **Root Cause** | *"I see OOMKilled events. What memory should I allocate?"* | Analyzes historical usage, recommends appropriate limit |
| **Remediation** | *"Can you increase the memory limit for order-service to 256Mi?"* | Applies the change via kubectl patch |
| **Verification** | *"Is order-service stable now?"* | Confirms no more restarts, resource usage within limits |

### Recovery
Chaos Studio experiments auto-recover. Or restore immediately:
```bash
kubectl apply -f k8s/base/application.yaml
```

---

## Scenario 2: CrashLoopBackOff - Application Crash

| | |
|---|---|
| **Method** | Chaos Studio |
| **Experiment** | `chaos-<workloadName>-crash-loop` |
| **Target Service** | product-service |
| **Failure Type** | Pod kill → CrashLoopBackOff → increasing back-off delay |
| **Difficulty** | Beginner |

### What Chaos Studio Does
The experiment kills the product-service pod process at regular intervals. Kubernetes detects the container exit and restarts it, but the repeated kills cause CrashLoopBackOff with exponentially increasing back-off delays.

### Trigger
```powershell
.\scripts\run-chaos-scenarios.ps1 -Scenario crash-loop -Action start -ResourceGroupName <infraRG>
```

### What You'll See
```bash
kubectl get pods -n pets | grep product-service   # Status: CrashLoopBackOff, high restart count
kubectl logs -l app=product-service -n pets --previous  # Logs from the terminated container
```

### SRE Agent Conversation Flow

| Step | Prompt | What SRE Agent Does |
|------|--------|---------------------|
| **Discovery** | *"My product catalog isn't loading. What's wrong?"* | Finds product-service in CrashLoopBackOff |
| **Diagnosis** | *"Why is product-service in CrashLoopBackOff?"* | Shows exit code, restart timeline, back-off state |
| **Log Analysis** | *"Show me the logs for the crashing product-service pods"* | Retrieves current and previous container logs |
| **Remediation** | *"Restart the product-service deployment"* | Performs rolling restart |
| **Verification** | *"Is product-service healthy now?"* | Confirms pods are Running with 0 restarts |

---

## Scenario 3: ImagePullBackOff - Invalid Image

| | |
|---|---|
| **Method** | kubectl manifest |
| **Target Service** | makeline-service |
| **Failure Type** | Bad image reference → ImagePullBackOff |
| **Difficulty** | Beginner |

### What Happens
The manifest replaces the makeline-service image with a non-existent tag. The kubelet cannot pull the image, and the pod stays in ImagePullBackOff.

### Trigger
```bash
kubectl apply -f k8s/scenarios/image-pull-backoff.yaml
```

### SRE Agent Conversation Flow

| Step | Prompt | What SRE Agent Does |
|------|--------|---------------------|
| **Discovery** | *"Some of my pods won't start. Help?"* | Identifies ImagePullBackOff state on makeline-service |
| **Diagnosis** | *"Why is makeline-service stuck in ImagePullBackOff?"* | Shows the invalid image reference, compares to registry |
| **Remediation** | *"What image should makeline-service be using?"* | Suggests the correct image tag from deployment history |

### Recovery
```bash
kubectl apply -f k8s/base/application.yaml
```

---

## Scenario 4: High CPU - Resource Exhaustion

| | |
|---|---|
| **Method** | Chaos Studio |
| **Experiment** | `chaos-<workloadName>-high-cpu` |
| **Target Service** | order-service |
| **Failure Type** | CPU stress → throttling → slow response times |
| **Difficulty** | Intermediate |

### What Chaos Studio Does
The experiment injects CPU stress, consuming available CPU cycles. This causes throttling on the target pods and can degrade other workloads on the same node due to CPU contention.

### Trigger
```powershell
.\scripts\run-chaos-scenarios.ps1 -Scenario high-cpu -Action start -ResourceGroupName <infraRG>
```

### What You'll See
```bash
kubectl top pods -n pets   # order-service consuming near 100% CPU
kubectl top nodes          # Node CPU pressure may increase
```

### SRE Agent Conversation Flow

| Step | Prompt | What SRE Agent Does |
|------|--------|---------------------|
| **Discovery** | *"My application feels slow. What's going on?"* | Identifies high CPU usage on order-service, correlates with degraded response times |
| **Diagnosis** | *"Which pods are consuming the most CPU?"* | Ranks pods by CPU consumption, shows throttling metrics |
| **Analysis** | *"Analyze CPU usage across all pods and identify contention"* | Maps CPU usage per pod to node capacity, identifies noisy neighbors |
| **Remediation** | *"What should I do to mitigate the CPU issues?"* | Suggests scaling, resource limits, or node pool expansion |

---

## Scenario 5: Pending Pods - Insufficient Resources

| | |
|---|---|
| **Method** | kubectl manifest |
| **Target** | resource-hog deployment |
| **Failure Type** | Impossible resource requests → Pending state |
| **Difficulty** | Intermediate |

### What Happens
Deploys pods requesting 32Gi memory and 8 CPUs — resources that no node in the cluster can satisfy. Pods remain stuck in Pending.

### Trigger
```bash
kubectl apply -f k8s/scenarios/pending-pods.yaml
```

### SRE Agent Conversation Flow

| Step | Prompt | What SRE Agent Does |
|------|--------|---------------------|
| **Discovery** | *"I deployed a new workload but it's not starting"* | Identifies Pending pods, shows scheduling failure reason |
| **Diagnosis** | *"Why are my pods stuck in Pending?"* | Compares requested resources to available node capacity |
| **Analysis** | *"Analyze cluster capacity vs. what's being requested"* | Shows node allocatable resources vs. total requests |
| **Remediation** | *"Should I scale the node pool or reduce resource requests?"* | Recommends appropriate approach based on workload needs |

### Recovery
```bash
kubectl delete deployment resource-hog -n pets
```

---

## Scenario 6: Probe Failure - Health Check Issues

| | |
|---|---|
| **Method** | Chaos Studio |
| **Experiment** | `chaos-<workloadName>-probe-failure` |
| **Target** | HTTP endpoints |
| **Failure Type** | Injected HTTP 500 → liveness probe failure → container restarts |
| **Difficulty** | Intermediate |

### What Chaos Studio Does
The experiment injects HTTP faults that cause health check endpoints to return 500 status codes. Kubernetes liveness probes fail, triggering container restarts. The pods themselves are healthy, but Kubernetes thinks they're not.

### Trigger
```powershell
.\scripts\run-chaos-scenarios.ps1 -Scenario probe-failure -Action start -ResourceGroupName <infraRG>
```

### SRE Agent Conversation Flow

| Step | Prompt | What SRE Agent Does |
|------|--------|---------------------|
| **Discovery** | *"My pods keep restarting but the app looks fine"* | Identifies liveness probe failures despite healthy containers |
| **Diagnosis** | *"Diagnose the health check failures in the pets namespace"* | Shows probe configuration, failure responses, restart correlation |
| **Root Cause** | *"What's wrong with the liveness probe configuration?"* | Distinguishes between app issue and probe misconfiguration |
| **Remediation** | *"How should I fix the probe configuration?"* | Suggests correct endpoint, timeout, and threshold settings |

---

## Scenario 7: Network Block - Connectivity Issues

| | |
|---|---|
| **Method** | kubectl manifest |
| **Target Service** | order-service |
| **Failure Type** | NetworkPolicy blocks ingress → service unreachable |
| **Difficulty** | Intermediate |

### What Happens
A NetworkPolicy is applied that blocks all ingress traffic to order-service. The pods are running and healthy, but no traffic can reach them. This simulates an overly restrictive security policy.

### Trigger
```bash
kubectl apply -f k8s/scenarios/network-block.yaml
```

### SRE Agent Conversation Flow

| Step | Prompt | What SRE Agent Does |
|------|--------|---------------------|
| **Discovery** | *"Orders aren't being processed anymore. What happened?"* | Identifies order-service is unreachable despite healthy pods |
| **Diagnosis** | *"Why can't store-front reach order-service?"* | Discovers blocking NetworkPolicy, shows policy rules |
| **Analysis** | *"Are there any network policies blocking traffic in the pets namespace?"* | Lists all NetworkPolicies, highlights the deny rule |
| **Remediation** | *"Delete the deny-order-service network policy"* | Removes the offending policy, restores connectivity |

### Recovery
```bash
kubectl delete networkpolicy deny-order-service -n pets
```

---

## Scenario 8: Missing Config - Configuration Error

| | |
|---|---|
| **Method** | kubectl manifest |
| **Target** | misconfigured-service deployment |
| **Failure Type** | Non-existent ConfigMap reference → ContainerCreateError |
| **Difficulty** | Beginner |

### What Happens
Deploys a service that references a ConfigMap that doesn't exist. The container can't be created because Kubernetes can't mount the missing configuration.

### Trigger
```bash
kubectl apply -f k8s/scenarios/missing-config.yaml
```

### SRE Agent Conversation Flow

| Step | Prompt | What SRE Agent Does |
|------|--------|---------------------|
| **Discovery** | *"A pod won't start — says something about a missing config?"* | Identifies ContainerCreateError with ConfigMap reference |
| **Diagnosis** | *"What configuration is missing for misconfigured-service?"* | Shows the missing ConfigMap name, lists available ConfigMaps |
| **Remediation** | *"Check for ConfigMap or Secret reference errors in pets namespace"* | Scans all deployments for broken config references |

### Recovery
```bash
kubectl delete deployment misconfigured-service -n pets
```

---

## Scenario 9: MongoDB Down - Cascading Dependency Failure

| | |
|---|---|
| **Method** | Chaos Studio |
| **Experiment** | `chaos-<workloadName>-mongodb-down` |
| **Target Service** | mongodb |
| **Failure Type** | Database offline → cascading failure across dependent services |
| **Difficulty** | Advanced |

### What Chaos Studio Does
The experiment kills the MongoDB pod, taking the database offline. This creates a realistic cascading failure: makeline-service loses its data store, health checks fail, but orders can still be placed (queued in RabbitMQ). The key diagnostic challenge is tracing the dependency chain to find the root cause.

### Trigger
```powershell
.\scripts\run-chaos-scenarios.ps1 -Scenario mongodb-down -Action start -ResourceGroupName <infraRG>
```

### What You'll See
```bash
kubectl get pods -n pets -l app=mongodb              # MongoDB pod terminated/restarting
kubectl get pods -n pets -l app=makeline-service      # Health checks failing
kubectl exec -n pets deploy/rabbitmq -- rabbitmqctl list_queues  # Orders queueing up
```

### SRE Agent Conversation Flow

| Step | Prompt | What SRE Agent Does |
|------|--------|---------------------|
| **Discovery** | *"The app is up but orders aren't going through. What's wrong?"* | Notices makeline-service failing, orders stuck in queue |
| **Diagnosis** | *"Why is makeline-service failing health checks?"* | Identifies database connectivity failure |
| **Root Cause** | *"Trace the dependency chain — what broke first?"* | Traces makeline → mongodb, identifies MongoDB as root cause |
| **Impact** | *"Which services depend on MongoDB and how are they affected?"* | Maps blast radius: makeline-service, order processing pipeline |
| **Remediation** | *"Scale the mongodb deployment back to 1 replica"* | Restores MongoDB, confirms cascading recovery |

### Why This Is the Best Demo Scenario
- Realistic: mimics a real database outage
- Requires multi-hop diagnosis (symptoms ≠ root cause)
- Shows SRE Agent's ability to trace dependencies
- Demonstrates cascading impact analysis

---

## Scenario 10: Service Mismatch - Silent Networking Failure

| | |
|---|---|
| **Method** | Chaos Studio |
| **Experiment** | `chaos-<workloadName>-service-mismatch` |
| **Target Service** | order-service |
| **Failure Type** | Wrong Service selector → zero endpoints → silent failure |
| **Difficulty** | Advanced |

### What Chaos Studio Does
The experiment changes the order-service Service selector to target `app: order-service-v2` (which doesn't exist). The pods continue running perfectly — no crashes, no restarts — but the Service has zero endpoints. Traffic simply never reaches any pod.

### Why This Is Deceptive
- `kubectl get pods` shows all green
- No error events, no restarts, no OOMKills
- The store-front loads fine
- Only placing an order fails silently
- SRE Agent must go beyond pod status and check Service endpoints

### Trigger
```powershell
.\scripts\run-chaos-scenarios.ps1 -Scenario service-mismatch -Action start -ResourceGroupName <infraRG>
```

### What You'll See
```bash
kubectl get pods -n pets -l app=order-service     # All Running, Ready!
kubectl get endpoints order-service -n pets        # <none> — zero endpoints
kubectl get svc order-service -n pets -o yaml      # selector: app: order-service-v2
```

### SRE Agent Conversation Flow

| Step | Prompt | What SRE Agent Does |
|------|--------|---------------------|
| **Discovery** | *"The site loads but placing an order fails. Everything looks healthy though."* | Investigates beyond pod status, checks Service endpoints |
| **Diagnosis** | *"Why does the order-service have no endpoints?"* | Compares Service selector to actual pod labels, finds mismatch |
| **Root Cause** | *"Compare the order-service Service selector to the actual pod labels"* | Shows selector `app: order-service-v2` vs. pods labeled `app: order-service` |
| **Remediation** | *"Fix the selector on the order-service Service to match the pods"* | Patches the Service selector to correct label |

---

## Recommended Demo Flows

### Executive Demo (5 min)
1. Run `mongodb-down` experiment (most business-relatable)
2. Ask SRE Agent: *"Orders aren't going through. What's wrong?"*
3. Watch SRE Agent trace the dependency chain to MongoDB
4. Let experiment auto-recover

### Technical Demo (15 min)
1. **OOMKilled** → SRE Agent diagnoses resource limits
2. **Network Block** → SRE Agent finds restrictive NetworkPolicy
3. **MongoDB Down** → SRE Agent traces cascading failure to root cause
4. Restore with `kubectl apply -f k8s/base/application.yaml`

### Full Workshop (30 min)
1. Show healthy baseline with SRE Agent health check
2. **Round 1** — OOMKilled (Chaos Studio): resource diagnosis
3. **Round 2** — Service Mismatch (Chaos Studio): silent failure investigation
4. **Round 3** — MongoDB Down (Chaos Studio): dependency chain tracing
5. **Round 4** — Network Block (kubectl): connectivity troubleshooting
6. Show Grafana dashboards for observability correlation
7. Discuss proactive monitoring with scheduled SRE Agent tasks

### Tips for Presenters
- **Start vague**: Use prompts like "something seems wrong" to show SRE Agent's discovery capability
- **Layer your questions**: Discovery → Diagnosis → Root Cause → Remediation → Verification
- **Use business language**: "Orders aren't going through" is more impressive than "check pod status"
- **Show the dashboards**: Correlate SRE Agent findings with Grafana/Portal dashboard visuals
- **One scenario at a time**: Don't overlap experiments — wait for recovery before starting the next

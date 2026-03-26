# Breakable Scenarios Guide

This guide explains each failure scenario available in the demo lab, how to trigger them (with Chaos Studio or kubectl), and how to use Azure SRE Agent to diagnose and fix the issues.

## Quick Reference

| # | Scenario | Method | What Breaks | SRE Agent Diagnosis |
|---|----------|--------|-------------|---------------------|
| 1 | OOMKilled | Chaos Studio | Memory exhaustion | Identifies OOM events, recommends memory limits |
| 2 | CrashLoop | Chaos Studio | Pod kill / startup failure | Shows exit codes, logs analysis |
| 3 | ImagePullBackOff | kubectl | Bad image reference | Registry/image troubleshooting |
| 4 | High CPU | Chaos Studio | Resource exhaustion | Performance analysis |
| 5 | Pending Pods | kubectl | Insufficient resources | Scheduling analysis |
| 6 | Probe Failure | Chaos Studio | Health check failure | Probe configuration analysis |
| 7 | Network Block | kubectl | Connectivity issues | Network policy analysis |
| 8 | Missing Config | kubectl | ConfigMap reference | Configuration troubleshooting |
| 9 | MongoDB Down | Chaos Studio | Cascading dependency failure | Dependency tracing, root cause |
| 10 | Service Mismatch | Chaos Studio | Silent networking failure | Endpoint/selector analysis |

## How Scenarios Are Triggered

### Chaos Studio Experiments (Automated)

Six scenarios are pre-provisioned as **Azure Chaos Studio** experiments. These are automated fault injection experiments that:
- Run for a fixed duration (typically 10 minutes)
- Clean up automatically when the experiment ends
- Can be started/stopped/monitored via the orchestration script or Azure Portal

```powershell
# Start a Chaos Studio experiment
.\scripts\run-chaos-scenarios.ps1 -Scenario oom-killed -Action start -ResourceGroupName <infraRG>

# Check experiment status
.\scripts\run-chaos-scenarios.ps1 -Scenario oom-killed -Action status -ResourceGroupName <infraRG>

# Stop an experiment early
.\scripts\run-chaos-scenarios.ps1 -Scenario oom-killed -Action stop -ResourceGroupName <infraRG>

# Run all 6 Chaos Studio experiments sequentially
.\scripts\run-chaos-scenarios.ps1 -Scenario all-chaos -Action start -ResourceGroupName <infraRG>
```

### kubectl Manifests (Manual)

Four scenarios are applied via kubectl manifests. These persist until you manually restore the healthy state:

```bash
# Apply a scenario
kubectl apply -f k8s/scenarios/<scenario>.yaml

# Restore healthy state
kubectl apply -f k8s/base/application.yaml
```

### Listing All Scenarios

```powershell
.\scripts\run-chaos-scenarios.ps1 -Scenario list
```

## Scenario Details

---

### 1. OOMKilled - Out of Memory

**Method:** Chaos Studio | **Experiment:** `chaos-<workloadName>-oom-killed`

**What happens:**
- Chaos Studio injects memory stress on order-service pods
- Pod memory consumption exceeds limits, triggering the OOM Killer
- Kubernetes restarts the pod, cycle repeats during the experiment window

**How to trigger:**
```powershell
.\scripts\run-chaos-scenarios.ps1 -Scenario oom-killed -Action start -ResourceGroupName <infraRG>
```

**What to observe:**
```bash
# Watch pods restart
kubectl get pods -n pets -w

# See OOMKilled status
kubectl describe pod -l app=order-service -n pets | grep -A 5 "Last State"
```

**SRE Agent prompts:**
- "Why is the order-service pod restarting repeatedly?"
- "I see OOMKilled events. What memory should I allocate?"
- "Diagnose the memory issues in the pets namespace"

**How to fix:**
```bash
kubectl apply -f k8s/base/application.yaml
```
> Chaos Studio experiments also auto-recover after their duration expires.

---

### 2. CrashLoopBackOff - Application Crash

**Method:** Chaos Studio | **Experiment:** `chaos-<workloadName>-crash-loop`

**What happens:**
- Chaos Studio kills the product-service pod process repeatedly
- Container exits, Kubernetes restarts it, enters CrashLoopBackOff
- Back-off delay increases with each restart

**How to trigger:**
```powershell
.\scripts\run-chaos-scenarios.ps1 -Scenario crash-loop -Action start -ResourceGroupName <infraRG>
```

**What to observe:**
```bash
# See CrashLoopBackOff status
kubectl get pods -n pets | grep product-service

# Check container logs
kubectl logs -l app=product-service -n pets --previous
```

**SRE Agent prompts:**
- "Why is product-service in CrashLoopBackOff?"
- "Show me the logs for the crashing pods"
- "What's causing exit code 1 in my application?"

**How to fix:**
```bash
kubectl apply -f k8s/base/application.yaml
```

---

### 3. ImagePullBackOff - Invalid Image

**Method:** kubectl manifest

**What happens:**
- Deploys makeline-service referencing a non-existent image tag
- Kubelet can't pull the image from registry
- Pod stays in ImagePullBackOff state

**How to trigger:**
```bash
kubectl apply -f k8s/scenarios/image-pull-backoff.yaml
```

**What to observe:**
```bash
# See ImagePullBackOff status
kubectl get pods -n pets | grep makeline

# Check events
kubectl describe pod -l app=makeline-service -n pets | grep -A 10 Events
```

**SRE Agent prompts:**
- "Why can't my pods start? I see ImagePullBackOff"
- "Help me troubleshoot the container image issue"
- "What's wrong with the makeline-service deployment?"

**How to fix:**
```bash
kubectl apply -f k8s/base/application.yaml
```

---

### 4. High CPU Utilization

**Method:** Chaos Studio | **Experiment:** `chaos-<workloadName>-high-cpu`

**What happens:**
- Chaos Studio injects CPU stress on order-service pods
- Other workloads may slow down due to resource contention
- Alerts may trigger based on CPU threshold rules

**How to trigger:**
```powershell
.\scripts\run-chaos-scenarios.ps1 -Scenario high-cpu -Action start -ResourceGroupName <infraRG>
```

**What to observe:**
```bash
# Watch CPU usage
kubectl top pods -n pets

# Check node pressure
kubectl top nodes
```

**SRE Agent prompts:**
- "My application is slow. What's consuming all the CPU?"
- "Analyze CPU usage across my pods"
- "Which pods are causing resource contention?"

**How to fix:**
The Chaos Studio experiment auto-recovers. To stop early:
```powershell
.\scripts\run-chaos-scenarios.ps1 -Scenario high-cpu -Action stop -ResourceGroupName <infraRG>
```

---

### 5. Pending Pods - Insufficient Resources

**Method:** kubectl manifest

**What happens:**
- Deploys pods requesting 32Gi memory and 8 CPUs each
- No nodes can satisfy these requests
- Pods stay in Pending state indefinitely

**How to trigger:**
```bash
kubectl apply -f k8s/scenarios/pending-pods.yaml
```

**What to observe:**
```bash
# See pending pods
kubectl get pods -n pets | grep resource-hog

# Check events
kubectl describe pod -l app=resource-hog -n pets | grep -A 10 Events
```

**SRE Agent prompts:**
- "Why are my pods stuck in Pending?"
- "I can't schedule new workloads. What's wrong?"
- "Analyze cluster capacity and pending pods"

**How to fix:**
```bash
kubectl delete deployment resource-hog -n pets
```

---

### 6. Failed Liveness Probe

**Method:** Chaos Studio | **Experiment:** `chaos-<workloadName>-probe-failure`

**What happens:**
- Chaos Studio injects HTTP faults causing health endpoints to return 500
- Liveness probes fail, Kubernetes restarts containers
- Pod shows high restart count

**How to trigger:**
```powershell
.\scripts\run-chaos-scenarios.ps1 -Scenario probe-failure -Action start -ResourceGroupName <infraRG>
```

**What to observe:**
```bash
# Watch restarts increase
kubectl get pods -n pets -w

# See probe failure events
kubectl describe pod -n pets | grep -A 5 "Liveness"
```

**SRE Agent prompts:**
- "My pods keep restarting but the app seems fine"
- "Diagnose the health check failures"
- "What's wrong with my liveness probe configuration?"

**How to fix:**
Experiment auto-recovers. To stop early:
```powershell
.\scripts\run-chaos-scenarios.ps1 -Scenario probe-failure -Action stop -ResourceGroupName <infraRG>
```

---

### 7. Network Policy Blocking

**Method:** kubectl manifest

**What happens:**
- Applies NetworkPolicy that blocks all traffic to order-service
- Service becomes unreachable from other pods
- API calls to order-service fail

**How to trigger:**
```bash
kubectl apply -f k8s/scenarios/network-block.yaml
```

**What to observe:**
```bash
# Test connectivity from store-front
kubectl exec -n pets deploy/store-front -- curl -s order-service:3000/health
# Should timeout or fail
```

**SRE Agent prompts:**
- "Why can't store-front reach order-service?"
- "Diagnose network connectivity issues in pets namespace"
- "What network policies are blocking my services?"

**How to fix:**
```bash
kubectl delete networkpolicy deny-order-service -n pets
```

---

### 8. Missing ConfigMap

**Method:** kubectl manifest

**What happens:**
- Deploys service referencing non-existent ConfigMap
- Pod can't start because referenced config doesn't exist
- Shows ContainerCreateError

**How to trigger:**
```bash
kubectl apply -f k8s/scenarios/missing-config.yaml
```

**What to observe:**
```bash
# See the error
kubectl get pods -n pets | grep misconfigured

# Check events
kubectl describe pod -l app=misconfigured-service -n pets | grep -A 10 Events
```

**SRE Agent prompts:**
- "My pod won't start. Says something about ConfigMap?"
- "What configuration is missing for my deployment?"
- "Troubleshoot the ConfigMap reference error"

**How to fix:**
```bash
kubectl delete deployment misconfigured-service -n pets
```

---

### 9. MongoDB Down - Cascading Dependency Failure

**Method:** Chaos Studio | **Experiment:** `chaos-<workloadName>-mongodb-down`

**What happens:**
- Chaos Studio kills the MongoDB pod, taking the database offline
- makeline-service can't connect to MongoDB, starts failing health checks
- Orders can still be placed (queued in RabbitMQ) but never get fulfilled
- This is the most realistic scenario: requires tracing a dependency chain

**How to trigger:**
```powershell
.\scripts\run-chaos-scenarios.ps1 -Scenario mongodb-down -Action start -ResourceGroupName <infraRG>
```

**What to observe:**
```bash
# MongoDB has 0 running pods
kubectl get pods -n pets -l app=mongodb

# makeline-service becomes unhealthy
kubectl get pods -n pets -l app=makeline-service

# Orders queue up in RabbitMQ but never complete
kubectl exec -n pets deploy/rabbitmq -- rabbitmqctl list_queues
```

**SRE Agent prompts:**
- "The app is up but orders aren't going through. What's wrong?"
- "Why is makeline-service failing health checks?"
- "Trace the dependency chain — what broke first?"
- "Scale the mongodb deployment back to 1 replica"

**How to fix:**
```bash
kubectl apply -f k8s/base/application.yaml
```

---

### 10. Service Selector Mismatch - Silent Networking Failure

**Method:** Chaos Studio | **Experiment:** `chaos-<workloadName>-service-mismatch`

**What happens:**
- Replaces the order-service Service with a wrong selector (`app: order-service-v2`)
- The order-service pods are perfectly healthy (Running, Ready)
- But the Service has zero endpoints — traffic doesn't reach any pod
- The store-front loads fine, but placing an order fails silently

**Why this is interesting:**
- All pods show green — no crashes, no restarts, no OOM
- `kubectl get pods` looks completely healthy
- SRE Agent must check Service endpoints and selector labels, not just pod status
- This mimics a common real-world misconfiguration (typo in selector)

**How to trigger:**
```powershell
.\scripts\run-chaos-scenarios.ps1 -Scenario service-mismatch -Action start -ResourceGroupName <infraRG>
```

**What to observe:**
```bash
# Pods are healthy!
kubectl get pods -n pets -l app=order-service

# But the Service has no endpoints
kubectl get endpoints order-service -n pets

# Compare selector vs. pod labels
kubectl get svc order-service -n pets -o jsonpath='{.spec.selector}'
kubectl get pods -n pets -l app=order-service --show-labels
```

**SRE Agent prompts:**
- "The site loads but placing an order fails. Everything looks healthy though."
- "Why does the order-service have no endpoints?"
- "Compare the order-service Service selector to the actual pod labels"
- "Fix the selector on the order-service Service to match the pods"

**How to fix:**
```bash
kubectl apply -f k8s/base/application.yaml
```

---

## Demo Flow Suggestions

### Quick Demo (5 minutes)

1. Start a Chaos Studio experiment (e.g., OOMKilled)
2. Show pods crashing in kubectl
3. Ask SRE Agent to diagnose
4. Show the auto-recovery or apply fix

### Standard Demo (15 minutes)

1. **Chaos Studio automated** — Run `oom-killed` experiment, let SRE Agent diagnose
2. **kubectl manual** — Apply `network-block.yaml`, ask SRE Agent about connectivity
3. **Cascading failure** — Run `mongodb-down` experiment, show dependency tracing
4. **Restore** — Apply `k8s/base/application.yaml`

### Comprehensive Demo (30 minutes)

1. **Introduction** — Show healthy application, SRE Agent baseline health check
2. **Resource issues** — OOMKilled (Chaos Studio) → SRE Agent diagnosis → fix
3. **Connectivity** — Network Policy (kubectl) → SRE Agent connectivity analysis → fix
4. **Application errors** — CrashLoopBackOff (Chaos Studio) → SRE Agent log analysis → fix
5. **Silent failure** — Service Mismatch (Chaos Studio) → SRE Agent endpoint analysis → fix
6. **Cascading failure** — MongoDB Down (Chaos Studio) → SRE Agent dependency tracing → fix
7. **Proactive** — Show scheduled monitoring task, dashboard review
8. **Cleanup** — Restore all scenarios with `kubectl apply -f k8s/base/application.yaml`

## Best Practices

- Always have baseline metrics before breaking things (check dashboards first)
- Have fix commands ready before starting a demo
- Don't apply multiple breaking scenarios simultaneously
- Don't leave scenarios running unattended
- Chaos Studio experiments auto-recover; kubectl scenarios need manual cleanup
- Use `run-chaos-scenarios.ps1 -Scenario list` to see all available scenarios

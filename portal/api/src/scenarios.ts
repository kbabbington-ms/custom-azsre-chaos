import { Scenario } from './types';

const WORKLOAD_NAME = process.env.WORKLOAD_NAME || 'srelab';

export const scenarios: Scenario[] = [
  // ─── Chaos Studio Experiments (6) ───────────────────────────────────
  {
    name: 'oom-killed',
    displayName: 'OOM Killed',
    type: 'chaos',
    description: 'Memory stress on order-service pods causing OOMKilled restarts',
    target: 'order-service',
    difficulty: 'Beginner',
    experimentName: `chaos-${WORKLOAD_NAME}-oom-killed`,
    durationMinutes: 10,
    srePrompts: [
      'Why is the order-service pod restarting repeatedly?',
      'I see OOMKilled events. What memory should I allocate?',
    ],
    expectedAlerts: [
      'CrashLoop/OOM detected (crashloop-oom)',
      'Pod restart spike (pod-restarts)',
    ],
  },
  {
    name: 'crash-loop',
    displayName: 'Crash Loop',
    type: 'chaos',
    description: 'Pod kill on product-service triggering CrashLoopBackOff',
    target: 'product-service',
    difficulty: 'Beginner',
    experimentName: `chaos-${WORKLOAD_NAME}-crash-loop`,
    durationMinutes: 10,
    srePrompts: [
      'Why is product-service in CrashLoopBackOff?',
      'Show me the logs for the crashing pods',
    ],
    expectedAlerts: [
      'Pod restart spike (pod-restarts)',
      'CrashLoop/OOM detected (crashloop-oom)',
    ],
  },
  {
    name: 'high-cpu',
    displayName: 'High CPU',
    type: 'chaos',
    description: 'CPU stress on store-front pods causing resource exhaustion',
    target: 'store-front',
    difficulty: 'Intermediate',
    experimentName: `chaos-${WORKLOAD_NAME}-high-cpu`,
    durationMinutes: 10,
    srePrompts: [
      'My application is slow. What is consuming all the CPU?',
      'Analyze CPU usage across my pods',
    ],
    expectedAlerts: [
      'High CPU utilization (high-cpu)',
    ],
  },
  {
    name: 'probe-failure',
    displayName: 'Probe Failure',
    type: 'chaos',
    description: 'HTTP fault injection — store-admin health endpoints return 500 errors',
    target: 'store-admin',
    difficulty: 'Intermediate',
    experimentName: `chaos-${WORKLOAD_NAME}-probe-failure`,
    durationMinutes: 10,
    srePrompts: [
      'My pods keep restarting but the app seems fine',
      'Diagnose the health check failures',
    ],
    expectedAlerts: [
      'Liveness/readiness probe failures (probe-failure)',
      'Pod restart spike (pod-restarts)',
    ],
  },
  {
    name: 'network-block',
    displayName: 'Network Block',
    type: 'chaos',
    description: 'Network partition blocking makeline-service traffic',
    target: 'makeline-service',
    difficulty: 'Advanced',
    experimentName: `chaos-${WORKLOAD_NAME}-network-block`,
    durationMinutes: 10,
    srePrompts: [
      "Why can't store-front reach order-service?",
      'Diagnose network connectivity issues in pets namespace',
    ],
    expectedAlerts: [
      'Network errors / containers not ready (network-container-errors)',
      'HTTP 5xx / application errors (http-5xx)',
    ],
  },
  {
    name: 'mongodb-down',
    displayName: 'MongoDB Down',
    type: 'chaos',
    description: 'Pod kill on mongodb causing cascading dependency failure',
    target: 'mongodb',
    difficulty: 'Advanced',
    experimentName: `chaos-${WORKLOAD_NAME}-mongodb-down`,
    durationMinutes: 10,
    srePrompts: [
      "The app is up but orders aren't going through. What's wrong?",
      'Trace the dependency chain — what broke first?',
    ],
    expectedAlerts: [
      'Failed or pending pods (pod-failures)',
      'Pod restart spike (pod-restarts)',
      'HTTP 5xx / application errors (http-5xx)',
    ],
  },

  // ─── Kubectl Scenarios (4) ──────────────────────────────────────────
  {
    name: 'image-pull-backoff',
    displayName: 'Image Pull BackOff',
    type: 'kubectl',
    description: 'Deploy bad image reference causing ImagePullBackOff on makeline-service',
    target: 'makeline-service',
    difficulty: 'Beginner',
    scenarioFile: 'image-pull-backoff.yaml',
    fixCommand: 'apply-baseline',
    srePrompts: [
      "Why can't my pods start? I see ImagePullBackOff",
      'Help me troubleshoot the container image issue',
    ],
    expectedAlerts: [
      'Network errors / containers not ready (network-container-errors)',
      'HTTP 5xx / application errors (http-5xx)',
    ],
  },
  {
    name: 'pending-pods',
    displayName: 'Pending Pods',
    type: 'kubectl',
    description: 'Deploy pods requesting impossible resources — stuck in Pending',
    target: 'resource-hog',
    difficulty: 'Beginner',
    scenarioFile: 'pending-pods.yaml',
    fixCommand: 'delete-deployment:resource-hog',
    srePrompts: [
      'Why are my pods stuck in Pending?',
      'Analyze cluster capacity and pending pods',
    ],
    expectedAlerts: [
      'Failed or pending pods (pod-failures)',
      'HTTP 5xx / application errors (http-5xx)',
    ],
  },
  {
    name: 'missing-config',
    displayName: 'Missing Config',
    type: 'kubectl',
    description: 'Deploy with non-existent ConfigMap reference — pods fail to start',
    target: 'misconfigured-service',
    difficulty: 'Intermediate',
    scenarioFile: 'missing-config.yaml',
    fixCommand: 'delete-deployment:misconfigured-service',
    srePrompts: [
      "My pod won't start. Says something about ConfigMap?",
      'What configuration is missing for my deployment?',
    ],
    expectedAlerts: [
      'HTTP 5xx / application errors (http-5xx)',
      'Network errors / containers not ready (network-container-errors)',
    ],
  },
  {
    name: 'service-mismatch',
    displayName: 'Service Mismatch',
    type: 'kubectl',
    description: 'Wrong Service selector — silent networking failure, orders fail',
    target: 'order-service',
    difficulty: 'Advanced',
    scenarioFile: 'service-mismatch.yaml',
    fixCommand: 'apply-baseline',
    srePrompts: [
      'The site loads but placing an order fails. Everything looks healthy.',
      'Why does the order-service have no endpoints?',
    ],
    expectedAlerts: [
      'No direct alert — silent failure (requires investigation)',
    ],
  },
];

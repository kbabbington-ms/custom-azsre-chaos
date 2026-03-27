export type ScenarioType = 'chaos' | 'kubectl';
export type ScenarioDifficulty = 'Beginner' | 'Intermediate' | 'Advanced';

export interface Scenario {
  name: string;
  displayName: string;
  type: ScenarioType;
  description: string;
  target: string;
  difficulty: ScenarioDifficulty;
  experimentName?: string;       // Chaos Studio experiment name
  scenarioFile?: string;         // kubectl scenario YAML path
  fixCommand?: string;           // kubectl fix command
  srePrompts: string[];
  durationMinutes?: number;      // Chaos Studio experiment duration
  expectedAlerts?: string[];     // Azure Monitor alert rules expected to fire
}

export interface ScenarioStatus {
  name: string;
  status: 'idle' | 'running' | 'success' | 'failed' | 'cancelled' | 'broken' | 'unknown';
  startedAt?: string;
  estimatedEndTime?: string;
  message?: string;
}

export interface PodInfo {
  name: string;
  namespace: string;
  status: string;
  ready: string;
  restarts: number;
  age: string;
  node: string;
}

export interface HealthResponse {
  status: string;
  timestamp: string;
  version: string;
}

export type ActivityLevel = 'info' | 'success' | 'error' | 'warning';

export interface ActivityEntry {
  id: string;
  timestamp: string;
  scenario: string;
  message: string;
  level: ActivityLevel;
}

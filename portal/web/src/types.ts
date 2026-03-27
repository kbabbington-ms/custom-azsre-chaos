export type ScenarioType = 'chaos' | 'kubectl';
export type ScenarioDifficulty = 'Beginner' | 'Intermediate' | 'Advanced';
export type ScenarioStatusValue =
  | 'idle'
  | 'running'
  | 'success'
  | 'failed'
  | 'cancelled'
  | 'broken'
  | 'unknown';

export interface Scenario {
  name: string;
  displayName: string;
  type: ScenarioType;
  description: string;
  target: string;
  difficulty: ScenarioDifficulty;
  experimentName?: string;
  scenarioFile?: string;
  fixCommand?: string;
  srePrompts: string[];
  durationMinutes?: number;
  expectedAlerts?: string[];
}

export interface ScenarioStatus {
  name: string;
  status: ScenarioStatusValue;
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

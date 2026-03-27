import { Scenario, ScenarioStatus, PodInfo } from '../types';
import { ActivityEntry } from '../hooks/useActivityLog';

const API_BASE = '/api';

async function fetchJson<T>(url: string, options?: RequestInit): Promise<T> {
  const res = await fetch(`${API_BASE}${url}`, {
    ...options,
    headers: { 'Content-Type': 'application/json', ...options?.headers },
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`API ${res.status}: ${text}`);
  }
  return res.json();
}

export async function getScenarios(): Promise<Scenario[]> {
  return fetchJson<Scenario[]>('/scenarios');
}

export async function getScenarioStatus(name: string): Promise<ScenarioStatus> {
  return fetchJson<ScenarioStatus>(`/scenarios/${encodeURIComponent(name)}/status`);
}

export async function startScenario(
  name: string
): Promise<{ success: boolean; message: string }> {
  return fetchJson(`/scenarios/${encodeURIComponent(name)}/start`, { method: 'POST' });
}

export async function stopScenario(
  name: string
): Promise<{ success: boolean; message: string }> {
  return fetchJson(`/scenarios/${encodeURIComponent(name)}/stop`, { method: 'POST' });
}

export async function fixAll(): Promise<{ message: string }> {
  return fetchJson('/scenarios/fix-all', { method: 'POST' });
}

export async function getPods(): Promise<PodInfo[]> {
  return fetchJson<PodInfo[]>('/cluster/pods');
}

export async function getActivities(limit = 200): Promise<ActivityEntry[]> {
  const raw = await fetchJson<Array<{ id: string; timestamp: string; scenario: string; message: string; level: string }>>(`/activities?limit=${limit}`);
  return raw.map((r) => ({
    id: Number(r.id.split('-')[0]) || Date.now(),
    timestamp: new Date(r.timestamp),
    scenario: r.scenario,
    message: r.message,
    level: (r.level as ActivityEntry['level']) || 'info',
  }));
}

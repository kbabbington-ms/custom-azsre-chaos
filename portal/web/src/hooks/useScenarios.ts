import { useState, useEffect, useCallback, useRef } from 'react';
import { Scenario, ScenarioStatus, PodInfo } from '../types';
import { getScenarios, getScenarioStatus, getPods } from '../api/client';

export function useScenarios() {
  const [scenarios, setScenarios] = useState<Scenario[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    getScenarios()
      .then(setScenarios)
      .catch(console.error)
      .finally(() => setLoading(false));
  }, []);

  return { scenarios, loading };
}

export function useScenarioStatuses(scenarios: Scenario[], intervalMs = 5000) {
  const [statuses, setStatuses] = useState<Map<string, ScenarioStatus>>(new Map());
  const scenariosRef = useRef(scenarios);
  scenariosRef.current = scenarios;

  const refresh = useCallback(async () => {
    const items = scenariosRef.current;
    if (items.length === 0) return;

    const results = await Promise.allSettled(items.map((s) => getScenarioStatus(s.name)));

    const map = new Map<string, ScenarioStatus>();
    results.forEach((r, i) => {
      if (r.status === 'fulfilled') {
        map.set(items[i].name, r.value);
      }
    });
    setStatuses(map);
  }, []);

  useEffect(() => {
    refresh();
    const id = setInterval(refresh, intervalMs);
    return () => clearInterval(id);
  }, [refresh, intervalMs]);

  return { statuses, refresh };
}

export function usePods(intervalMs = 5000) {
  const [pods, setPods] = useState<PodInfo[]>([]);

  const refresh = useCallback(async () => {
    try {
      const data = await getPods();
      setPods(data);
    } catch (e) {
      console.error('Failed to fetch pods:', e);
    }
  }, []);

  useEffect(() => {
    refresh();
    const id = setInterval(refresh, intervalMs);
    return () => clearInterval(id);
  }, [refresh, intervalMs]);

  return { pods, refresh };
}

import { useState, useCallback } from 'react';
import { getActivities } from '../api/client';

export type ActivityLevel = 'info' | 'success' | 'error' | 'warning';

export interface ActivityEntry {
  id: number;
  timestamp: Date;
  scenario: string;
  message: string;
  level: ActivityLevel;
}

let nextId = 1;

export function useActivityLog() {
  const [entries, setEntries] = useState<ActivityEntry[]>([]);

  const log = useCallback((scenario: string, message: string, level: ActivityLevel = 'info') => {
    setEntries((prev) => [
      { id: nextId++, timestamp: new Date(), scenario, message, level },
      ...prev,
    ].slice(0, 200));
  }, []);

  const clear = useCallback(() => setEntries([]), []);

  const refresh = useCallback(async () => {
    try {
      const stored = await getActivities(200);
      setEntries((prev) => {
        // Merge: keep local entries not yet persisted, prepend stored
        const storedIds = new Set(stored.map((e) => e.scenario + e.message + e.timestamp.getTime()));
        const localOnly = prev.filter((e) => !storedIds.has(e.scenario + e.message + e.timestamp.getTime()));
        return [...localOnly, ...stored].sort((a, b) => b.timestamp.getTime() - a.timestamp.getTime()).slice(0, 200);
      });
    } catch (err) {
      console.warn('Failed to refresh activities:', err);
    }
  }, []);

  return { entries, log, clear, refresh };
}

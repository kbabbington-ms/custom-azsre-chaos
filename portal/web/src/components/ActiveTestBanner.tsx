import { useState, useEffect, useRef } from 'react';
import {
  makeStyles,
  tokens,
  Text,
  Badge,
  PresenceBadge,
} from '@fluentui/react-components';
import { TimerRegular } from '@fluentui/react-icons';
import { Scenario, ScenarioStatus } from '../types';

const useStyles = makeStyles({
  banner: {
    backgroundColor: tokens.colorPaletteRedBackground1,
    borderBottom: `2px solid ${tokens.colorPaletteRedBorder1}`,
    padding: '8px 16px',
    display: 'flex',
    alignItems: 'center',
    gap: '12px',
    flexWrap: 'wrap',
    '@media (max-width: 768px)': {
      padding: '6px 8px',
      gap: '8px',
    },
  },
  label: {
    display: 'flex',
    alignItems: 'center',
    gap: '6px',
    fontWeight: 600,
    whiteSpace: 'nowrap',
  },
  scenarios: {
    display: 'flex',
    gap: '12px',
    flexWrap: 'wrap',
    flex: 1,
  },
  scenarioItem: {
    display: 'flex',
    alignItems: 'center',
    gap: '6px',
    backgroundColor: 'rgba(255,255,255,0.15)',
    borderRadius: '4px',
    padding: '2px 8px',
  },
  timer: {
    display: 'flex',
    alignItems: 'center',
    gap: '4px',
    fontSize: '12px',
    fontFamily: 'Consolas, "Courier New", monospace',
    opacity: 0.9,
  },
});

interface ActiveTestBannerProps {
  activeScenarios: Scenario[];
  statuses: Map<string, ScenarioStatus>;
}

function CountdownTimer({ startedAt, durationMinutes }: { startedAt?: string; durationMinutes?: number }) {
  const [remaining, setRemaining] = useState<number | null>(null);
  const timerRef = useRef<ReturnType<typeof setInterval>>();

  useEffect(() => {
    if (!startedAt || !durationMinutes) {
      setRemaining(null);
      return;
    }

    const endTime = new Date(startedAt).getTime() + durationMinutes * 60 * 1000;

    const tick = () => {
      const r = Math.max(0, Math.floor((endTime - Date.now()) / 1000));
      setRemaining(r);
      if (r <= 0) clearInterval(timerRef.current);
    };

    tick();
    timerRef.current = setInterval(tick, 1000);
    return () => clearInterval(timerRef.current);
  }, [startedAt, durationMinutes]);

  if (remaining === null) return null;

  const m = Math.floor(remaining / 60);
  const s = remaining % 60;

  return (
    <span style={{ display: 'flex', alignItems: 'center', gap: '4px', fontSize: '12px', fontFamily: 'Consolas, "Courier New", monospace' }}>
      <TimerRegular fontSize={14} />
      {m}:{s.toString().padStart(2, '0')}
    </span>
  );
}

export function ActiveTestBanner({ activeScenarios, statuses }: ActiveTestBannerProps) {
  const classes = useStyles();

  if (activeScenarios.length === 0) return null;

  return (
    <div className={classes.banner}>
      <div className={classes.label}>
        <PresenceBadge status="busy" size="small" />
        <Text size={200} weight="semibold">
          {activeScenarios.length === 1 ? 'Active Test' : `${activeScenarios.length} Active Tests`}
        </Text>
      </div>
      <div className={classes.scenarios}>
        {activeScenarios.map((scenario) => {
          const status = statuses.get(scenario.name);
          return (
            <div key={scenario.name} className={classes.scenarioItem}>
              <Badge
                color={scenario.type === 'chaos' ? 'brand' : 'warning'}
                appearance="filled"
                size="small"
              >
                {scenario.type === 'chaos' ? 'Chaos' : 'kubectl'}
              </Badge>
              <Text size={200} weight="semibold">
                {scenario.displayName}
              </Text>
              <Text size={100} style={{ opacity: 0.7 }}>
                → {scenario.target}
              </Text>
              {scenario.type === 'chaos' && status?.status === 'running' && (
                <CountdownTimer
                  startedAt={status.startedAt}
                  durationMinutes={scenario.durationMinutes}
                />
              )}
              {status?.status === 'broken' && (
                <Badge color="danger" appearance="outline" size="small">broken</Badge>
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
}

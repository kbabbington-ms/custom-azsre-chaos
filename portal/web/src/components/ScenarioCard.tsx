import { useState, useCallback, useEffect, useRef } from 'react';
import {
  makeStyles,
  tokens,
  Card,
  CardHeader,
  Text,
  Badge,
  Button,
  Tooltip,
  PresenceBadge,
} from '@fluentui/react-components';
import {
  PlayRegular,
  StopRegular,
  WrenchRegular,
  TimerRegular,
  AlertUrgentRegular,
} from '@fluentui/react-icons';
import { Scenario, ScenarioStatus, ScenarioStatusValue } from '../types';
import { startScenario, stopScenario } from '../api/client';
import { ActivityLevel } from '../hooks/useActivityLog';

const useStyles = makeStyles({
  card: {
    minWidth: '280px',
    maxWidth: '100%',
    flex: '1 1 280px',
    '@media (max-width: 768px)': {
      minWidth: '100%',
      flex: '1 1 100%',
    },
  },
  chaosAccent: {
    borderLeft: `3px solid ${tokens.colorPaletteBlueBorderActive}`,
  },
  kubectlAccent: {
    borderLeft: `3px solid ${tokens.colorPaletteDarkOrangeBorderActive}`,
  },
  body: {
    padding: '0 16px 12px',
  },
  description: {
    display: 'block',
    marginBottom: '8px',
    opacity: 0.8,
  },
  target: {
    display: 'block',
    marginBottom: '8px',
    opacity: 0.6,
  },
  footer: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'space-between',
    padding: '8px 16px 12px',
    gap: '8px',
  },
  badges: {
    display: 'flex',
    gap: '6px',
    alignItems: 'center',
    flexWrap: 'wrap',
  },
  actions: {
    display: 'flex',
    gap: '4px',
  },
  timer: {
    display: 'flex',
    alignItems: 'center',
    gap: '4px',
    fontSize: '12px',
    opacity: 0.7,
  },
  prompts: {
    padding: '4px 16px 8px',
    borderTop: `1px solid ${tokens.colorNeutralStroke2}`,
    listStyleType: 'none',
    margin: 0,
  },
  prompt: {
    fontSize: '12px',
    opacity: 0.6,
    padding: '2px 0',
    '&::before': { content: '">"', marginRight: '6px' },
  },
  alertSection: {
    padding: '4px 16px 8px',
    borderTop: `1px solid ${tokens.colorNeutralStroke2}`,
    margin: 0,
  },
  alertHeader: {
    display: 'flex',
    alignItems: 'center',
    gap: '4px',
    marginBottom: '4px',
  },
  alertList: {
    listStyleType: 'none',
    margin: 0,
    padding: 0,
  },
  alertItem: {
    fontSize: '11px',
    padding: '1px 0',
    color: tokens.colorPaletteRedForeground1,
    '&::before': { content: '"\u26A0"', marginRight: '6px' },
  },
  alertItemSilent: {
    fontSize: '11px',
    padding: '1px 0',
    color: tokens.colorPaletteYellowForeground1,
    '&::before': { content: '"\u2139\uFE0F"', marginRight: '6px' },
  },
});

const statusToPresence: Record<ScenarioStatusValue, 'available' | 'busy' | 'away' | 'offline' | 'unknown'> = {
  idle: 'offline',
  running: 'busy',
  success: 'available',
  failed: 'busy',
  cancelled: 'offline',
  broken: 'away',
  unknown: 'unknown',
};

const difficultyColor: Record<string, 'success' | 'warning' | 'danger'> = {
  Beginner: 'success',
  Intermediate: 'warning',
  Advanced: 'danger',
};

interface ScenarioCardProps {
  scenario: Scenario;
  status?: ScenarioStatus;
  onActionComplete: () => void;
  onLog?: (scenario: string, message: string, level?: ActivityLevel) => void;
  onHover?: (scenario: Scenario) => void;
  onHoverEnd?: () => void;
  isSelected?: boolean;
  onClickCard?: (scenario: Scenario) => void;
}

export function ScenarioCard({ scenario, status, onActionComplete, onLog, onHover, onHoverEnd, isSelected, onClickCard }: ScenarioCardProps) {
  const classes = useStyles();
  const [acting, setActing] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [countdown, setCountdown] = useState<number | null>(null);
  const timerRef = useRef<ReturnType<typeof setInterval>>();
  const prevStatusRef = useRef<ScenarioStatusValue | undefined>();

  const currentStatus = status?.status ?? 'idle';
  const isActive = currentStatus === 'running' || currentStatus === 'broken';

  // Log status transitions
  useEffect(() => {
    const prev = prevStatusRef.current;
    prevStatusRef.current = currentStatus;
    if (!prev || prev === currentStatus) return;

    if (currentStatus === 'running') {
      onLog?.(scenario.displayName, 'Experiment is running — fault injection active', 'info');
    } else if (currentStatus === 'success') {
      onLog?.(scenario.displayName, 'Experiment completed successfully', 'success');
    } else if (currentStatus === 'failed') {
      onLog?.(scenario.displayName, `Experiment failed${status?.message ? ': ' + status.message : ''}`, 'error');
    } else if (currentStatus === 'cancelled') {
      onLog?.(scenario.displayName, 'Experiment cancelled', 'warning');
    } else if (currentStatus === 'broken') {
      onLog?.(scenario.displayName, 'Scenario is active — target is in a broken state', 'warning');
    } else if (currentStatus === 'idle' && prev !== 'idle') {
      onLog?.(scenario.displayName, 'Returned to healthy state', 'success');
    }
  }, [currentStatus, scenario.displayName, status?.message, onLog]);

  // Countdown timer for Chaos Studio experiments
  useEffect(() => {
    if (
      currentStatus === 'running' &&
      scenario.type === 'chaos' &&
      scenario.durationMinutes &&
      status?.startedAt
    ) {
      const endTime =
        new Date(status.startedAt).getTime() + scenario.durationMinutes * 60 * 1000;

      const tick = () => {
        const remaining = Math.max(0, Math.floor((endTime - Date.now()) / 1000));
        setCountdown(remaining);
        if (remaining <= 0) clearInterval(timerRef.current);
      };

      tick();
      timerRef.current = setInterval(tick, 1000);
      return () => clearInterval(timerRef.current);
    } else {
      setCountdown(null);
    }
  }, [currentStatus, status?.startedAt, scenario.type, scenario.durationMinutes]);

  const handleStart = useCallback(async () => {
    setActing(true);
    setError(null);
    onLog?.(scenario.displayName, `Starting ${scenario.type === 'chaos' ? 'Chaos Studio experiment' : 'kubectl scenario'}...`, 'info');
    try {
      const result = await startScenario(scenario.name);
      if (!result.success) {
        setError(result.message);
        onLog?.(scenario.displayName, `Failed to start: ${result.message}`, 'error');
      } else {
        onLog?.(scenario.displayName, 'Initiated successfully — waiting for experiment to begin', 'success');
      }
      onActionComplete();
    } catch (e) {
      const msg = e instanceof Error ? e.message : 'Failed to start scenario';
      setError(msg);
      onLog?.(scenario.displayName, `Error: ${msg}`, 'error');
      console.error(e);
    } finally {
      setActing(false);
    }
  }, [scenario.name, scenario.displayName, scenario.type, onActionComplete, onLog]);

  const handleStop = useCallback(async () => {
    setActing(true);
    setError(null);
    onLog?.(scenario.displayName, `Stopping ${scenario.type === 'chaos' ? 'experiment' : 'scenario'}...`, 'info');
    try {
      const result = await stopScenario(scenario.name);
      if (!result.success) {
        setError(result.message);
        onLog?.(scenario.displayName, `Failed to stop: ${result.message}`, 'error');
      } else {
        onLog?.(scenario.displayName, 'Stop/fix command sent successfully', 'success');
      }
      onActionComplete();
    } catch (e) {
      const msg = e instanceof Error ? e.message : 'Failed to stop scenario';
      setError(msg);
      onLog?.(scenario.displayName, `Error: ${msg}`, 'error');
      console.error(e);
    } finally {
      setActing(false);
    }
  }, [scenario.name, scenario.displayName, scenario.type, onActionComplete, onLog]);

  const fmtTime = (s: number) => {
    const m = Math.floor(s / 60);
    const sec = s % 60;
    return `${m}:${sec.toString().padStart(2, '0')}`;
  };

  return (
    <Card
      className={`${classes.card} ${scenario.type === 'chaos' ? classes.chaosAccent : classes.kubectlAccent}`}
      onMouseEnter={() => onHover?.(scenario)}
      onMouseLeave={() => onHoverEnd?.()}
      onClick={() => onClickCard?.(scenario)}
      style={{ cursor: onClickCard ? 'pointer' : undefined, ...(isSelected ? { outline: '2px solid #e65100', outlineOffset: '-2px', boxShadow: '0 0 8px rgba(230,81,0,0.4)' } : {}) }}
    >
      <CardHeader
        header={
          <Text weight="semibold" size={400}>
            <PresenceBadge
              status={statusToPresence[currentStatus]}
              size="extra-small"
              style={{ marginRight: 8 }}
            />
            {scenario.displayName}
          </Text>
        }
        description={
          <Text size={200} style={{ opacity: 0.6 }}>
            Target: {scenario.target}
          </Text>
        }
      />

      <div className={classes.body}>
        <Text size={200} className={classes.description}>
          {scenario.description}
        </Text>
        {error && (
          <Text size={200} style={{ color: tokens.colorPaletteRedForeground1, display: 'block', marginTop: '4px' }}>
            Error: {error}
          </Text>
        )}
      </div>

      <div className={classes.footer}>
        <div className={classes.badges}>
          <Badge
            color={scenario.type === 'chaos' ? 'brand' : 'warning'}
            appearance="filled"
            size="small"
          >
            {scenario.type === 'chaos' ? 'Chaos Studio' : 'kubectl'}
          </Badge>
          <Badge
            color={difficultyColor[scenario.difficulty]}
            appearance="outline"
            size="small"
          >
            {scenario.difficulty}
          </Badge>
          {countdown !== null && countdown > 0 && (
            <span className={classes.timer}>
              <TimerRegular fontSize={14} />
              {fmtTime(countdown)}
            </span>
          )}
        </div>
        <div className={classes.actions} onClick={(e) => e.stopPropagation()}>
          {isActive ? (
            <Tooltip content={scenario.type === 'chaos' ? 'Cancel experiment' : 'Fix / revert'} relationship="label">
              <Button
                appearance="subtle"
                icon={scenario.type === 'chaos' ? <StopRegular /> : <WrenchRegular />}
                size="small"
                onClick={handleStop}
                disabled={acting}
              >
                {scenario.type === 'chaos' ? 'Stop' : 'Fix'}
              </Button>
            </Tooltip>
          ) : (
            <Tooltip content="Inject failure" relationship="label">
              <Button
                appearance="primary"
                icon={<PlayRegular />}
                size="small"
                onClick={handleStart}
                disabled={acting}
              >
                Start
              </Button>
            </Tooltip>
          )}
        </div>
      </div>

      <ul className={classes.prompts}>
        {scenario.srePrompts.map((p, i) => (
          <li key={i} className={classes.prompt}>
            {p}
          </li>
        ))}
      </ul>

      {scenario.expectedAlerts && scenario.expectedAlerts.length > 0 && (
        <div className={classes.alertSection}>
          <div className={classes.alertHeader}>
            <AlertUrgentRegular fontSize={14} style={{ color: tokens.colorPaletteRedForeground1 }} />
            <Text size={200} weight="semibold" style={{ opacity: 0.8 }}>
              Expected Alert Rules
            </Text>
          </div>
          <ul className={classes.alertList}>
            {scenario.expectedAlerts.map((a, i) => (
              <li
                key={i}
                className={a.includes('No direct alert') ? classes.alertItemSilent : classes.alertItem}
              >
                {a}
              </li>
            ))}
          </ul>
        </div>
      )}
    </Card>
  );
}

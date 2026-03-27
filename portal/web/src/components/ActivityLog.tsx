import { useState, useRef, useEffect } from 'react';
import {
  makeStyles,
  tokens,
  Text,
  Badge,
  Button,
  Tooltip,
} from '@fluentui/react-components';
import {
  ChevronUpRegular,
  ChevronDownRegular,
  DeleteRegular,
  ArrowClockwiseRegular,
} from '@fluentui/react-icons';
import { ActivityEntry, ActivityLevel } from '../hooks/useActivityLog';
import { ResizeHandle } from './ResizeHandle';

const useStyles = makeStyles({
  container: {
    position: 'fixed',
    bottom: 0,
    left: 0,
    right: 0,
    zIndex: 1000,
    backgroundColor: tokens.colorNeutralBackground3,
    borderTop: `2px solid ${tokens.colorNeutralStroke1}`,
    display: 'flex',
    flexDirection: 'column',
    transition: 'height 0.2s ease',
  },
  header: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'space-between',
    padding: '6px 12px',
    cursor: 'pointer',
    userSelect: 'none',
    flexShrink: 0,
    '&:hover': {
      backgroundColor: tokens.colorNeutralBackground3Hover,
    },
    '@media (max-width: 600px)': {
      padding: '4px 8px',
    },
  },
  headerLeft: {
    display: 'flex',
    alignItems: 'center',
    gap: '8px',
  },
  headerActions: {
    display: 'flex',
    alignItems: 'center',
    gap: '4px',
  },
  logArea: {
    overflowY: 'auto',
    flex: 1,
    padding: '0 12px 8px',
    fontFamily: 'Consolas, "Courier New", monospace',
    fontSize: '12px',
    lineHeight: '20px',
    '@media (max-width: 600px)': {
      padding: '0 8px 4px',
      fontSize: '11px',
      lineHeight: '18px',
    },
  },
  entry: {
    display: 'flex',
    gap: '6px',
    padding: '2px 0',
    borderBottom: `1px solid ${tokens.colorNeutralStroke3}`,
    alignItems: 'baseline',
    flexWrap: 'wrap',
    '@media (max-width: 600px)': {
      gap: '4px',
    },
  },
  timestamp: {
    opacity: 0.5,
    whiteSpace: 'nowrap',
    minWidth: '65px',
    '@media (max-width: 600px)': {
      minWidth: 'auto',
      fontSize: '10px',
    },
  },
  scenario: {
    fontWeight: 600,
    whiteSpace: 'nowrap',
    minWidth: '100px',
    '@media (max-width: 600px)': {
      minWidth: 'auto',
    },
  },
  message: {
    flex: 1,
  },
  info: { color: tokens.colorNeutralForeground2 },
  success: { color: tokens.colorPaletteGreenForeground1 },
  error: { color: tokens.colorPaletteRedForeground1 },
  warning: { color: tokens.colorPaletteYellowForeground1 },
  empty: {
    opacity: 0.4,
    textAlign: 'center' as const,
    padding: '16px',
  },
});

const levelIcon: Record<ActivityLevel, string> = {
  info: '\u2139\uFE0F',
  success: '\u2705',
  error: '\u274C',
  warning: '\u26A0\uFE0F',
};

interface ActivityLogProps {
  entries: ActivityEntry[];
  onClear: () => void;
  onRefresh?: () => void;
  height?: number;
  onResizeHeight?: (deltaY: number) => void;
  inline?: boolean;
}

export function ActivityLog({ entries, onClear, onRefresh, height, onResizeHeight, inline }: ActivityLogProps) {
  const classes = useStyles();
  const [expanded, setExpanded] = useState(false);
  const logRef = useRef<HTMLDivElement>(null);
  const prevCountRef = useRef(entries.length);

  // Auto-expand when new entries arrive
  useEffect(() => {
    if (entries.length > prevCountRef.current && !expanded) {
      setExpanded(true);
    }
    prevCountRef.current = entries.length;
  }, [entries.length, expanded]);

  const errorCount = entries.filter((e) => e.level === 'error').length;
  const runningCount = entries.filter(
    (e) => e.level === 'info' && (e.message.includes('Starting') || e.message.includes('Initiated'))
  ).length;

  const fmtTime = (d: Date) =>
    d.toLocaleTimeString('en-US', { hour12: false, hour: '2-digit', minute: '2-digit', second: '2-digit' });

  const isControlled = height !== undefined;
  const effectiveHeight = inline ? undefined : isControlled ? height : expanded ? 220 : 36;
  const isExpanded = inline ? true : isControlled ? height > 40 : expanded;

  return (
    <div
      className={classes.container}
      style={inline
        ? { position: 'static', width: '250px', flexShrink: 0, height: '100%', borderTop: 'none', border: '2px solid var(--colorNeutralStroke1)', borderRadius: '6px 0 0 6px', zIndex: 'auto', transition: 'none' }
        : { height: effectiveHeight }
      }
    >
      {!inline && isControlled && onResizeHeight && (
        <ResizeHandle onResize={onResizeHeight} />
      )}
      <div className={classes.header} onClick={inline ? undefined : () => {
        if (isControlled && onResizeHeight) {
          onResizeHeight(isExpanded ? 9999 : -9999);
        } else {
          setExpanded(!expanded);
        }
      }} style={inline ? { cursor: 'default' } : undefined}>
        <div className={classes.headerLeft}>
          {!inline && (isExpanded ? <ChevronDownRegular fontSize={16} /> : <ChevronUpRegular fontSize={16} />)}
          <Text weight="semibold" size={200}>
            Activity Log
          </Text>
          {entries.length > 0 && (
            <Badge color="informative" appearance="filled" size="small">
              {entries.length}
            </Badge>
          )}
          {errorCount > 0 && (
            <Badge color="danger" appearance="filled" size="small">
              {errorCount} error{errorCount > 1 ? 's' : ''}
            </Badge>
          )}
          {runningCount > 0 && (
            <Badge color="brand" appearance="filled" size="small">
              {runningCount} in progress
            </Badge>
          )}
        </div>
        <div className={classes.headerActions}>
          {onRefresh && (
            <Tooltip content="Refresh from server" relationship="label">
              <Button
                appearance="subtle"
                icon={<ArrowClockwiseRegular />}
                size="small"
                onClick={(e) => { e.stopPropagation(); onRefresh(); }}
              />
            </Tooltip>
          )}
          {entries.length > 0 && (
            <Tooltip content="Clear log" relationship="label">
              <Button
                appearance="subtle"
                icon={<DeleteRegular />}
                size="small"
                onClick={(e) => { e.stopPropagation(); onClear(); }}
              />
            </Tooltip>
          )}
        </div>
      </div>

      {isExpanded && (
        <div ref={logRef} className={classes.logArea}>
          {entries.length === 0 ? (
            <div className={classes.empty}>
              No activity yet. Click Start on a scenario to begin.
            </div>
          ) : (
            entries.map((entry) => (
              <div key={entry.id} className={classes.entry}>
                <span className={classes.timestamp}>{fmtTime(entry.timestamp)}</span>
                <span>{levelIcon[entry.level]}</span>
                <span className={classes.scenario}>{entry.scenario}</span>
                <span className={`${classes.message} ${classes[entry.level]}`}>
                  {entry.message}
                </span>
              </div>
            ))
          )}
        </div>
      )}
    </div>
  );
}

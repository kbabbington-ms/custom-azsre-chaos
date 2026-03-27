import { useState, useCallback, useMemo } from 'react';
import { makeStyles, tokens, Spinner, Text } from '@fluentui/react-components';
import { Header } from './components/Header';
import { ScenarioGrid } from './components/ScenarioGrid';
import { PodTable } from './components/PodTable';
import { ActivityLog } from './components/ActivityLog';
import { ServiceMap } from './components/ServiceMap';
import { ImpactedResources } from './components/ImpactedResources';
import { ActiveTestBanner } from './components/ActiveTestBanner';
import { ResizeHandle } from './components/ResizeHandle';
import { useScenarios, useScenarioStatuses, usePods } from './hooks/useScenarios';
import { useActivityLog } from './hooks/useActivityLog';
import { fixAll } from './api/client';
import { Scenario } from './types';

// Responsive height bounds (will be clamped by viewport on mobile)
const MAP_MIN = 140;
const MAP_MAX = 600;
const MAP_DEFAULT = 320;

const useStyles = makeStyles({
  root: {
    minHeight: '100vh',
    backgroundColor: tokens.colorNeutralBackground1,
    color: tokens.colorNeutralForeground1,
  },
  stickyMap: {
    position: 'sticky',
    top: 0,
    zIndex: 100,
    backgroundColor: tokens.colorNeutralBackground1,
    borderBottom: `1px solid ${tokens.colorNeutralStroke2}`,
    boxShadow: '0 2px 8px rgba(0,0,0,0.08)',
    padding: '12px 16px 0',
    display: 'flex',
    flexDirection: 'column',
    overflow: 'hidden',
    '@media (max-width: 768px)': {
      padding: '8px 8px 0',
    },
  },
  stickyMapInner: {
    maxWidth: '1400px',
    width: '100%',
    margin: '0 auto',
    flex: 1,
    overflow: 'hidden',
    display: 'flex',
    gap: '12px',
  },
  content: {
    maxWidth: '1400px',
    margin: '0 auto',
    padding: '16px',
    '@media (max-width: 768px)': {
      padding: '12px 8px',
    },
  },
  centered: {
    display: 'flex',
    justifyContent: 'center',
    alignItems: 'center',
    minHeight: '60vh',
    flexDirection: 'column',
    gap: '12px',
  },
});

function App() {
  const classes = useStyles();
  const { scenarios, loading } = useScenarios();
  const { statuses, refresh: refreshStatuses } = useScenarioStatuses(scenarios);
  const { pods } = usePods();
  const { entries, log, clear, refresh: refreshActivities } = useActivityLog();
  const [fixingAll, setFixingAll] = useState(false);
  const [hoveredScenario, setHoveredScenario] = useState<Scenario | null>(null);
  const [selectedCategory, setSelectedCategory] = useState<'chaos' | 'kubectl' | null>(null);
  const [selectedScenario, setSelectedScenario] = useState<Scenario | null>(null);
  const [mapHeight, setMapHeight] = useState(MAP_DEFAULT);

  const activeScenarios = useMemo(() =>
    scenarios.filter((s) => {
      const st = statuses.get(s.name);
      return st && (st.status === 'running' || st.status === 'broken');
    }),
    [scenarios, statuses],
  );

  const pinnedScenarios = useMemo(() => {
    if (!selectedCategory) return [];
    return scenarios.filter((s) => s.type === selectedCategory);
  }, [selectedCategory, scenarios]);

  const handleFixAll = useCallback(async () => {
    setFixingAll(true);
    log('Fix All', 'Reverting all scenarios to baseline...', 'info');
    try {
      await fixAll();
      refreshStatuses();
      log('Fix All', 'All scenarios reverted to baseline', 'success');
    } catch (e) {
      log('Fix All', `Failed: ${e instanceof Error ? e.message : String(e)}`, 'error');
      console.error('Fix All failed:', e);
    } finally {
      setFixingAll(false);
    }
  }, [refreshStatuses, log]);

  if (loading) {
    return (
      <div className={classes.root}>
        <Header onFixAll={handleFixAll} fixingAll={fixingAll} />
        <div className={classes.centered}>
          <Spinner size="large" />
          <Text>Loading scenarios…</Text>
        </div>
      </div>
    );
  }

  return (
    <div className={classes.root}>
      <Header onFixAll={handleFixAll} fixingAll={fixingAll} />
      <ActiveTestBanner activeScenarios={activeScenarios} statuses={statuses} />
      <div className={classes.stickyMap} style={{ height: mapHeight }}>
        <div className={classes.stickyMapInner}>
          <ActivityLog entries={entries} onClear={clear} onRefresh={refreshActivities} inline />
          <ServiceMap hoveredScenario={hoveredScenario} activeScenarios={activeScenarios} pinnedScenarios={pinnedScenarios} selectedScenario={selectedScenario} />
          <ImpactedResources hoveredScenario={hoveredScenario} activeScenarios={activeScenarios} pinnedScenarios={pinnedScenarios} selectedScenario={selectedScenario} />
        </div>
        <ResizeHandle
          onResize={(d) => setMapHeight((h) => Math.min(MAP_MAX, Math.max(MAP_MIN, h + d)))}
        />
      </div>
      <main className={classes.content}>
        <ScenarioGrid
          scenarios={scenarios}
          statuses={statuses}
          onRefresh={refreshStatuses}
          onLog={log}
          onHoverScenario={setHoveredScenario}
          onHoverScenarioEnd={() => setHoveredScenario(null)}
          selectedCategory={selectedCategory}
          onClickCategory={(cat) => setSelectedCategory((prev) => prev === cat ? null : cat)}
          selectedScenario={selectedScenario}
          onClickScenario={(s) => setSelectedScenario((prev) => prev?.name === s.name ? null : s)}
        />
        <PodTable pods={pods} />
      </main>
    </div>
  );
}

export default App;

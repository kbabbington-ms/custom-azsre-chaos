import {
  makeStyles,
  tokens,
  Text,
  Divider,
  mergeClasses,
} from '@fluentui/react-components';
import {
  CloudRegular,
  WindowConsoleRegular,
} from '@fluentui/react-icons';
import { Scenario, ScenarioStatus, ScenarioType } from '../types';
import { ScenarioCard } from './ScenarioCard';
import { ActivityLevel } from '../hooks/useActivityLog';

const useStyles = makeStyles({
  section: {
    marginBottom: '24px',
  },
  sectionHeader: {
    display: 'flex',
    alignItems: 'center',
    gap: '8px',
    marginBottom: '16px',
    cursor: 'pointer',
    userSelect: 'none',
    padding: '6px 10px',
    borderRadius: '8px',
    transition: 'background-color 0.15s ease',
    '&:hover': {
      backgroundColor: tokens.colorNeutralBackground3Hover,
    },
  },
  sectionHeaderActive: {
    backgroundColor: tokens.colorBrandBackground2,
    '&:hover': {
      backgroundColor: tokens.colorBrandBackground2Hover,
    },
  },
  chaosIcon: {
    color: tokens.colorPaletteBlueBorderActive,
  },
  kubectlIcon: {
    color: tokens.colorPaletteDarkOrangeBorderActive,
  },
  grid: {
    display: 'flex',
    flexWrap: 'wrap',
    gap: '12px',
    '@media (max-width: 768px)': {
      gap: '8px',
    },
  },
});

interface ScenarioGridProps {
  scenarios: Scenario[];
  statuses: Map<string, ScenarioStatus>;
  onRefresh: () => void;
  onLog?: (scenario: string, message: string, level?: ActivityLevel) => void;
  onHoverScenario?: (scenario: Scenario) => void;
  onHoverScenarioEnd?: () => void;
  selectedCategory?: ScenarioType | null;
  onClickCategory?: (category: ScenarioType) => void;
  selectedScenario?: Scenario | null;
  onClickScenario?: (scenario: Scenario) => void;
}

export function ScenarioGrid({ scenarios, statuses, onRefresh, onLog, onHoverScenario, onHoverScenarioEnd, selectedCategory, onClickCategory, selectedScenario, onClickScenario }: ScenarioGridProps) {
  const classes = useStyles();

  const chaosScenarios = scenarios.filter((s) => s.type === 'chaos');
  const kubectlScenarios = scenarios.filter((s) => s.type === 'kubectl');

  return (
    <>
      {/* Chaos Studio Section */}
      <section className={classes.section}>
        <div
          className={mergeClasses(classes.sectionHeader, selectedCategory === 'chaos' && classes.sectionHeaderActive)}
          onClick={() => onClickCategory?.('chaos')}
        >
          <CloudRegular fontSize={24} className={classes.chaosIcon} />
          <Text weight="semibold" size={400}>
            Azure Chaos Studio
          </Text>
          <Text size={200} style={{ opacity: 0.6 }}>
            — Automated experiments, 10-min duration, auto-cleanup
          </Text>
          {selectedCategory === 'chaos' && (
            <Text size={200} style={{ marginLeft: 'auto', opacity: 0.5 }}>click to deselect</Text>
          )}
        </div>
        <div className={classes.grid}>
          {chaosScenarios.map((s) => (
            <ScenarioCard
              key={s.name}
              scenario={s}
              status={statuses.get(s.name)}
              onActionComplete={onRefresh}
              onLog={onLog}
              onHover={onHoverScenario}
              onHoverEnd={onHoverScenarioEnd}
              isSelected={selectedScenario?.name === s.name}
              onClickCard={onClickScenario}
            />
          ))}
        </div>
      </section>

      <Divider style={{ margin: '24px 0' }} />

      {/* Kubectl Section */}
      <section className={classes.section}>
        <div
          className={mergeClasses(classes.sectionHeader, selectedCategory === 'kubectl' && classes.sectionHeaderActive)}
          onClick={() => onClickCategory?.('kubectl')}
        >
          <WindowConsoleRegular fontSize={24} className={classes.kubectlIcon} />
          <Text weight="semibold" size={400}>
            Kubernetes Scenarios
          </Text>
          <Text size={200} style={{ opacity: 0.6 }}>
            — Manifest-based misconfigurations, manual cleanup required
          </Text>
          {selectedCategory === 'kubectl' && (
            <Text size={200} style={{ marginLeft: 'auto', opacity: 0.5 }}>click to deselect</Text>
          )}
        </div>
        <div className={classes.grid}>
          {kubectlScenarios.map((s) => (
            <ScenarioCard
              key={s.name}
              scenario={s}
              status={statuses.get(s.name)}
              onActionComplete={onRefresh}
              onLog={onLog}
              onHover={onHoverScenario}
              onHoverEnd={onHoverScenarioEnd}
              isSelected={selectedScenario?.name === s.name}
              onClickCard={onClickScenario}
            />
          ))}
        </div>
      </section>
    </>
  );
}

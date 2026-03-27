import { useMemo } from 'react';
import { makeStyles, tokens, Text } from '@fluentui/react-components';
import { Scenario } from '../types';

interface AzureResource {
  type: string;
  name: string;
  rg: string;
  icon: string;
}

const INFRA_RG = 'EXP-SREDEMO-AKS-CUS-RG';
const MON_RG = 'EXP-SREDEMO-MON-CUS-RG';
const SRE_RG = 'EXP-SREDEMO-SRE-EAUS2-RG';

// Common resources referenced in every scenario
const AKS: AzureResource = { type: 'AKS Cluster', name: 'aks-srelab', rg: INFRA_RG, icon: '⎈' };
const LOG: AzureResource = { type: 'Log Analytics', name: 'log-srelab', rg: MON_RG, icon: '📊' };
const APPI: AzureResource = { type: 'App Insights', name: 'appi-srelab', rg: MON_RG, icon: '🔍' };
const GRAFANA: AzureResource = { type: 'Managed Grafana', name: 'grafana-srelab', rg: MON_RG, icon: '📈' };
const SRE: AzureResource = { type: 'SRE Agent', name: 'sre-srelab', rg: SRE_RG, icon: '🤖' };
const VNET: AzureResource = { type: 'Virtual Network', name: 'vnet-srelab', rg: INFRA_RG, icon: '🔗' };
const ACR: AzureResource = { type: 'Container Registry', name: 'acrsrelab', rg: INFRA_RG, icon: '📦' };
const PROM: AzureResource = { type: 'Prometheus', name: 'prometheus-srelab', rg: MON_RG, icon: '🔥' };

const alert = (name: string): AzureResource => ({
  type: 'Alert Rule',
  name,
  rg: MON_RG,
  icon: '🔔',
});

const chaos = (name: string): AzureResource => ({
  type: 'Chaos Experiment',
  name,
  rg: INFRA_RG,
  icon: '🧪',
});

const SCENARIO_RESOURCES: Record<string, AzureResource[]> = {
  'oom-killed': [
    AKS, chaos('chaos-srelab-oom-killed'),
    alert('crashloop-oom'), alert('pod-restarts'),
    LOG, APPI, PROM, GRAFANA, SRE,
  ],
  'crash-loop': [
    AKS, chaos('chaos-srelab-crash-loop'),
    alert('pod-restarts'), alert('crashloop-oom'),
    LOG, APPI, PROM, GRAFANA, SRE,
  ],
  'high-cpu': [
    AKS, chaos('chaos-srelab-high-cpu'),
    alert('high-cpu'),
    LOG, APPI, PROM, GRAFANA, SRE,
  ],
  'probe-failure': [
    AKS, chaos('chaos-srelab-probe-failure'),
    alert('probe-failure'), alert('pod-restarts'),
    LOG, APPI, PROM, GRAFANA, SRE,
  ],
  'network-block': [
    AKS, VNET, chaos('chaos-srelab-network-block'),
    alert('network-container-errors'), alert('http-5xx'),
    LOG, APPI, PROM, GRAFANA, SRE,
  ],
  'mongodb-down': [
    AKS, chaos('chaos-srelab-mongodb-down'),
    alert('pod-failures'), alert('pod-restarts'), alert('http-5xx'),
    LOG, APPI, PROM, GRAFANA, SRE,
  ],
  'image-pull-backoff': [
    AKS, ACR,
    alert('network-container-errors'), alert('http-5xx'),
    LOG, APPI, PROM, GRAFANA, SRE,
  ],
  'pending-pods': [
    AKS,
    alert('pod-failures'), alert('http-5xx'),
    LOG, APPI, PROM, GRAFANA, SRE,
  ],
  'missing-config': [
    AKS,
    alert('http-5xx'), alert('network-container-errors'),
    LOG, APPI, PROM, GRAFANA, SRE,
  ],
  'service-mismatch': [
    AKS,
    LOG, APPI, PROM, GRAFANA, SRE,
  ],
};

const useStyles = makeStyles({
  panel: {
    display: 'flex',
    flexDirection: 'column',
    height: '100%',
    width: '250px',
    flexShrink: 0,
    borderLeft: `1px solid ${tokens.colorNeutralStroke2}`,
    backgroundColor: tokens.colorNeutralBackground3,
    borderRadius: '0 6px 6px 0',
    overflow: 'hidden',
    '@media (max-width: 1100px)': {
      display: 'none',
    },
  },
  header: {
    padding: '8px 12px',
    borderBottom: `1px solid ${tokens.colorNeutralStroke2}`,
    flexShrink: 0,
  },
  list: {
    flex: 1,
    overflowY: 'auto',
    padding: '4px 0',
  },
  empty: {
    padding: '16px 12px',
    opacity: 0.4,
    fontSize: '12px',
    textAlign: 'center' as const,
  },
  item: {
    display: 'flex',
    alignItems: 'flex-start',
    gap: '8px',
    padding: '4px 12px',
    fontSize: '11px',
    lineHeight: '16px',
    '&:hover': {
      backgroundColor: tokens.colorNeutralBackground3Hover,
    },
  },
  itemIcon: {
    flexShrink: 0,
    fontSize: '13px',
    lineHeight: '16px',
  },
  itemDetails: {
    display: 'flex',
    flexDirection: 'column',
    minWidth: 0,
  },
  itemName: {
    fontWeight: 600,
    whiteSpace: 'nowrap',
    overflow: 'hidden',
    textOverflow: 'ellipsis',
  },
  itemType: {
    opacity: 0.6,
    fontSize: '10px',
  },
  itemRg: {
    opacity: 0.4,
    fontSize: '9px',
    whiteSpace: 'nowrap',
    overflow: 'hidden',
    textOverflow: 'ellipsis',
  },
  count: {
    opacity: 0.5,
    marginLeft: '6px',
    fontSize: '12px',
  },
});

interface ImpactedResourcesProps {
  hoveredScenario: Scenario | null;
  activeScenarios: Scenario[];
  pinnedScenarios?: Scenario[];
  selectedScenario?: Scenario | null;
}

export function ImpactedResources({ hoveredScenario, activeScenarios: _ac, pinnedScenarios = [], selectedScenario = null }: ImpactedResourcesProps) {
  const classes = useStyles();

  const resources = useMemo(() => {
    // Priority: hover > selected card > pinned category (no auto-active)
    const display = hoveredScenario ?? selectedScenario ?? (pinnedScenarios.length === 1 ? pinnedScenarios[0] : null);
    if (display) return SCENARIO_RESOURCES[display.name] ?? [];
    const multiList = pinnedScenarios.length > 1 ? pinnedScenarios : [];
    if (multiList.length > 0) {
      const seen = new Set<string>();
      const merged: AzureResource[] = [];
      for (const sc of multiList) {
        for (const r of SCENARIO_RESOURCES[sc.name] ?? []) {
          const key = `${r.type}:${r.name}`;
          if (!seen.has(key)) {
            seen.add(key);
            merged.push(r);
          }
        }
      }
      return merged;
    }
    return [];
  }, [hoveredScenario, selectedScenario, pinnedScenarios]);

  return (
    <div className={classes.panel}>
      <div className={classes.header}>
        <Text weight="semibold" size={200}>
          Impacted Azure Resources
          {resources.length > 0 && (
            <span className={classes.count}>({resources.length})</span>
          )}
        </Text>
      </div>
      <div className={classes.list}>
        {resources.length === 0 ? (
          <div className={classes.empty}>
            Click a scenario card or category header to see impacted Azure resources.
          </div>
        ) : (
          resources.map((r, i) => (
            <div key={`${r.name}-${i}`} className={classes.item}>
              <span className={classes.itemIcon}>{r.icon}</span>
              <div className={classes.itemDetails}>
                <span className={classes.itemName}>{r.name}</span>
                <span className={classes.itemType}>{r.type}</span>
                <span className={classes.itemRg}>{r.rg}</span>
              </div>
            </div>
          ))
        )}
      </div>
    </div>
  );
}

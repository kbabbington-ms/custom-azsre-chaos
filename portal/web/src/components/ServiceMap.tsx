import { useMemo } from 'react';
import { makeStyles, tokens, Text } from '@fluentui/react-components';
import { Scenario } from '../types';

// ─── Architecture graph data ──────────────────────────────────────────────────
interface ServiceNode {
  id: string;
  label: string;
  azure: string;
  kind: 'frontend' | 'api' | 'worker' | 'data' | 'external';
  x: number;
  y: number;
}

interface ServiceEdge {
  from: string;
  to: string;
  label?: string;
  dashed?: boolean;
}

const NODES: ServiceNode[] = [
  // External
  { id: 'users',              label: 'Users',              azure: 'Azure Load Balancer',    kind: 'external', x: 80,  y: 50 },
  { id: 'virtual-customer',   label: 'Virtual Customer',   azure: 'AKS Pod',                kind: 'external', x: 80,  y: 170 },
  // Frontends
  { id: 'store-front',        label: 'Store Front',        azure: 'AKS · Vue.js',           kind: 'frontend', x: 270, y: 50 },
  { id: 'store-admin',        label: 'Store Admin',        azure: 'AKS · Vue.js',           kind: 'frontend', x: 270, y: 220 },
  // APIs
  { id: 'order-service',      label: 'Order Service',      azure: 'AKS · Node.js',          kind: 'api',      x: 480, y: 50 },
  { id: 'product-service',    label: 'Product Service',    azure: 'AKS · Rust',             kind: 'api',      x: 480, y: 165 },
  { id: 'makeline-service',   label: 'Makeline Service',   azure: 'AKS · Go',               kind: 'api',      x: 480, y: 280 },
  // Infrastructure
  { id: 'rabbitmq',           label: 'RabbitMQ',           azure: 'AKS · AMQP Broker',      kind: 'data',     x: 690, y: 50 },
  { id: 'mongodb',            label: 'MongoDB',            azure: 'AKS · Managed Disk',     kind: 'data',     x: 690, y: 220 },
  { id: 'ai-service',         label: 'AI Service',         azure: 'AKS · Azure OpenAI',     kind: 'worker',   x: 690, y: 140 },
];

const EDGES: ServiceEdge[] = [
  { from: 'users',            to: 'store-front',       label: 'HTTP' },
  { from: 'virtual-customer', to: 'order-service',     label: 'HTTP', dashed: true },
  { from: 'store-front',      to: 'order-service',     label: 'REST' },
  { from: 'store-front',      to: 'product-service',   label: 'REST' },
  { from: 'store-admin',      to: 'product-service',   label: 'REST' },
  { from: 'store-admin',      to: 'makeline-service',  label: 'REST' },
  { from: 'order-service',    to: 'rabbitmq',          label: 'AMQP' },
  { from: 'makeline-service', to: 'rabbitmq',          label: 'AMQP' },
  { from: 'makeline-service', to: 'mongodb',           label: 'TCP' },
  { from: 'product-service',  to: 'ai-service',        label: 'HTTP', dashed: true },
];

// Map scenario names to the node IDs they impact (blast radius)
const SCENARIO_BLAST_RADIUS: Record<string, string[]> = {
  'oom-killed':         ['order-service', 'store-front', 'rabbitmq'],
  'crash-loop':         ['product-service', 'store-front', 'store-admin'],
  'high-cpu':           ['order-service', 'store-front', 'rabbitmq'],
  'probe-failure':      ['order-service', 'store-front'],
  'network-block':      ['order-service', 'store-front', 'rabbitmq'],
  'mongodb-down':       ['mongodb', 'makeline-service', 'order-service', 'rabbitmq'],
  'image-pull-backoff': ['makeline-service', 'mongodb', 'rabbitmq'],
  'pending-pods':       [],                                                 // resource-hog is a new pod
  'missing-config':     [],                                                 // misconfigured-service is new
  'service-mismatch':   ['order-service', 'store-front', 'rabbitmq'],
};

// ─── Styles ───────────────────────────────────────────────────────────────────
const useStyles = makeStyles({
  wrapper: {
    padding: '8px 0 0',
    overflow: 'hidden',
    display: 'flex',
    flexDirection: 'column',
    height: '100%',
    flex: '1 1 0',
    minWidth: 0,
  },
  title: {
    display: 'flex',
    alignItems: 'center',
    gap: '8px',
    marginBottom: '6px',
    flexShrink: 0,
    flexWrap: 'wrap',
    '@media (max-width: 600px)': {
      gap: '4px',
    },
  },
  subtitle: {
    '@media (max-width: 600px)': {
      display: 'none',
    },
  },
  mapRow: {
    display: 'flex',
    gap: '12px',
    alignItems: 'stretch',
    flex: 1,
    minHeight: 0,
    overflow: 'hidden',
    '@media (max-width: 768px)': {
      flexDirection: 'column',
      gap: '8px',
    },
  },
  mapSvgCol: {
    flex: '1 1 0',
    minWidth: 0,
    display: 'flex',
    alignItems: 'flex-start',
    overflow: 'hidden',
  },
  legend: {
    display: 'flex',
    gap: '12px',
    flexWrap: 'wrap',
    alignItems: 'center',
    marginTop: '6px',
    padding: '6px 10px',
    borderTop: `1px solid ${tokens.colorNeutralStroke2}`,
    backgroundColor: tokens.colorNeutralBackground3,
    borderRadius: '4px',
    flexShrink: 0,
    '@media (max-width: 600px)': {
      gap: '6px',
      marginTop: '4px',
      padding: '4px 6px',
    },
  },
  legendItem: {
    display: 'flex',
    alignItems: 'center',
    gap: '6px',
    fontSize: '13px',
    '@media (max-width: 600px)': {
      fontSize: '11px',
    },
  },
  blastInfo: {
    padding: '10px 12px',
    borderRadius: '6px',
    backgroundColor: tokens.colorNeutralBackground3,
    border: `1px solid ${tokens.colorNeutralStroke2}`,
    width: '240px',
    flexShrink: 0,
    overflowY: 'auto',
    display: 'flex',
    flexDirection: 'column',
    justifyContent: 'flex-start',
    fontSize: '12px',
    '@media (max-width: 768px)': {
      width: '100%',
      maxHeight: '80px',
      padding: '8px 10px',
    },
  },
  blastHeader: {
    display: 'flex',
    alignItems: 'center',
    gap: '6px',
    marginBottom: '6px',
  },
  blastAlerts: {
    listStyleType: 'none',
    margin: '4px 0 0',
    padding: 0,
    display: 'flex',
    flexWrap: 'wrap',
    gap: '6px',
  },
  blastAlertTag: {
    fontSize: '11px',
    padding: '2px 8px',
    borderRadius: '10px',
    backgroundColor: tokens.colorPaletteRedBackground2,
    color: tokens.colorPaletteRedForeground2,
    whiteSpace: 'nowrap',
  },
  blastAlertTagSilent: {
    fontSize: '11px',
    padding: '2px 8px',
    borderRadius: '10px',
    backgroundColor: tokens.colorPaletteYellowBackground2,
    color: tokens.colorPaletteYellowForeground2,
    whiteSpace: 'nowrap',
  },
  blastPrompts: {
    listStyleType: 'none',
    margin: '6px 0 0',
    padding: 0,
  },
  blastPrompt: {
    fontSize: '11px',
    opacity: 0.7,
    padding: '1px 0',
    '&::before': { content: '">', marginRight: '6px', opacity: 0.5 },
    '@media (max-width: 600px)': {
      fontSize: '10px',
    },
  },
});

// ─── Color helpers ────────────────────────────────────────────────────────────
const KIND_COLORS: Record<ServiceNode['kind'], { fill: string; stroke: string }> = {
  frontend: { fill: '#e3f2fd', stroke: '#1976d2' },
  api:      { fill: '#e8f5e9', stroke: '#388e3c' },
  worker:   { fill: '#fff3e0', stroke: '#f57c00' },
  data:     { fill: '#fce4ec', stroke: '#c62828' },
  external: { fill: '#f3e5f5', stroke: '#7b1fa2' },
};

const NODE_W = 140;
const NODE_H = 52;
const SVG_W = 840;
const SVG_H = 350;

// ─── Component ────────────────────────────────────────────────────────────────
interface ServiceMapProps {
  hoveredScenario: Scenario | null;
  activeScenarios?: Scenario[];
  pinnedScenarios?: Scenario[];
  selectedScenario?: Scenario | null;
}

export function ServiceMap({ hoveredScenario, activeScenarios = [], pinnedScenarios = [], selectedScenario = null }: ServiceMapProps) {
  const classes = useStyles();

  // Pinned category blast radius — blue
  const pinnedBlastIds = useMemo(() => {
    const s = new Set<string>();
    for (const sc of pinnedScenarios) {
      for (const id of SCENARIO_BLAST_RADIUS[sc.name] ?? []) s.add(id);
    }
    return s;
  }, [pinnedScenarios]);

  // Selected individual scenario blast radius — orange
  const selectedBlastIds = useMemo(() => {
    if (!selectedScenario) return new Set<string>();
    return new Set(SCENARIO_BLAST_RADIUS[selectedScenario.name] ?? []);
  }, [selectedScenario]);

  // Hover blast radius — red (takes visual priority)
  const hoverBlastIds = useMemo(() => {
    if (!hoveredScenario) return new Set<string>();
    return new Set(SCENARIO_BLAST_RADIUS[hoveredScenario.name] ?? []);
  }, [hoveredScenario]);

  // Combined: any node in any set gets highlighted (no auto-active — map stays healthy by default)
  const blastIds = useMemo(() => {
    const s = new Set<string>();
    for (const id of selectedBlastIds) s.add(id);
    for (const id of pinnedBlastIds) s.add(id);
    for (const id of hoverBlastIds) s.add(id);
    return s;
  }, [selectedBlastIds, pinnedBlastIds, hoverBlastIds]);

  // Which edges are in the blast path?
  const blastEdges = useMemo(() => {
    const s = new Set<string>();
    for (const e of EDGES) {
      if (blastIds.has(e.from) && blastIds.has(e.to)) s.add(`${e.from}->${e.to}`);
    }
    return s;
  }, [blastIds]);

  const hasHighlight = hoveredScenario !== null || selectedScenario !== null || pinnedScenarios.length > 0;
  const displayScenario = hoveredScenario ?? selectedScenario ?? (pinnedScenarios.length === 1 ? pinnedScenarios[0] : null);
  const displayMultiple = !displayScenario
    ? (pinnedScenarios.length > 1 ? pinnedScenarios : [])
    : [];

  return (
    <div className={classes.wrapper}>
      <div className={classes.title}>
        <Text weight="semibold" size={400}>
          Service Architecture Map
        </Text>
        <Text size={200} style={{ opacity: 0.6 }} className={classes.subtitle}>
          — Click a scenario card to see its blast radius
        </Text>
      </div>

      <div className={classes.mapRow}>
      {/* Blast radius detail panel — left side */}
      <div className={classes.blastInfo}>
        {!displayScenario && displayMultiple.length === 0 ? (
          <Text size={200} style={{ opacity: 0.4 }}>
            Click a scenario card or category header to see its failure blast radius, expected alert rules, and SRE investigation prompts.
          </Text>
        ) : !displayScenario && displayMultiple.length > 0 ? (
          <Text size={200}>
            <span style={{ fontWeight: 600 }}>{displayMultiple.length} scenarios selected:</span>{' '}
            {displayMultiple.map((s) => s.displayName).join(', ')}
          </Text>
        ) : displayScenario ? (
          <>
            <div className={classes.blastHeader}>
              <Text size={200} style={{ opacity: 0.5 }}>Scenario:</Text>
              <Text weight="semibold" size={300}>
                {displayScenario.displayName}
              </Text>
              {activeScenarios.some((s) => s.name === displayScenario.name) && (
                <Text size={200} style={{ color: '#e65100', fontWeight: 600 }}>RUNNING</Text>
              )}
            </div>
            <div className={classes.blastHeader} style={{ marginBottom: '2px' }}>
              <Text size={200} style={{ opacity: 0.5 }}>Target:</Text>
              <Text weight="semibold" size={300} style={{ color: '#d32f2f' }}>
                {displayScenario.target}
              </Text>
            </div>

            {/* Alert rules */}
            {displayScenario.expectedAlerts && displayScenario.expectedAlerts.length > 0 && (
              <div style={{ marginBottom: '4px' }}>
                <Text size={200} style={{ opacity: 0.5 }}>Alert Rules:</Text>
                <ul className={classes.blastAlerts}>
                  {displayScenario.expectedAlerts.map((a, i) => (
                    <li
                      key={i}
                      className={a.includes('No direct') ? classes.blastAlertTagSilent : classes.blastAlertTag}
                    >
                      {a}
                    </li>
                  ))}
                </ul>
              </div>
            )}

            {/* SRE prompts */}
            <Text size={200} style={{ opacity: 0.5 }}>SRE Agent Prompts:</Text>
            <ul className={classes.blastPrompts}>
              {displayScenario.srePrompts.map((p, i) => (
                <li key={i} className={classes.blastPrompt}>{p}</li>
              ))}
            </ul>
          </>
        ) : null}
      </div>

      {/* SVG map — right side */}
      <div className={classes.mapSvgCol}>
      <svg
        viewBox={`0 0 ${SVG_W} ${SVG_H}`}
        width="100%"
        preserveAspectRatio="xMidYMid meet"
        style={{ display: 'block', maxHeight: '100%' }}
      >
        <defs>
          <marker id="arrow" viewBox="0 0 10 6" refX="10" refY="3"
            markerWidth="8" markerHeight="6" orient="auto-start-reverse">
            <path d="M 0 0 L 10 3 L 0 6 z" fill="#888" />
          </marker>
          <marker id="arrow-danger" viewBox="0 0 10 6" refX="10" refY="3"
            markerWidth="8" markerHeight="6" orient="auto-start-reverse">
            <path d="M 0 0 L 10 3 L 0 6 z" fill="#d32f2f" />
          </marker>
          {/* glow filter for highlighted nodes */}
          <filter id="glow-red">
            <feDropShadow dx="0" dy="0" stdDeviation="4" floodColor="#d32f2f" floodOpacity="0.6" />
          </filter>
          <filter id="glow-orange">
            <feDropShadow dx="0" dy="0" stdDeviation="4" floodColor="#e65100" floodOpacity="0.6" />
          </filter>
          <filter id="glow-blue">
            <feDropShadow dx="0" dy="0" stdDeviation="4" floodColor="#1565c0" floodOpacity="0.6" />
          </filter>
          <marker id="arrow-pinned" viewBox="0 0 10 6" refX="10" refY="3"
            markerWidth="8" markerHeight="6" orient="auto-start-reverse">
            <path d="M 0 0 L 10 3 L 0 6 z" fill="#1565c0" />
          </marker>
          <marker id="arrow-selected" viewBox="0 0 10 6" refX="10" refY="3"
            markerWidth="8" markerHeight="6" orient="auto-start-reverse">
            <path d="M 0 0 L 10 3 L 0 6 z" fill="#e65100" />
          </marker>
          {/* pulse animation */}
          <style>{`
            @keyframes pulse { 0%,100%{opacity:1} 50%{opacity:.4} }
            .blast-pulse { animation: pulse 1.2s infinite; }
            @keyframes active-pulse { 0%,100%{opacity:1} 50%{opacity:.6} }
            .active-pulse { animation: active-pulse 2s infinite; }
          `}</style>
        </defs>

        {/* Edges */}
        {EDGES.map((e) => {
          const from = NODES.find((n) => n.id === e.from)!;
          const to = NODES.find((n) => n.id === e.to)!;
          const x1 = from.x + NODE_W / 2;
          const y1 = from.y + NODE_H / 2;
          const x2 = to.x + NODE_W / 2;
          const y2 = to.y + NODE_H / 2;

          // Shorten line so arrow sits at node edge
          const dx = x2 - x1;
          const dy = y2 - y1;
          const len = Math.sqrt(dx * dx + dy * dy);
          const pad = NODE_W / 2 + 4;
          const ratio1 = pad / len;
          const ratio2 = (len - pad) / len;
          const sx = x1 + dx * ratio1;
          const sy = y1 + dy * ratio1;
          const ex = x1 + dx * ratio2;
          const ey = y1 + dy * ratio2;

          const edgeKey = `${e.from}->${e.to}`;
          const isBlast = blastEdges.has(edgeKey);
          const isHoverBlast = hoverBlastIds.has(e.from) && hoverBlastIds.has(e.to);
          const isSelectedBlast = selectedBlastIds.has(e.from) && selectedBlastIds.has(e.to);
          const isPinnedBlast = pinnedBlastIds.has(e.from) && pinnedBlastIds.has(e.to);
          const dimmed = hasHighlight && !isBlast;
          const edgeColor = isHoverBlast ? '#d32f2f' : isSelectedBlast ? '#e65100' : isPinnedBlast ? '#1565c0' : '#aaa';
          const edgeMarker = isHoverBlast ? 'url(#arrow-danger)' : isSelectedBlast ? 'url(#arrow-selected)' : isPinnedBlast ? 'url(#arrow-pinned)' : 'url(#arrow)';

          return (
            <g key={edgeKey}>
              <line
                x1={sx} y1={sy} x2={ex} y2={ey}
                stroke={edgeColor}
                strokeWidth={isBlast ? 2.5 : 1.2}
                strokeDasharray={e.dashed ? '6 4' : undefined}
                markerEnd={edgeMarker}
                opacity={dimmed ? 0.15 : 1}
                className={isHoverBlast ? 'blast-pulse' : undefined}
              />
              {e.label && (
                <text
                  x={(sx + ex) / 2}
                  y={(sy + ey) / 2 - 6}
                  textAnchor="middle"
                  fontSize="9"
                  fill={isBlast ? '#d32f2f' : '#999'}
                  opacity={dimmed ? 0.15 : 0.7}
                >
                  {e.label}
                </text>
              )}
            </g>
          );
        })}

        {/* Nodes */}
        {NODES.map((n) => {
          const isHoverBlast = hoverBlastIds.has(n.id);
          const isSelectedBlast = selectedBlastIds.has(n.id);
          const isPinnedBlast = pinnedBlastIds.has(n.id);
          const isBlast = isHoverBlast || isSelectedBlast || isPinnedBlast;
          const dimmed = hasHighlight && !isBlast;
          const colors = KIND_COLORS[n.kind];
          const glowFilter = isHoverBlast ? 'url(#glow-red)' : isSelectedBlast ? 'url(#glow-orange)' : isPinnedBlast ? 'url(#glow-blue)' : undefined;
          const fillColor = isHoverBlast ? '#ffebee' : isSelectedBlast ? '#fff3e0' : isPinnedBlast ? '#e3f2fd' : colors.fill;
          const strokeColor = isHoverBlast ? '#d32f2f' : isSelectedBlast ? '#e65100' : isPinnedBlast ? '#1565c0' : colors.stroke;
          const textColor = isHoverBlast ? '#b71c1c' : isSelectedBlast ? '#bf360c' : isPinnedBlast ? '#0d47a1' : '#333';
          const subTextColor = isHoverBlast ? '#c62828' : isSelectedBlast ? '#e65100' : isPinnedBlast ? '#1565c0' : '#777';

          return (
            <g key={n.id} opacity={dimmed ? 0.2 : 1} filter={glowFilter}>
              <rect
                x={n.x}
                y={n.y}
                width={NODE_W}
                height={NODE_H}
                rx={6}
                fill={fillColor}
                stroke={strokeColor}
                strokeWidth={isBlast ? 2.5 : 1.5}
              />
              <text
                x={n.x + NODE_W / 2}
                y={n.y + NODE_H / 2 - 5}
                textAnchor="middle"
                dominantBaseline="middle"
                fontSize="11"
                fontWeight={isBlast ? 700 : 500}
                fill={textColor}
              >
                {n.label}
              </text>
              <text
                x={n.x + NODE_W / 2}
                y={n.y + NODE_H / 2 + 9}
                textAnchor="middle"
                dominantBaseline="middle"
                fontSize="8"
                fontWeight={400}
                fill={subTextColor}
                fontStyle="italic"
              >
                {n.azure}
              </text>
              {isBlast && (
                <text
                  x={n.x + NODE_W - 4}
                  y={n.y + 12}
                  textAnchor="end"
                  fontSize="12"
                >
                  &#x1F525;
                </text>
              )}
            </g>
          );
        })}
      </svg>
      </div>{/* end mapSvgCol */}
      </div>{/* end mapRow */}

      {/* Legend */}
      <div className={classes.legend}>
        <Text weight="semibold" size={200} style={{ marginRight: '4px' }}>Legend:</Text>
        {(['frontend', 'api', 'worker', 'data', 'external'] as const).map((kind) => (
          <div key={kind} className={classes.legendItem}>
            <svg width="18" height="18">
              <rect width="18" height="18" rx="3" fill={KIND_COLORS[kind].fill} stroke={KIND_COLORS[kind].stroke} strokeWidth="1.5" />
            </svg>
            {kind.charAt(0).toUpperCase() + kind.slice(1)}
          </div>
        ))}
        <div className={classes.legendItem}>
          <svg width="18" height="18">
            <rect width="18" height="18" rx="3" fill="#ffebee" stroke="#d32f2f" strokeWidth="2" />
          </svg>
          Blast Radius (hover)
        </div>
        <div className={classes.legendItem}>
          <svg width="18" height="18">
            <rect width="18" height="18" rx="3" fill="#fff3e0" stroke="#e65100" strokeWidth="2" />
          </svg>
          Selected Scenario
        </div>
        <div className={classes.legendItem}>
          <svg width="18" height="18">
            <rect width="18" height="18" rx="3" fill="#e3f2fd" stroke="#1565c0" strokeWidth="2" />
          </svg>
          Selected Category
        </div>
      </div>
    </div>
  );
}

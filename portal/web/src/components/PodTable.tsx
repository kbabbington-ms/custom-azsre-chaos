import {
  makeStyles,
  tokens,
  Text,
  Table,
  TableHeader,
  TableRow,
  TableHeaderCell,
  TableBody,
  TableCell,
  Badge,
} from '@fluentui/react-components';
import { PodInfo } from '../types';

const useStyles = makeStyles({
  container: {
    marginTop: '16px',
  },
  header: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: '8px',
    flexWrap: 'wrap',
    gap: '4px',
  },
  table: {
    width: '100%',
  },
  tableWrapper: {
    overflowX: 'auto',
    WebkitOverflowScrolling: 'touch' as unknown as undefined,
  },
});

function podStatusColor(
  status: string,
  restarts: number,
  ready: string
): 'success' | 'danger' | 'warning' | 'informative' {
  if (status === 'Running' && ready.split('/')[0] === ready.split('/')[1] && restarts < 5) {
    return 'success';
  }
  if (status === 'Running' && restarts >= 5) return 'warning';
  if (status === 'Pending' || status === 'ContainerCreating') return 'informative';
  return 'danger';
}

interface PodTableProps {
  pods: PodInfo[];
}

export function PodTable({ pods }: PodTableProps) {
  const classes = useStyles();

  return (
    <section className={classes.container}>
      <div className={classes.header}>
        <Text weight="semibold" size={400}>
          Live Pod Status
        </Text>
        <Text size={200} style={{ opacity: 0.6 }}>
          pets namespace — auto-refresh 5 s
        </Text>
      </div>
      <div className={classes.tableWrapper}>
      <Table size="small" className={classes.table}>
        <TableHeader>
          <TableRow>
            <TableHeaderCell>Pod</TableHeaderCell>
            <TableHeaderCell>Status</TableHeaderCell>
            <TableHeaderCell>Ready</TableHeaderCell>
            <TableHeaderCell>Restarts</TableHeaderCell>
            <TableHeaderCell>Age</TableHeaderCell>
          </TableRow>
        </TableHeader>
        <TableBody>
          {pods
            .sort((a, b) => a.name.localeCompare(b.name))
            .map((pod) => (
              <TableRow key={pod.name}>
                <TableCell>
                  <Text size={200} font="monospace">
                    {pod.name}
                  </Text>
                </TableCell>
                <TableCell>
                  <Badge
                    color={podStatusColor(pod.status, pod.restarts, pod.ready)}
                    appearance="filled"
                    size="small"
                    style={{
                      backgroundColor:
                        podStatusColor(pod.status, pod.restarts, pod.ready) === 'success'
                          ? tokens.colorPaletteGreenBackground2
                          : podStatusColor(pod.status, pod.restarts, pod.ready) === 'danger'
                            ? tokens.colorPaletteRedBackground2
                            : podStatusColor(pod.status, pod.restarts, pod.ready) === 'warning'
                              ? tokens.colorPaletteYellowBackground2
                              : tokens.colorNeutralBackground4,
                    }}
                  >
                    {pod.status}
                  </Badge>
                </TableCell>
                <TableCell>
                  <Text size={200}>{pod.ready}</Text>
                </TableCell>
                <TableCell>
                  <Text
                    size={200}
                    style={{
                      color:
                        pod.restarts > 5
                          ? tokens.colorPaletteRedForeground1
                          : pod.restarts > 0
                            ? tokens.colorPaletteYellowForeground1
                            : undefined,
                    }}
                  >
                    {pod.restarts}
                  </Text>
                </TableCell>
                <TableCell>
                  <Text size={200} style={{ opacity: 0.7 }}>
                    {pod.age}
                  </Text>
                </TableCell>
              </TableRow>
            ))}
        </TableBody>
      </Table>
      </div>
    </section>
  );
}

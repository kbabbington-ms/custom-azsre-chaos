import {
  makeStyles,
  tokens,
  Text,
  Button,
  Toolbar,
  ToolbarButton,
} from '@fluentui/react-components';
import {
  FlashRegular,
  OpenRegular,
  ArrowResetRegular,
} from '@fluentui/react-icons';

const useStyles = makeStyles({
  header: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'space-between',
    padding: '10px 16px',
    backgroundColor: tokens.colorNeutralBackground3,
    borderBottom: `1px solid ${tokens.colorNeutralStroke1}`,
    flexWrap: 'wrap',
    gap: '8px',
    '@media (max-width: 600px)': {
      padding: '8px 10px',
    },
  },
  left: {
    display: 'flex',
    alignItems: 'center',
    gap: '12px',
  },
  iconWrapper: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    width: '36px',
    height: '36px',
    borderRadius: '8px',
    backgroundColor: tokens.colorBrandBackground,
  },
});

interface HeaderProps {
  onFixAll: () => void;
  fixingAll: boolean;
}

export function Header({ onFixAll, fixingAll }: HeaderProps) {
  const classes = useStyles();

  return (
    <header className={classes.header}>
      <div className={classes.left}>
        <div className={classes.iconWrapper}>
          <FlashRegular fontSize={20} />
        </div>
        <div>
          <Text weight="semibold" size={500}>
            Chaos Engineering Lab
          </Text>
          <Text size={200} style={{ display: 'block', opacity: 0.7 }}>
            Azure SRE Agent Demo — 10 Breakable Scenarios
          </Text>
        </div>
      </div>
      <Toolbar>
        <Button
          appearance="primary"
          icon={<ArrowResetRegular />}
          onClick={onFixAll}
          disabled={fixingAll}
        >
          {fixingAll ? 'Fixing…' : 'Fix All'}
        </Button>
        <ToolbarButton
          icon={<OpenRegular />}
          as="a"
          href="https://aka.ms/sreagent/portal"
          target="_blank"
        >
          SRE Agent
        </ToolbarButton>
      </Toolbar>
    </header>
  );
}

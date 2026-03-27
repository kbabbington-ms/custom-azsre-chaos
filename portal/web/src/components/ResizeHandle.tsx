import { useCallback, useRef } from 'react';
import { makeStyles, tokens } from '@fluentui/react-components';

const useStyles = makeStyles({
  handle: {
    height: '6px',
    cursor: 'row-resize',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    flexShrink: 0,
    userSelect: 'none',
    touchAction: 'none',
    zIndex: 10,
    '&:hover > div': {
      backgroundColor: tokens.colorBrandBackground,
      width: '48px',
    },
  },
  grip: {
    width: '32px',
    height: '3px',
    borderRadius: '2px',
    backgroundColor: tokens.colorNeutralStroke2,
    transition: 'width 0.15s ease, background-color 0.15s ease',
  },
});

interface ResizeHandleProps {
  onResize: (deltaY: number) => void;
  onResizeEnd?: () => void;
}

export function ResizeHandle({ onResize, onResizeEnd }: ResizeHandleProps) {
  const classes = useStyles();
  const startY = useRef(0);

  const handlePointerDown = useCallback(
    (e: React.PointerEvent) => {
      e.preventDefault();
      startY.current = e.clientY;
      const el = e.currentTarget as HTMLElement;
      el.setPointerCapture(e.pointerId);

      const onMove = (ev: PointerEvent) => {
        const delta = ev.clientY - startY.current;
        startY.current = ev.clientY;
        onResize(delta);
      };

      const onUp = () => {
        el.removeEventListener('pointermove', onMove);
        el.removeEventListener('pointerup', onUp);
        onResizeEnd?.();
      };

      el.addEventListener('pointermove', onMove);
      el.addEventListener('pointerup', onUp);
    },
    [onResize, onResizeEnd],
  );

  return (
    <div className={classes.handle} onPointerDown={handlePointerDown}>
      <div className={classes.grip} />
    </div>
  );
}

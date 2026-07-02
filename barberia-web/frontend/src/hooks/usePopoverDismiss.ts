'use client';

import { useEffect } from 'react';

type RefTarget = React.RefObject<HTMLElement | null>;

export function usePopoverDismiss(
  open: boolean,
  onClose: () => void,
  refs: RefTarget | RefTarget[],
) {
  useEffect(() => {
    if (!open) return;

    const refList = Array.isArray(refs) ? refs : [refs];

    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') onClose();
    };

    const onPointerDown = (event: MouseEvent) => {
      const target = event.target as Node;
      const inside = refList.some((ref) => ref.current?.contains(target));
      if (!inside) onClose();
    };

    document.addEventListener('keydown', onKeyDown);
    document.addEventListener('mousedown', onPointerDown);
    return () => {
      document.removeEventListener('keydown', onKeyDown);
      document.removeEventListener('mousedown', onPointerDown);
    };
  }, [open, onClose, refs]);
}

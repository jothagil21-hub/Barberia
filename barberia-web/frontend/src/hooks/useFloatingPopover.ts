'use client';

import { useEffect, useLayoutEffect, useState } from 'react';

type FloatingStyle = {
  top: number;
  left: number;
  width: number;
  transform?: string;
};

export function useFloatingPopover(
  open: boolean,
  triggerRef: React.RefObject<HTMLElement | null>,
) {
  const [mounted, setMounted] = useState(false);
  const [style, setStyle] = useState<FloatingStyle | null>(null);

  useEffect(() => {
    setMounted(true);
  }, []);

  useLayoutEffect(() => {
    if (!open || !triggerRef.current) {
      setStyle(null);
      return;
    }

    function updatePosition() {
      const trigger = triggerRef.current;
      if (!trigger) return;

      const rect = trigger.getBoundingClientRect();
      const gap = 6;
      const estimatedHeight = 180;
      const spaceBelow = window.innerHeight - rect.bottom;
      const openUpward = spaceBelow < estimatedHeight && rect.top > estimatedHeight;

      setStyle({
        top: openUpward ? rect.top - gap : rect.bottom + gap,
        left: rect.left,
        width: Math.max(rect.width, 160),
        ...(openUpward ? { transform: 'translateY(-100%)' } : {}),
      });
    }

    updatePosition();
    window.addEventListener('scroll', updatePosition, true);
    window.addEventListener('resize', updatePosition);

    return () => {
      window.removeEventListener('scroll', updatePosition, true);
      window.removeEventListener('resize', updatePosition);
    };
  }, [open, triggerRef]);

  return { mounted, style };
}

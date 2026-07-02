'use client';

import { useCallback, useState } from 'react';

export function useBusy() {
  const [busyKey, setBusyKey] = useState<string | null>(null);

  const isBusy = useCallback((key: string) => busyKey === key, [busyKey]);

  const run = useCallback(async (key: string, action: () => Promise<void>) => {
    setBusyKey(key);
    try {
      await action();
    } finally {
      setBusyKey(null);
    }
  }, []);

  return { busyKey, isBusy, run, isAnyBusy: busyKey !== null };
}

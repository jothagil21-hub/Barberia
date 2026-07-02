'use client';

import { useEffect, useRef } from 'react';

type AutoRefreshOptions = {
  intervalMs?: number;
  enabled?: boolean;
};

/**
 * Ejecuta `callback` periódicamente mientras la pestaña está visible
 * y al recuperar el foco o volver a la pestaña.
 */
export function useAutoRefresh(
  callback: () => void | Promise<void>,
  deps: unknown[],
  options: AutoRefreshOptions = {},
) {
  const { intervalMs = 30_000, enabled = true } = options;
  const callbackRef = useRef(callback);

  useEffect(() => {
    callbackRef.current = callback;
  }, [callback]);

  useEffect(() => {
    if (!enabled) return;

    let timer: ReturnType<typeof setInterval> | null = null;

    const run = () => {
      void callbackRef.current();
    };

    const startPolling = () => {
      if (timer != null) return;
      timer = setInterval(run, intervalMs);
    };

    const stopPolling = () => {
      if (timer == null) return;
      clearInterval(timer);
      timer = null;
    };

    const onVisibilityChange = () => {
      if (document.visibilityState === 'visible') {
        run();
        startPolling();
      } else {
        stopPolling();
      }
    };

    const onFocus = () => {
      run();
    };

    if (document.visibilityState === 'visible') {
      startPolling();
    }

    document.addEventListener('visibilitychange', onVisibilityChange);
    window.addEventListener('focus', onFocus);

    return () => {
      stopPolling();
      document.removeEventListener('visibilitychange', onVisibilityChange);
      window.removeEventListener('focus', onFocus);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps -- deps passed explicitly by caller
  }, [enabled, intervalMs, ...deps]);
}

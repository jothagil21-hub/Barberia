'use client';

import { ToastProvider } from '@/components/ToastProvider';

/** Agrupa providers del cliente (toasts, etc.). */
export function Providers({ children }: { children: React.ReactNode }) {
  return <ToastProvider>{children}</ToastProvider>;
}

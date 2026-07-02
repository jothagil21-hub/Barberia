'use client';

import { createContext, useCallback, useContext, useMemo, useState } from 'react';
import { Toast, type ToastItem, type ToastType } from './Toast';

type ToastContextValue = {
  showSuccess: (message: string) => void;
  showError: (message: string) => void;
  showInfo: (message: string) => void;
};

const ToastContext = createContext<ToastContextValue | null>(null);

const AUTO_DISMISS_MS = 5000;

function nextId() {
  return `${Date.now()}-${Math.random().toString(36).slice(2, 9)}`;
}

/** Provee toasts globales a toda la app. Envolver en layout. */
export function ToastProvider({ children }: { children: React.ReactNode }) {
  const [toasts, setToasts] = useState<ToastItem[]>([]);

  const remove = useCallback((id: string) => {
    setToasts((prev) => prev.filter((t) => t.id !== id));
  }, []);

  const show = useCallback(
    (type: ToastType, message: string) => {
      const id = nextId();
      setToasts((prev) => [...prev, { id, type, message }]);

      if (type !== 'error') {
        window.setTimeout(() => remove(id), AUTO_DISMISS_MS);
      }
    },
    [remove],
  );

  const value = useMemo(
    () => ({
      showSuccess: (message: string) => show('success', message),
      showError: (message: string) => show('error', message),
      showInfo: (message: string) => show('info', message),
    }),
    [show],
  );

  return (
    <ToastContext.Provider value={value}>
      {children}
      <div className="toast-container" aria-live="polite">
        {toasts.map((t) => (
          <Toast key={t.id} toast={t} onClose={remove} />
        ))}
      </div>
    </ToastContext.Provider>
  );
}

export function useToast() {
  const ctx = useContext(ToastContext);
  if (!ctx) {
    throw new Error('useToast debe usarse dentro de ToastProvider');
  }
  return ctx;
}

'use client';

export type ToastType = 'success' | 'error' | 'info';

export type ToastItem = {
  id: string;
  type: ToastType;
  message: string;
};

type ToastProps = {
  toast: ToastItem;
  onClose: (id: string) => void;
};

/** Un mensaje flotante (éxito, error o info). */
export function Toast({ toast, onClose }: ToastProps) {
  return (
    <div className={`toast toast-${toast.type}`} role="alert">
      <span className="toast-message">{toast.message}</span>
      <button
        type="button"
        className="toast-close"
        onClick={() => onClose(toast.id)}
        aria-label="Cerrar"
      >
        ×
      </button>
    </div>
  );
}

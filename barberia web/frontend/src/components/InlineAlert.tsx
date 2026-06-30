type InlineAlertProps = {
  message: string;
  variant?: 'error' | 'info';
};

/** Alerta junto a un formulario (ej. login). */
export function InlineAlert({ message, variant = 'error' }: InlineAlertProps) {
  return <p className={`inline-alert inline-alert-${variant}`} role="alert">{message}</p>;
}

type InlineSpinnerProps = {
  label?: string;
  size?: 'sm' | 'md';
};

export function InlineSpinner({ label, size = 'sm' }: InlineSpinnerProps) {
  return (
    <span className={`inline-spinner inline-spinner-${size}`} role="status">
      <span className="spinner" aria-hidden="true" />
      {label && <span className="muted">{label}</span>}
    </span>
  );
}

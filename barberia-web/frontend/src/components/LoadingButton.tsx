'use client';

type LoadingButtonProps = React.ButtonHTMLAttributes<HTMLButtonElement> & {
  loading?: boolean;
  loadingText?: string;
  variant?: 'primary' | 'secondary';
};

export function LoadingButton({
  loading = false,
  loadingText,
  children,
  className = '',
  disabled,
  variant = 'primary',
  type = 'button',
  ...props
}: LoadingButtonProps) {
  const classes = [
    'btn',
    variant === 'primary' ? 'btn-primary' : 'btn-secondary',
    loading ? 'btn-loading' : '',
    className,
  ]
    .filter(Boolean)
    .join(' ');

  return (
    <button {...props} type={type} className={classes} disabled={disabled || loading}>
      {loading ? loadingText ?? children : children}
    </button>
  );
}

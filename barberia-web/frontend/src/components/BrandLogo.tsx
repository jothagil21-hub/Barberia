type BrandLogoProps = {
  size?: 'sm' | 'md' | 'lg';
  showText?: boolean;
  className?: string;
};

const SIZES = {
  sm: 32,
  md: 40,
  lg: 56,
};

export function BrandLogo({ size = 'md', showText = false, className = '' }: BrandLogoProps) {
  const dimension = SIZES[size];

  return (
    <div className={`brand-logo${className ? ` ${className}` : ''}`}>
      <svg
        width={dimension}
        height={dimension}
        viewBox="0 0 56 56"
        fill="none"
        xmlns="http://www.w3.org/2000/svg"
        aria-hidden={showText ? undefined : true}
        role={showText ? 'img' : undefined}
        aria-label={showText ? 'BarberiaApp' : undefined}
      >
        <circle cx="28" cy="28" r="28" fill="var(--brand-gold)" />
        <path
          d="M18 22c0-3.3 2.7-6 6-6h8c3.3 0 6 2.7 6 6v2c0 2.2-1.2 4.1-3 5.2V36h-4v-6.8c-1.8-1-3-3-3-5.2v-2z"
          fill="var(--ink)"
          opacity="0.9"
        />
        <rect x="22" y="36" width="12" height="3" rx="1.5" fill="var(--ink)" opacity="0.85" />
        <path
          d="M21 18l3 4M35 18l-3 4"
          stroke="var(--ink)"
          strokeWidth="2"
          strokeLinecap="round"
        />
      </svg>
      {showText && <span className="brand-logo-text">BarberiaApp</span>}
    </div>
  );
}

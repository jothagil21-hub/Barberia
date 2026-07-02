'use client';

type ToggleProps = {
  checked: boolean;
  onChange: (checked: boolean) => void;
  label: string;
  id?: string;
  disabled?: boolean;
};

export function Toggle({ checked, onChange, label, id, disabled = false }: ToggleProps) {
  const toggleId = id ?? 'toggle';

  return (
    <label className={`toggle${disabled ? ' toggle-disabled' : ''}`} htmlFor={toggleId}>
      <input
        id={toggleId}
        type="checkbox"
        className="toggle-input"
        checked={checked}
        disabled={disabled}
        onChange={(event) => onChange(event.target.checked)}
      />
      <span className="toggle-track" aria-hidden="true">
        <span className="toggle-thumb" />
      </span>
      <span className="toggle-label">{label}</span>
    </label>
  );
}

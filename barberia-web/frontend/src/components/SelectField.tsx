'use client';

import { createPortal } from 'react-dom';
import { useMemo, useRef, useState } from 'react';
import { useFloatingPopover } from '@/hooks/useFloatingPopover';
import { usePopoverDismiss } from '@/hooks/usePopoverDismiss';

export type SelectOption = {
  value: string;
  label: string;
};

type SelectFieldProps = {
  value: string;
  onChange: (value: string) => void;
  options: SelectOption[];
  label?: string;
  id?: string;
  placeholder?: string;
  compact?: boolean;
  disabled?: boolean;
  required?: boolean;
  'aria-label'?: string;
};

export function SelectField({
  value,
  onChange,
  options,
  label,
  id,
  placeholder = 'Seleccionar…',
  compact = false,
  disabled = false,
  required = false,
  'aria-label': ariaLabel,
}: SelectFieldProps) {
  const rootRef = useRef<HTMLDivElement>(null);
  const triggerRef = useRef<HTMLButtonElement>(null);
  const popoverRef = useRef<HTMLDivElement>(null);
  const [open, setOpen] = useState(false);
  const triggerId = id ?? 'select-field';
  const usePortal = compact;

  const { mounted, style: floatingStyle } = useFloatingPopover(open && usePortal, triggerRef);

  usePopoverDismiss(
    open,
    () => setOpen(false),
    usePortal ? [rootRef, popoverRef] : rootRef,
  );

  const selectedLabel = useMemo(() => {
    const match = options.find((option) => option.value === value);
    return match?.label ?? placeholder;
  }, [options, value, placeholder]);

  function selectOption(nextValue: string) {
    onChange(nextValue);
    setOpen(false);
  }

  const popover = open ? (
    <div
      ref={popoverRef}
      className={`picker-field-popover select-field-popover${usePortal ? ' picker-field-popover-floating' : ''}`}
      role="listbox"
      aria-label={label ?? 'Opciones'}
      style={
        usePortal && floatingStyle
          ? {
              top: floatingStyle.top,
              left: floatingStyle.left,
              width: floatingStyle.width,
              transform: floatingStyle.transform,
            }
          : undefined
      }
    >
      {options.map((option) => (
        <button
          key={option.value}
          type="button"
          role="option"
          aria-selected={option.value === value}
          className={`select-field-option${option.value === value ? ' select-field-option-selected' : ''}`}
          onClick={() => selectOption(option.value)}
        >
          {option.label}
        </button>
      ))}
    </div>
  ) : null;

  return (
    <div
      className={`picker-field select-field${open ? ' picker-field-open' : ''}${compact ? ' select-field-compact' : ''}`}
      ref={rootRef}
    >
      {label && (
        <label htmlFor={triggerId} className="picker-field-label">
          {label}
        </label>
      )}
      <button
        ref={triggerRef}
        type="button"
        id={triggerId}
        className="picker-field-trigger"
        aria-haspopup="listbox"
        aria-expanded={open}
        aria-required={required}
        aria-label={ariaLabel ?? (label ? `${label}: ${selectedLabel}` : selectedLabel)}
        disabled={disabled}
        onClick={() => !disabled && setOpen((current) => !current)}
      >
        <span className={`picker-field-trigger-value${!value ? ' picker-field-placeholder' : ''}`}>
          {selectedLabel}
        </span>
        <span className="picker-field-chevron" aria-hidden="true">
          ▾
        </span>
      </button>

      {usePortal && mounted ? createPortal(popover, document.body) : !usePortal && popover}
    </div>
  );
}

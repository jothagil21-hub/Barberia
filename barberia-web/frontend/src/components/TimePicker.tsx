'use client';

import { useEffect, useMemo, useRef, useState } from 'react';
import { usePopoverDismiss } from '@/hooks/usePopoverDismiss';
import { buildTimeSlots, formatTimeDisplay } from '@/lib/date-utils';

type TimePickerProps = {
  value: string;
  onChange: (time: string) => void;
  label?: string;
  id?: string;
  stepMinutes?: number;
};

export function TimePicker({
  value,
  onChange,
  label,
  id,
  stepMinutes = 15,
}: TimePickerProps) {
  const rootRef = useRef<HTMLDivElement>(null);
  const [open, setOpen] = useState(false);
  const slots = useMemo(() => buildTimeSlots(stepMinutes), [stepMinutes]);
  const triggerId = id ?? 'time-picker';

  usePopoverDismiss(open, () => setOpen(false), rootRef);

  useEffect(() => {
    if (!open) return;
    const selected = rootRef.current?.querySelector('.time-picker-slot-selected');
    selected?.scrollIntoView({ block: 'nearest' });
  }, [open]);

  function selectTime(time: string) {
    onChange(time);
    setOpen(false);
  }

  return (
    <div className={`picker-field time-picker${open ? ' picker-field-open' : ''}`} ref={rootRef}>
      {label && (
        <label htmlFor={triggerId} className="picker-field-label">
          {label}
        </label>
      )}
      <button
        type="button"
        id={triggerId}
        className="picker-field-trigger"
        aria-haspopup="dialog"
        aria-expanded={open}
        aria-label={label ? `${label}: ${formatTimeDisplay(value)}` : formatTimeDisplay(value)}
        onClick={() => setOpen((current) => !current)}
      >
        <span className="picker-field-trigger-value">{formatTimeDisplay(value)}</span>
        <span className="picker-field-chevron" aria-hidden="true">
          ▾
        </span>
      </button>

      {open && (
        <div className="picker-field-popover time-picker-popover" role="dialog" aria-label="Seleccionar hora">
          <div className="time-picker-slots">
            {slots.map((slot) => (
              <button
                key={slot}
                type="button"
                className={`time-picker-slot${slot === value ? ' time-picker-slot-selected' : ''}`}
                onClick={() => selectTime(slot)}
              >
                {slot}
              </button>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}

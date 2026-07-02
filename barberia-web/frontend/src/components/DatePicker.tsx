'use client';

import { useEffect, useMemo, useRef, useState } from 'react';
import { usePopoverDismiss } from '@/hooks/usePopoverDismiss';
import {
  addMonths,
  buildMonthDays,
  capitalize,
  isSameDay,
  parseIso,
  toIso,
} from '@/lib/date-utils';

type DatePickerProps = {
  value: string;
  onChange: (isoDate: string) => void;
  label?: string;
  id?: string;
};

const WEEKDAYS = ['LUN', 'MAR', 'MIÉ', 'JUE', 'VIE', 'SÁB', 'DOM'];

export function DatePicker({ value, onChange, label = 'Fecha', id = 'date-picker' }: DatePickerProps) {
  const rootRef = useRef<HTMLDivElement>(null);
  const [open, setOpen] = useState(false);
  const selected = useMemo(() => parseIso(value), [value]);
  const [viewMonth, setViewMonth] = useState(() => new Date(selected.getFullYear(), selected.getMonth(), 1));
  const today = useMemo(() => {
    const now = new Date();
    return new Date(now.getFullYear(), now.getMonth(), now.getDate());
  }, []);

  usePopoverDismiss(open, () => setOpen(false), rootRef);

  useEffect(() => {
    setViewMonth(new Date(selected.getFullYear(), selected.getMonth(), 1));
  }, [selected]);

  const monthDays = useMemo(() => buildMonthDays(viewMonth), [viewMonth]);

  const selectedDayLabel = capitalize(
    selected.toLocaleDateString('es-ES', { weekday: 'long', day: 'numeric' }),
  );
  const selectedMonthLabel = capitalize(
    viewMonth.toLocaleDateString('es-ES', { month: 'long', year: 'numeric' }),
  );
  const triggerValue = capitalize(
    selected.toLocaleDateString('es-ES', {
      weekday: 'short',
      day: 'numeric',
      month: 'short',
      year: 'numeric',
    }),
  );

  function selectDay(day: Date) {
    onChange(toIso(day));
    setOpen(false);
  }

  function goToday() {
    onChange(toIso(today));
    setViewMonth(new Date(today.getFullYear(), today.getMonth(), 1));
    setOpen(false);
  }

  return (
    <div className={`picker-field date-picker${open ? ' picker-field-open' : ''}`} ref={rootRef}>
      <button
        type="button"
        id={id}
        className="picker-field-trigger date-picker-trigger"
        aria-haspopup="dialog"
        aria-expanded={open}
        aria-label={`${label}: ${triggerValue}`}
        onClick={() => setOpen((current) => !current)}
      >
        <span className="picker-field-trigger-label date-picker-trigger-label">{label}</span>
        <span className="picker-field-trigger-value date-picker-trigger-value">{triggerValue}</span>
        <span className="picker-field-chevron date-picker-chevron" aria-hidden="true">
          ▾
        </span>
      </button>

      {open && (
        <div className="picker-field-popover date-picker-popover" role="dialog" aria-label="Seleccionar fecha">
          <div className="date-picker-popover-header">
            <div className="date-picker-popover-selected">{selectedDayLabel}</div>
            <div className="date-picker-popover-month">{selectedMonthLabel}</div>
          </div>

          <div className="date-picker-nav">
            <button
              type="button"
              className="date-picker-nav-btn"
              aria-label="Mes anterior"
              onClick={() => setViewMonth((current) => addMonths(current, -1))}
            >
              ‹
            </button>
            <button
              type="button"
              className="date-picker-nav-btn"
              aria-label="Mes siguiente"
              onClick={() => setViewMonth((current) => addMonths(current, 1))}
            >
              ›
            </button>
          </div>

          <div className="date-picker-weekdays">
            {WEEKDAYS.map((day) => (
              <span key={day} className="date-picker-weekday">
                {day}
              </span>
            ))}
          </div>

          <div className="date-picker-grid">
            {monthDays.map((day) => {
              const inMonth = day.getMonth() === viewMonth.getMonth();
              const isSelected = isSameDay(day, selected);
              const isToday = isSameDay(day, today);

              return (
                <button
                  key={toIso(day)}
                  type="button"
                  className={[
                    'date-picker-day',
                    !inMonth ? 'date-picker-day-outside' : '',
                    isSelected ? 'date-picker-day-selected' : '',
                    isToday && !isSelected ? 'date-picker-day-today' : '',
                  ]
                    .filter(Boolean)
                    .join(' ')}
                  onClick={() => selectDay(day)}
                >
                  {day.getDate()}
                </button>
              );
            })}
          </div>

          <div className="date-picker-footer">
            <button type="button" className="date-picker-footer-btn" onClick={goToday}>
              Hoy
            </button>
          </div>
        </div>
      )}
    </div>
  );
}

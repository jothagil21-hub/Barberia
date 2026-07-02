'use client';

import { useEffect, useId, useRef, useState } from 'react';
import { LoadingButton } from '@/components/LoadingButton';
import { Modal } from '@/components/Modal';

type PromptDialogProps = {
  open: boolean;
  title: string;
  description?: string;
  label?: string;
  defaultValue?: string;
  inputType?: 'text' | 'password';
  confirmLabel?: string;
  cancelLabel?: string;
  loadingLabel?: string;
  onConfirm: (value: string) => void | Promise<void>;
  onClose: () => void;
};

export function PromptDialog({
  open,
  title,
  description,
  label = 'Valor',
  defaultValue = '',
  inputType = 'text',
  confirmLabel = 'Confirmar',
  cancelLabel = 'Cancelar',
  loadingLabel = 'Guardando…',
  onConfirm,
  onClose,
}: PromptDialogProps) {
  const inputId = useId();
  const inputRef = useRef<HTMLInputElement>(null);
  const [value, setValue] = useState(defaultValue);
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    if (open) {
      setValue(defaultValue);
      setSubmitting(false);
      window.setTimeout(() => inputRef.current?.focus(), 0);
    }
  }, [open, defaultValue]);

  async function submit() {
    const trimmed = value.trim();
    if (!trimmed || submitting) return;
    setSubmitting(true);
    try {
      await onConfirm(trimmed);
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <Modal
      open={open}
      onClose={submitting ? () => {} : onClose}
      title={title}
      footer={
        <div className="modal-actions">
          <LoadingButton variant="secondary" disabled={submitting} onClick={onClose}>
            {cancelLabel}
          </LoadingButton>
          <LoadingButton
            loading={submitting}
            loadingText={loadingLabel}
            disabled={!value.trim()}
            onClick={() => void submit()}
          >
            {confirmLabel}
          </LoadingButton>
        </div>
      }
    >
      {description && <p className="muted prompt-dialog-description">{description}</p>}
      <div className="field prompt-dialog-field">
        <label htmlFor={inputId}>{label}</label>
        <input
          ref={inputRef}
          id={inputId}
          type={inputType}
          value={value}
          disabled={submitting}
          onChange={(event) => setValue(event.target.value)}
          onKeyDown={(event) => {
            if (event.key === 'Enter') {
              event.preventDefault();
              void submit();
            }
          }}
        />
      </div>
    </Modal>
  );
}

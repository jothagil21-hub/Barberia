'use client';

import { useRef, useState } from 'react';
import { InlineSpinner } from '@/components/InlineSpinner';
import { LoadingButton } from '@/components/LoadingButton';

type FileUploadProps = {
  accept?: string;
  onChange: (file: File | null) => void;
  previewUrl?: string | null;
  label?: string;
  disabled?: boolean;
  uploading?: boolean;
};

export function FileUpload({
  accept = 'image/*',
  onChange,
  previewUrl,
  label = 'Logo',
  disabled = false,
  uploading = false,
}: FileUploadProps) {
  const inputRef = useRef<HTMLInputElement>(null);
  const [fileName, setFileName] = useState<string | null>(null);

  function handleChange(event: React.ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0] ?? null;
    setFileName(file?.name ?? null);
    onChange(file);
  }

  return (
    <div className="file-upload">
      <span className="picker-field-label">{label}</span>
      <div className="logo-upload-row">
        {previewUrl ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img src={previewUrl} alt="Vista previa del logo" className="logo-preview" />
        ) : (
          <div className="logo-preview logo-preview-empty">Sin logo</div>
        )}
        <div className="file-upload-controls">
          <input
            ref={inputRef}
            type="file"
            accept={accept}
            className="file-upload-input"
            disabled={disabled}
            onChange={handleChange}
          />
          <LoadingButton
            variant="secondary"
            disabled={disabled || uploading}
            loading={uploading}
            loadingText="Subiendo…"
            onClick={() => inputRef.current?.click()}
          >
            Elegir imagen
          </LoadingButton>
          {uploading && <InlineSpinner label="Subiendo logo…" />}
          {!uploading && fileName && <span className="file-upload-name">{fileName}</span>}
        </div>
      </div>
    </div>
  );
}

'use client';

import { useMemo, useState } from 'react';
import { useToast } from '@/components/useToast';

type Props = {
  slug: string;
};

export function BookingLinkSection({ slug }: Props) {
  const { showSuccess } = useToast();
  const [copied, setCopied] = useState(false);

  const bookingUrl = useMemo(() => {
    if (typeof window === 'undefined') return '';
    return `${window.location.origin}/agendar/${slug}`;
  }, [slug]);

  const qrUrl = useMemo(() => {
    if (!bookingUrl) return '';
    return `https://quickchart.io/qr?size=200&margin=1&text=${encodeURIComponent(bookingUrl)}`;
  }, [bookingUrl]);

  async function copyLink() {
    if (!bookingUrl) return;
    await navigator.clipboard.writeText(bookingUrl);
    setCopied(true);
    showSuccess('Enlace copiado');
    setTimeout(() => setCopied(false), 2000);
  }

  if (!bookingUrl) return null;

  return (
    <div className="booking-link-section">
      <div className="field">
        <label htmlFor="booking-url">Enlace de reserva</label>
        <div className="booking-link-row">
          <input id="booking-url" readOnly value={bookingUrl} />
          <button type="button" className="btn btn-secondary" onClick={copyLink}>
            {copied ? 'Copiado' : 'Copiar'}
          </button>
        </div>
      </div>
      <div className="booking-qr">
        <p className="muted">Código QR</p>
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img src={qrUrl} alt={`QR para reservar en ${slug}`} width={200} height={200} />
      </div>
    </div>
  );
}

'use client';

import { FormEvent, useCallback, useEffect, useMemo, useState } from 'react';
import { useParams } from 'next/navigation';
import { BrandLogo } from '@/components/BrandLogo';
import { DatePicker } from '@/components/DatePicker';
import { InlineAlert } from '@/components/InlineAlert';
import { LoadingBlock } from '@/components/LoadingBlock';
import { LoadingButton } from '@/components/LoadingButton';
import { SelectField } from '@/components/SelectField';
import { logoSrc } from '@/lib/api';
import { toIso } from '@/lib/date-utils';

type Barber = { id: string; name: string };
type Service = { id: string; name: string; price: number; durationMinutes: number };

type Catalog = {
  displayName: string;
  logoUrl: string | null;
  scheduleStart: string;
  scheduleEnd: string;
  scheduleInterval: number;
  barbers: Barber[];
  services: Service[];
};

function todayIso() {
  return toIso(new Date());
}

export default function PublicBookingPage() {
  const params = useParams();
  const slug = params.slug as string;

  const [catalog, setCatalog] = useState<Catalog | null>(null);
  const [loadError, setLoadError] = useState('');
  const [loading, setLoading] = useState(true);

  const [clientName, setClientName] = useState('');
  const [clientPhone, setClientPhone] = useState('');
  const [barberId, setBarberId] = useState('');
  const [serviceIds, setServiceIds] = useState<string[]>([]);
  const [date, setDate] = useState(todayIso);
  const [time, setTime] = useState('');
  const [slots, setSlots] = useState<string[]>([]);
  const [slotsLoading, setSlotsLoading] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [success, setSuccess] = useState(false);
  const [formError, setFormError] = useState('');

  useEffect(() => {
    fetch(`/api/public/booking/${slug}`)
      .then(async (res) => {
        if (!res.ok) {
          const data = await res.json().catch(() => ({}));
          throw new Error(data.error ?? 'No se pudo cargar la barbería');
        }
        return res.json() as Promise<Catalog>;
      })
      .then((data) => {
        setCatalog(data);
        if (data.barbers.length > 0) setBarberId(data.barbers[0].id);
      })
      .catch((err) => {
        setLoadError(err instanceof Error ? err.message : 'Error al cargar');
      })
      .finally(() => setLoading(false));
  }, [slug]);

  const selectedServices = useMemo(
    () => catalog?.services.filter((s) => serviceIds.includes(s.id)) ?? [],
    [catalog, serviceIds],
  );

  const totalDuration = selectedServices.reduce((sum, s) => sum + s.durationMinutes, 0);
  const totalPrice = selectedServices.reduce((sum, s) => sum + s.price, 0);

  const loadSlots = useCallback(async () => {
    if (!barberId || serviceIds.length === 0 || !date) {
      setSlots([]);
      setTime('');
      return;
    }
    setSlotsLoading(true);
    setFormError('');
    try {
      const qs = new URLSearchParams({
        barberId,
        date,
        serviceIds: serviceIds.join(','),
      });
      const res = await fetch(`/api/public/booking/${slug}/slots?${qs}`);
      const data = await res.json();
      if (!res.ok) throw new Error(data.error ?? 'No se pudieron cargar horarios');
      setSlots(data.slots as string[]);
      setTime((prev) => (data.slots.includes(prev) ? prev : ''));
    } catch (err) {
      setSlots([]);
      setTime('');
      setFormError(err instanceof Error ? err.message : 'Error al cargar horarios');
    } finally {
      setSlotsLoading(false);
    }
  }, [barberId, date, serviceIds, slug]);

  useEffect(() => {
    void loadSlots();
  }, [loadSlots]);

  function toggleService(id: string) {
    setServiceIds((prev) =>
      prev.includes(id) ? prev.filter((s) => s !== id) : [...prev, id],
    );
  }

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    setFormError('');
    if (!time) {
      setFormError('Selecciona un horario disponible');
      return;
    }
    setSubmitting(true);
    try {
      const res = await fetch(`/api/public/booking/${slug}/requests`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          clientName,
          clientPhone,
          barberId,
          date,
          time,
          serviceIds,
        }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error ?? 'No se pudo enviar la solicitud');
      setSuccess(true);
    } catch (err) {
      setFormError(err instanceof Error ? err.message : 'Error al enviar');
    } finally {
      setSubmitting(false);
    }
  }

  if (loading) {
    return (
      <main className="container booking-page">
        <LoadingBlock label="Cargando…" />
      </main>
    );
  }

  if (loadError || !catalog) {
    return (
      <main className="container booking-page">
        <InlineAlert message={loadError || 'Barbería no encontrada'} />
      </main>
    );
  }

  if (success) {
    return (
      <main className="container booking-page">
        <div className="card booking-success">
          <h1>Solicitud enviada</h1>
          <p>
            Tu cita queda <strong>pendiente de confirmación</strong>. La barbería tiene hasta 24
            horas para aceptarla. Te contactarán al teléfono indicado si es necesario.
          </p>
        </div>
      </main>
    );
  }

  const catalogLogoUrl = logoSrc(catalog.logoUrl);

  return (
    <main className="container booking-page">
      <header className="booking-header">
        {catalogLogoUrl ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={catalogLogoUrl}
            alt=""
            className="booking-logo"
            width={56}
            height={56}
          />
        ) : (
          <BrandLogo size="lg" />
        )}
        <div>
          <h1>{catalog.displayName}</h1>
          <p className="muted">
            Horario {catalog.scheduleStart} – {catalog.scheduleEnd}
          </p>
        </div>
      </header>

      <div className="card">
        <h2>Reservar cita</h2>
        <p className="muted booking-note">
          Completa el formulario. La barbería confirmará tu solicitud en un plazo máximo de 24
          horas.
        </p>

        {formError && <InlineAlert message={formError} />}

        <form onSubmit={onSubmit} className="booking-form">
          <div className="field">
            <label htmlFor="clientName">Nombre</label>
            <input
              id="clientName"
              value={clientName}
              onChange={(e) => setClientName(e.target.value)}
              required
              maxLength={120}
              autoComplete="name"
            />
          </div>

          <div className="field">
            <label htmlFor="clientPhone">Teléfono</label>
            <input
              id="clientPhone"
              type="tel"
              value={clientPhone}
              onChange={(e) => setClientPhone(e.target.value)}
              required
              minLength={6}
              maxLength={30}
              autoComplete="tel"
              placeholder="Ej. 300 123 4567"
            />
          </div>

          <SelectField
            id="barber"
            label="Barbero"
            value={barberId}
            onChange={setBarberId}
            options={catalog.barbers.map((b) => ({ value: b.id, label: b.name }))}
          />

          <fieldset className="booking-services">
            <legend>Servicios</legend>
            {catalog.services.map((service) => (
              <label key={service.id} className="booking-service-option">
                <input
                  type="checkbox"
                  checked={serviceIds.includes(service.id)}
                  onChange={() => toggleService(service.id)}
                />
                <span>
                  {service.name} — {service.durationMinutes} min — $
                  {service.price.toLocaleString('es-CO')}
                </span>
              </label>
            ))}
          </fieldset>

          {selectedServices.length > 0 && (
            <p className="muted">
              Duración total: {totalDuration} min · Total estimado: $
              {totalPrice.toLocaleString('es-CO')}
            </p>
          )}

          <DatePicker value={date} onChange={setDate} label="Fecha" id="booking-date" />

          <div className="field">
            <span className="field-label">Hora disponible</span>
            {slotsLoading ? (
              <p className="muted">Cargando horarios…</p>
            ) : serviceIds.length === 0 ? (
              <p className="muted">Selecciona al menos un servicio</p>
            ) : slots.length === 0 ? (
              <p className="muted">No hay horarios libres para esta fecha</p>
            ) : (
              <div className="booking-slot-grid">
                {slots.map((slot) => (
                  <button
                    key={slot}
                    type="button"
                    className={`booking-slot${time === slot ? ' booking-slot--selected' : ''}`}
                    onClick={() => setTime(slot)}
                  >
                    {slot}
                  </button>
                ))}
              </div>
            )}
          </div>

          <LoadingButton
            type="submit"
            loading={submitting}
            loadingText="Enviando…"
            disabled={submitting || serviceIds.length === 0 || !time}
          >
            Enviar solicitud
          </LoadingButton>
        </form>
      </div>
    </main>
  );
}

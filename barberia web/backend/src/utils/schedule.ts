/**
 * Reglas de horario — mismas que la app móvil (schedule_config_validator.dart).
 * Intervalos: 15, 20, 30, 45, 60 min. Inicio debe ser antes que cierre.
 */

export const ALLOWED_INTERVALS = [15, 20, 30, 45, 60] as const;

export type ScheduleInput = {
  scheduleStart: string;
  scheduleEnd: string;
  scheduleInterval: number;
};

function parseMinutes(time: string): number {
  const parts = time.split(':');
  if (parts.length !== 2) {
    throw new Error(`Formato de hora inválido: ${time}`);
  }
  const hours = Number(parts[0]);
  const minutes = Number(parts[1]);
  if (Number.isNaN(hours) || Number.isNaN(minutes)) {
    throw new Error(`Formato de hora inválido: ${time}`);
  }
  return hours * 60 + minutes;
}

function countSlots(config: ScheduleInput): number {
  const start = parseMinutes(config.scheduleStart);
  const end = parseMinutes(config.scheduleEnd);
  let count = 0;
  for (let t = start; t < end; t += config.scheduleInterval) {
    count++;
  }
  return count;
}

export function validateScheduleConfig(config: ScheduleInput): void {
  if (!ALLOWED_INTERVALS.includes(config.scheduleInterval as (typeof ALLOWED_INTERVALS)[number])) {
    throw new Error(
      `El intervalo debe ser uno de: ${ALLOWED_INTERVALS.join(', ')} minutos.`,
    );
  }
  if (parseMinutes(config.scheduleStart) >= parseMinutes(config.scheduleEnd)) {
    throw new Error('La hora de inicio debe ser anterior a la de cierre.');
  }
  if (countSlots(config) === 0) {
    throw new Error('El rango horario no genera ningún turno.');
  }
}

/** Genera slug URL-friendly a partir del nombre de la barbería. */
export function slugify(name: string): string {
  return (
    name
      .toLowerCase()
      .normalize('NFD')
      .replace(/[\u0300-\u036f]/g, '')
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/^-+|-+$/g, '')
      .slice(0, 80) || 'barberia'
  );
}

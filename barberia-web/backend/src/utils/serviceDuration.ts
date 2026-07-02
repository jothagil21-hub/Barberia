export const SERVICE_DURATION_BLOCK = 15;
export const SERVICE_DURATION_MIN = 15;
export const SERVICE_DURATION_MAX = 180;
export const SERVICE_DURATION_DEFAULT = 30;

export function validateServiceDuration(minutes: number): void {
  if (!Number.isInteger(minutes) || minutes < SERVICE_DURATION_MIN || minutes > SERVICE_DURATION_MAX) {
    throw new Error(
      `La duración debe estar entre ${SERVICE_DURATION_MIN} y ${SERVICE_DURATION_MAX} minutos.`,
    );
  }
  if (minutes % SERVICE_DURATION_BLOCK !== 0) {
    throw new Error(`La duración debe ser múltiplo de ${SERVICE_DURATION_BLOCK} minutos.`);
  }
}

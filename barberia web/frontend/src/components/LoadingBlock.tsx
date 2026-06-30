type LoadingBlockProps = {
  label?: string;
};

/** Indicador de carga con spinner. */
export function LoadingBlock({ label = 'Cargando…' }: LoadingBlockProps) {
  return (
    <div className="loading-block" role="status">
      <div className="spinner" aria-hidden />
      <span className="muted">{label}</span>
    </div>
  );
}

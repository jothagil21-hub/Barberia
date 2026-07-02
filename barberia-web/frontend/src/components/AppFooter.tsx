/** Pie de página global del panel (fondo gris oscuro). */
export function AppFooter() {
  const year = new Date().getFullYear();

  return (
    <footer className="app-footer">
      <div className="app-footer-inner">
        <span className="app-footer-brand">BarberiaApp Panel</span>
        <span className="app-footer-muted">© {year} — Gestión de barberías</span>
      </div>
    </footer>
  );
}

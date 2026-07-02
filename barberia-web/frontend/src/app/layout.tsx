import type { Metadata } from 'next';
import './globals.css';
import { AppFooter } from '@/components/AppFooter';
import { Providers } from '@/components/Providers';

export const metadata: Metadata = {
  title: 'BarberiaApp — Panel',
  description: 'Panel super-admin de BarberiaApp',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="es">
      <body>
        <Providers>
          <div className="app-shell">
            <div className="app-shell-content">{children}</div>
            <AppFooter />
          </div>
        </Providers>
      </body>
    </html>
  );
}

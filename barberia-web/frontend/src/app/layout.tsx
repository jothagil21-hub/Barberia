import type { Metadata } from 'next';
import Script from 'next/script';
import './globals.css';
import { AppFooter } from '@/components/AppFooter';
import { Providers } from '@/components/Providers';
import { themeInitScript } from '@/lib/theme';

export const metadata: Metadata = {
  title: 'BarberiaApp — Panel',
  description: 'Panel super-admin de BarberiaApp',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="es" suppressHydrationWarning>
      <body>
        <Script id="theme-init" strategy="beforeInteractive">
          {themeInitScript}
        </Script>
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

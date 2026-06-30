import { jsPDF } from 'jspdf';
import type { TenantPosInvoice } from './api';

function formatPrice(value: number): string {
  return new Intl.NumberFormat('es-ES', { style: 'currency', currency: 'EUR' }).format(value);
}

function formatIssuedAt(iso: string): string {
  const d = new Date(iso);
  return Number.isNaN(d.getTime()) ? iso : d.toLocaleString('es-ES');
}

export function buildPosInvoicePdf(
  invoice: TenantPosInvoice,
  shopName: string,
): jsPDF {
  const doc = new jsPDF({ unit: 'mm', format: 'a4' });
  let y = 20;

  doc.setFontSize(18);
  doc.setFont('helvetica', 'bold');
  doc.text(shopName, 20, y);
  y += 8;

  doc.setFontSize(11);
  doc.setFont('helvetica', 'normal');
  doc.text(`Comprobante POS #${invoice.number}`, 20, y);
  y += 6;
  doc.text(`Emitido: ${formatIssuedAt(invoice.issuedAt)}`, 20, y);
  y += 10;

  doc.text(`Cliente: ${invoice.clientName}`, 20, y);
  y += 6;
  if (invoice.barberName) {
    doc.text(`Barbero: ${invoice.barberName}`, 20, y);
    y += 6;
  }
  y += 6;

  doc.setFont('helvetica', 'bold');
  doc.text('Servicio', 20, y);
  doc.text('Duración', 90, y);
  doc.text('Precio', 130, y);
  doc.text('Total', 165, y);
  y += 2;
  doc.line(20, y, 190, y);
  y += 6;

  doc.setFont('helvetica', 'normal');
  for (const line of invoice.lines) {
    if (y > 270) {
      doc.addPage();
      y = 20;
    }
    doc.text(line.serviceName, 20, y, { maxWidth: 65 });
    doc.text(`${line.durationMinutes} min`, 90, y);
    doc.text(formatPrice(line.unitPrice), 130, y);
    doc.text(formatPrice(line.lineTotal), 165, y);
    y += 8;
  }

  y += 4;
  doc.setFont('helvetica', 'bold');
  doc.text(`Total: ${formatPrice(invoice.subtotal)}`, 165, y, { align: 'right' });

  return doc;
}

export function downloadPosInvoicePdf(invoice: TenantPosInvoice, shopName: string): void {
  const doc = buildPosInvoicePdf(invoice, shopName);
  doc.save(`comprobante-${invoice.number}.pdf`);
}

export function openPosInvoicePdf(invoice: TenantPosInvoice, shopName: string): void {
  const doc = buildPosInvoicePdf(invoice, shopName);
  const blob = doc.output('blob');
  const url = URL.createObjectURL(blob);
  window.open(url, '_blank', 'noopener,noreferrer');
  window.setTimeout(() => URL.revokeObjectURL(url), 60_000);
}

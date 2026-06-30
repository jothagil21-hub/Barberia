import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../utils/currency_formatter.dart';
import '../../data/models/pos_invoice.dart';

class PosInvoicePdfExporter {
  Future<void> exportAndShare({
    required PosInvoice invoice,
    required String shopName,
  }) async {
    final pdf = pw.Document();
    final issued = DateTime.tryParse(invoice.issuedAt);
    final issuedLabel = issued != null
        ? DateFormat('d/M/yyyy HH:mm').format(issued)
        : invoice.issuedAt;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              shopName,
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Text('Comprobante POS #${invoice.number}'),
            pw.Text('Emitido: $issuedLabel'),
            pw.SizedBox(height: 16),
            pw.Text('Cliente: ${invoice.clientName}'),
            if (invoice.barberName != null)
              pw.Text('Barbero: ${invoice.barberName}'),
            pw.SizedBox(height: 16),
            pw.TableHelper.fromTextArray(
              headers: ['Servicio', 'Duración', 'Precio', 'Total'],
              data: invoice.lines
                  .map(
                    (line) => [
                      line.serviceName,
                      '${line.durationMinutes} min',
                      CurrencyFormatter.format(line.unitPrice),
                      CurrencyFormatter.format(line.lineTotal),
                    ],
                  )
                  .toList(),
            ),
            pw.SizedBox(height: 16),
            pw.Text(
              'Total: ${CurrencyFormatter.format(invoice.subtotal)}',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/comprobante-${invoice.number}.pdf');
    await file.writeAsBytes(await pdf.save());
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], text: 'Comprobante #${invoice.number}'),
    );
  }
}

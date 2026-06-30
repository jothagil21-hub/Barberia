import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../core/constants/appointment_status.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/appointment.dart';
import 'export_appointment_grouper.dart';
import 'export_attended_totals.dart';

class AppointmentPdfExporter {
  Future<void> exportAndShare({
    required List<Appointment> appointments,
    required DateTime startDate,
    required DateTime endDate,
    required String shopName,
    String? logoPath,
  }) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('d/M/yyyy');
    final generatedAt = DateFormat('d/M/yyyy HH:mm').format(DateTime.now());
    final groups = groupAppointmentsForExport(appointments);

    pw.Widget? logoWidget;
    if (logoPath != null && logoPath.isNotEmpty) {
      final file = File(logoPath);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        logoWidget = pw.Image(
          pw.MemoryImage(bytes),
          width: 48,
          height: 48,
        );
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (logoWidget != null) ...[
                logoWidget,
                pw.SizedBox(width: 12),
              ],
              pw.Expanded(
                child: pw.Text(
                  '$shopName — Reporte de citas',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Del ${dateFormat.format(startDate)} al ${dateFormat.format(endDate)}',
            style: const pw.TextStyle(fontSize: 12),
          ),
          pw.SizedBox(height: 16),
          if (groups.isEmpty)
            pw.Text('No hay citas en el rango seleccionado.')
          else ...[
            ..._buildGroupedContent(groups, dateFormat),
            pw.SizedBox(height: 20),
            pw.Text(
              'Total general (asistió): ${CurrencyFormatter.format(sumAttendedTotal(appointments))}',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
          pw.SizedBox(height: 24),
          pw.Text(
            'Generado el $generatedAt',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
        ],
      ),
    );

    final bytes = await pdf.save();
    final directory = await getTemporaryDirectory();
    final fileName =
        'citas_${DateFormat('yyyyMMdd').format(startDate)}_${DateFormat('yyyyMMdd').format(endDate)}.pdf';
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(bytes);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/pdf')],
        subject: 'Reporte de citas — $shopName',
      ),
    );
  }

  List<pw.Widget> _buildGroupedContent(
    List<ExportBarberGroup> groups,
    DateFormat dateFormat,
  ) {
    final widgets = <pw.Widget>[];

    for (var barberIndex = 0; barberIndex < groups.length; barberIndex++) {
      final barberGroup = groups[barberIndex];

      if (barberIndex > 0) {
        widgets.add(pw.SizedBox(height: 20));
      }

      widgets.add(
        pw.Text(
          'Barbero: ${barberGroup.barberName}',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      );
      widgets.add(pw.SizedBox(height: 8));

      for (var dateIndex = 0; dateIndex < barberGroup.dates.length; dateIndex++) {
        final dateGroup = barberGroup.dates[dateIndex];

        if (dateIndex > 0) {
          widgets.add(pw.SizedBox(height: 12));
        }

        widgets.add(
          pw.Text(
            dateFormat.format(DateTime.parse(dateGroup.date)),
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        );
        widgets.add(pw.SizedBox(height: 6));
        widgets.add(
          pw.TableHelper.fromTextArray(
            headers: const [
              'Hora',
              'Cliente',
              'Servicios',
              'Total',
              'Estado',
            ],
            data: dateGroup.appointments
                .map(
                  (appointment) => [
                    appointment.time,
                    appointment.clientName,
                    appointment.servicesLabel,
                    CurrencyFormatter.format(appointment.totalPrice),
                    appointment.status.displayLabel,
                  ],
                )
                .toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.centerLeft,
            headerDecoration:
                const pw.BoxDecoration(color: PdfColors.grey300),
            cellHeight: 28,
          ),
        );
      }

      widgets.add(pw.SizedBox(height: 8));
      widgets.add(
        pw.Text(
          'Total ${barberGroup.barberName} (asistió): ${CurrencyFormatter.format(sumAttendedTotalForBarberGroup(barberGroup))}',
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      );
    }

    return widgets;
  }
}

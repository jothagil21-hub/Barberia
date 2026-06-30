import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/constants/app_branding.dart';
import '../core/export/appointment_pdf_exporter.dart';
import '../providers/providers.dart';
import '../widgets/date_selector.dart';

class ExportAppointmentsScreen extends ConsumerStatefulWidget {
  const ExportAppointmentsScreen({super.key});

  @override
  ConsumerState<ExportAppointmentsScreen> createState() =>
      _ExportAppointmentsScreenState();
}

class _ExportAppointmentsScreenState
    extends ConsumerState<ExportAppointmentsScreen> {
  late DateTime _startDate;
  late DateTime _endDate;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _endDate = DateTime(now.year, now.month, now.day);
    _startDate = _endDate.subtract(const Duration(days: 30));
  }

  Future<void> _export() async {
    if (_startDate.isAfter(_endDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La fecha inicial no puede ser posterior a la final.'),
        ),
      );
      return;
    }

    setState(() => _exporting = true);

    try {
      final repo = ref.read(appointmentRepositoryProvider);
      final start = DateFormat('yyyy-MM-dd').format(_startDate);
      final end = DateFormat('yyyy-MM-dd').format(_endDate);
      final appointments = await repo.getAppointmentsInRange(start, end);
      final settings = ref.read(appSettingsProvider).maybeWhen(
            data: (value) => value,
            orElse: () => null,
          );

      await AppointmentPdfExporter().exportAndShare(
        appointments: appointments,
        startDate: _startDate,
        endDate: _endDate,
        shopName: settings?.shopName ?? AppBranding.shopName,
        logoPath: settings?.logoPath,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al exportar: $error')),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Exportar citas')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Selecciona el rango de fechas',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'El PDF incluirá citas programadas y canceladas, agrupadas por barbero y por fecha.',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 24),
          const Text(
            'Desde',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          DateSelector(
            selectedDate: _startDate,
            allowPastDates: true,
            onDateChanged: (date) => setState(() => _startDate = date),
          ),
          const SizedBox(height: 24),
          const Text(
            'Hasta',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          DateSelector(
            selectedDate: _endDate,
            allowPastDates: true,
            onDateChanged: (date) => setState(() => _endDate = date),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: _exporting ? null : _export,
            icon: _exporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf),
            label: Text(
              _exporting ? 'Generando PDF...' : 'Generar y compartir PDF',
            ),
          ),
        ],
      ),
    );
  }
}

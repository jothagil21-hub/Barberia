import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import 'package:intl/intl.dart';



import '../core/constants/appointment_status.dart';

import '../core/notifications/appointment_notification_sync.dart';

import '../core/theme/app_theme.dart';

import '../core/export/pos_invoice_pdf_exporter.dart';

import '../core/utils/currency_formatter.dart';

import '../data/repositories/pos_invoice_repository.dart';

import '../providers/providers.dart';
import '../widgets/text_input_dialog.dart';



class AppointmentDetailScreen extends ConsumerWidget {

  const AppointmentDetailScreen({super.key, required this.appointmentId});



  final int appointmentId;



  Future<void> _editClientName(
    BuildContext context,
    WidgetRef ref,
    String currentName,
  ) async {
    final newName = await showTextInputDialog(
      context,
      title: 'Editar cliente',
      label: 'Nombre del cliente',
      initialValue: currentName,
    );

    if (newName == null || !context.mounted) return;

    if (newName == currentName) return;

    try {
      final repo = ref.read(appointmentRepositoryProvider);
      await repo.updateClientName(id: appointmentId, clientName: newName);
      refreshAppointments(ref);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nombre actualizado')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $error')),
      );
    }
  }

  Future<void> _reactivate(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reactivar cita'),
        content: const Text(
          '¿Deseas reactivar esta cita? Volverá a la agenda si el horario sigue disponible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí, reactivar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      final repo = ref.read(appointmentRepositoryProvider);
      await repo.reactivateAppointment(appointmentId);

      final reminderResult = await syncReminderById(repo, appointmentId);
      refreshAppointments(ref);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cita reactivada')),
      );
      showReminderSyncSnackBar(
        reminderResult,
        (message) => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        ),
      );
      context.pop();
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $error')),
      );
    }
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {

    final confirmed = await showDialog<bool>(

      context: context,

      builder: (context) => AlertDialog(

        title: const Text('Cancelar cita'),

        content: const Text(

          '¿Deseas cancelar esta cita? El horario quedará disponible y la cita pasará al historial de canceladas.',

        ),

        actions: [

          TextButton(

            onPressed: () => Navigator.pop(context, false),

            child: const Text('No'),

          ),

          FilledButton(

            onPressed: () => Navigator.pop(context, true),

            child: const Text('Sí, cancelar'),

          ),

        ],

      ),

    );



    if (confirmed != true || !context.mounted) return;



    try {

      final repo = ref.read(appointmentRepositoryProvider);

      await repo.cancelAppointment(appointmentId);

      await cancelReminderForAppointment(appointmentId);

      refreshAppointments(ref);



      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(

        const SnackBar(content: Text('Cita cancelada')),

      );

      context.pop();

    } catch (error) {

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(

        SnackBar(content: Text('Error: $error')),

      );

    }

  }



  Future<void> _showInvoice(BuildContext context, WidgetRef ref) async {
    final invoice = await PosInvoiceRepository().getByAppointmentId(appointmentId);
    if (!context.mounted) return;
    if (invoice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay comprobante para esta cita.')),
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Comprobante #${invoice.number}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Cliente: ${invoice.clientName}'),
              if (invoice.barberName != null) Text('Barbero: ${invoice.barberName}'),
              const SizedBox(height: 12),
              ...invoice.lines.map(
                (line) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '${line.serviceName} · ${line.durationMinutes} min · '
                    '${CurrencyFormatter.format(line.lineTotal)}',
                  ),
                ),
              ),
              const Divider(),
              Text(
                'Total: ${CurrencyFormatter.format(invoice.subtotal)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          FilledButton.icon(
            onPressed: () async {
              final settings = await ref.read(settingsRepositoryProvider).getSettings();
              if (!context.mounted) return;
              await PosInvoicePdfExporter().exportAndShare(
                invoice: invoice,
                shopName: settings.shopName,
              );
            },
            icon: const Icon(Icons.share),
            label: const Text('Compartir PDF'),
          ),
        ],
      ),
    );
  }



  Future<void> _rejectPending(BuildContext context, WidgetRef ref) async {
    try {
      final repo = ref.read(appointmentRepositoryProvider);
      await repo.rejectPendingRequest(appointmentId);
      refreshAppointments(ref);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitud rechazada')),
      );
      context.pop();
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $error')),
      );
    }
  }

  Future<void> _acceptPending(BuildContext context, WidgetRef ref) async {
    try {
      final repo = ref.read(appointmentRepositoryProvider);
      await repo.acceptPendingRequest(appointmentId);
      await syncReminderById(repo, appointmentId);
      refreshAppointments(ref);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitud aceptada')),
      );
      context.pop();
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $error')),
      );
    }
  }

  Future<void> _markAttendance(

    BuildContext context,

    WidgetRef ref, {

    required bool attended,

  }) async {

    try {

      final repo = ref.read(appointmentRepositoryProvider);

      if (attended) {
        await repo.markAttended(appointmentId, createInvoice: true);
      } else {

        await repo.markNoShow(appointmentId);

      }

      await cancelReminderForAppointment(appointmentId);

      refreshAppointments(ref);



      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(

        SnackBar(

          content: Text(attended ? 'Marcada como asistió.' : 'Marcada como no asistió.'),

        ),

      );

      context.pop();

    } catch (error) {

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(

        SnackBar(content: Text('Error: $error')),

      );

    }

  }



  @override

  Widget build(BuildContext context, WidgetRef ref) {

    final appointmentAsync = ref.watch(appointmentDetailProvider(appointmentId));



    return Scaffold(

      appBar: AppBar(title: const Text('Detalle de cita')),

      body: appointmentAsync.when(

        loading: () => const Center(child: CircularProgressIndicator()),

        error: (error, _) => Center(child: Text('Error: $error')),

        data: (appointment) {

          if (appointment == null) {

            return const Center(child: Text('Cita no encontrada'));

          }



          final dateLabel = DateFormat('EEEE d MMMM yyyy', 'es')

              .format(DateTime.parse(appointment.date));

          final canMarkAttendance =

              appointment.canMarkAttendanceAt(DateTime.now());

          final isOwner = ref.watch(authProvider).value?.isOwner ?? true;

          return Padding(

            padding: const EdgeInsets.all(16),

            child: Column(

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                if (!appointment.isScheduled)

                  Container(

                    padding:

                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),

                    decoration: BoxDecoration(

                      color: _statusColor(appointment.status)

                          .withValues(alpha: 0.2),

                      borderRadius: BorderRadius.circular(8),

                    ),

                    child: Text(

                      appointment.status.displayLabel.toUpperCase(),

                      style: TextStyle(

                        color: _statusColor(appointment.status),

                        fontWeight: FontWeight.bold,

                      ),

                    ),

                  ),

                if (!appointment.isScheduled) const SizedBox(height: 16),

                _DetailRow(label: 'Cliente', value: appointment.clientName),

                if (appointment.clientPhone != null)
                  _DetailRow(label: 'Teléfono', value: appointment.clientPhone!),

                if (appointment.barberName != null)

                  _DetailRow(label: 'Barbero', value: appointment.barberName!),

                _DetailRow(

                  label: 'Fecha',

                  value: dateLabel[0].toUpperCase() + dateLabel.substring(1),

                ),

                _DetailRow(label: 'Hora', value: appointment.time),

                _DetailRow(
                  label: 'Duración',
                  value: '${appointment.durationMinutes} min',
                ),

                _DetailRow(label: 'Servicios', value: appointment.servicesLabel),

                if (appointment.totalPrice > 0)

                  _DetailRow(

                    label: 'Total',

                    value: CurrencyFormatter.format(appointment.totalPrice),

                  ),

                if (appointment.canceledAt != null)

                  _DetailRow(

                    label: 'Cancelada el',

                    value: DateFormat('d/M/yyyy HH:mm')

                        .format(DateTime.parse(appointment.canceledAt!)),

                  ),

                const Spacer(),

                if (appointment.isPending) ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _acceptPending(context, ref),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Aceptar solicitud'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _rejectPending(context, ref),
                      icon: const Icon(Icons.close),
                      label: const Text('Rechazar'),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                if (appointment.isAttended && isOwner) ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _showInvoice(context, ref),
                      icon: const Icon(Icons.receipt_long_outlined),
                      label: const Text('Ver comprobante'),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                if (appointment.isScheduled && !appointment.canModify)

                  Container(

                    width: double.infinity,

                    padding: const EdgeInsets.all(12),

                    decoration: BoxDecoration(

                      color: AppTheme.canceled.withValues(alpha: 0.15),

                      borderRadius: BorderRadius.circular(8),

                    ),

                    child: Text(

                      canMarkAttendance

                          ? 'Esta cita ya pasó. Registra si el cliente asistió.'

                          : 'Esta cita ya pasó y no puede modificarse',

                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(

                            color: AppTheme.textSecondary,

                          ),

                    ),

                  ),

                if (canMarkAttendance) ...[

                  SizedBox(

                    width: double.infinity,

                    child: FilledButton.icon(

                      onPressed: () => _markAttendance(context, ref, attended: true),

                      icon: const Icon(Icons.check_circle_outline),

                      label: const Text('Asistió'),

                    ),

                  ),

                  const SizedBox(height: 12),

                  SizedBox(

                    width: double.infinity,

                    child: OutlinedButton.icon(

                      onPressed: () => _markAttendance(context, ref, attended: false),

                      icon: const Icon(Icons.person_off_outlined),

                      label: const Text('No asistió'),

                    ),

                  ),

                ],

                if (appointment.canReactivateAt(DateTime.now())) ...[

                  SizedBox(

                    width: double.infinity,

                    child: FilledButton.icon(

                      onPressed: () => _reactivate(context, ref),

                      icon: const Icon(Icons.restore),

                      label: const Text('Reactivar cita'),

                    ),

                  ),

                ],

                if (appointment.canModify) ...[

                  SizedBox(

                    width: double.infinity,

                    child: OutlinedButton.icon(

                      onPressed: () => _editClientName(

                        context,

                        ref,

                        appointment.clientName,

                      ),

                      icon: const Icon(Icons.edit_outlined),

                      label: const Text('Editar cliente'),

                    ),

                  ),

                  const SizedBox(height: 12),

                  SizedBox(

                    width: double.infinity,

                    child: FilledButton.icon(

                      onPressed: () => context.push(

                        '/appointment/$appointmentId/reschedule',

                      ),

                      icon: const Icon(Icons.event_repeat),

                      label: const Text('Reagendar cita'),

                    ),

                  ),

                  const SizedBox(height: 12),

                  SizedBox(

                    width: double.infinity,

                    child: OutlinedButton.icon(

                      onPressed: () => _cancel(context, ref),

                      icon: const Icon(Icons.cancel_outlined),

                      label: const Text('Cancelar cita'),

                      style: OutlinedButton.styleFrom(

                        foregroundColor: Theme.of(context).colorScheme.error,

                        side: BorderSide(

                          color: Theme.of(context).colorScheme.error,

                        ),

                      ),

                    ),

                  ),

                ],

              ],

            ),

          );

        },

      ),

    );

  }



  Color _statusColor(AppointmentStatus status) {
    switch (status) {
      case AppointmentStatus.pending:
        return Colors.orange;
      case AppointmentStatus.canceled:

        return AppTheme.canceled;

      case AppointmentStatus.attended:

        return AppTheme.accent;

      case AppointmentStatus.noShow:
        return Colors.redAccent;

      case AppointmentStatus.scheduled:

        return AppTheme.textPrimary;

    }

  }

}



class _DetailRow extends StatelessWidget {

  const _DetailRow({required this.label, required this.value});



  final String label;

  final String value;



  @override

  Widget build(BuildContext context) {

    return Padding(

      padding: const EdgeInsets.only(bottom: 16),

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Text(

            label,

            style: Theme.of(context).textTheme.bodySmall,

          ),

          const SizedBox(height: 4),

          Text(

            value,

            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),

          ),

        ],

      ),

    );

  }

}


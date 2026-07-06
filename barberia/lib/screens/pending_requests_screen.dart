import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../core/notifications/appointment_notification_sync.dart';
import '../core/theme/app_theme.dart';
import '../providers/providers.dart';
import '../widgets/appointment_card.dart';

class PendingRequestsScreen extends ConsumerWidget {
  const PendingRequestsScreen({super.key});

  Future<void> _accept(BuildContext context, WidgetRef ref, int id) async {
    try {
      final repo = ref.read(appointmentRepositoryProvider);
      await repo.acceptPendingRequest(id);
      await syncReminderById(repo, id);
      refreshAppointments(ref);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitud aceptada')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $error')),
      );
    }
  }

  Future<void> _reject(BuildContext context, WidgetRef ref, int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rechazar solicitud'),
        content: const Text('¿Confirmas que deseas rechazar esta solicitud?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final repo = ref.read(appointmentRepositoryProvider);
      await repo.rejectPendingRequest(id);
      refreshAppointments(ref);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitud rechazada')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingAppointmentsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Solicitudes pendientes')),
      body: pendingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
        data: (appointments) {
          if (appointments.isEmpty) {
            return const Center(
              child: Text('No hay solicitudes pendientes'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: appointments.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final appointment = appointments[index];
              final expires = appointment.pendingExpiresAt;
              final expiresLabel = expires == null
                  ? null
                  : DateFormat('d/M HH:mm').format(DateTime.parse(expires));

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppointmentCard(
                        appointment: appointment,
                        onTap: () => context.push('/appointment/${appointment.id}'),
                      ),
                      if (appointment.clientPhone != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Tel: ${appointment.clientPhone}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                      if (expiresLabel != null)
                        Text(
                          'Expira: $expiresLabel',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                        ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _reject(context, ref, appointment.id),
                              child: const Text('Rechazar'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton(
                              onPressed: () => _accept(context, ref, appointment.id),
                              child: const Text('Aceptar'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

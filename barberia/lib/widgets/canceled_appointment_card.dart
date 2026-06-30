import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/theme/app_theme.dart';
import '../data/models/appointment.dart';

class CanceledAppointmentCard extends StatelessWidget {
  const CanceledAppointmentCard({
    super.key,
    required this.appointment,
    required this.onTap,
  });

  final Appointment appointment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final canceledLabel = appointment.canceledAt == null
        ? 'Cancelada'
        : 'Cancelada: ${DateFormat('d/M/yyyy HH:mm').format(DateTime.parse(appointment.canceledAt!))}';

    return Card(
      color: AppTheme.surface.withValues(alpha: 0.8),
      child: ListTile(
        leading: const Icon(Icons.cancel_outlined, color: AppTheme.canceled),
        title: Text(
          appointment.clientName,
          style: const TextStyle(
            decoration: TextDecoration.lineThrough,
            color: AppTheme.canceled,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${appointment.date} · ${appointment.time}'),
            Text(appointment.servicesLabel),
            const SizedBox(height: 4),
            Text(
              canceledLabel,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.canceled,
              ),
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

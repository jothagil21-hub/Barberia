import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

enum TimeSlotLegendMode { block, booking }

class TimeSlotLegend extends StatelessWidget {
  const TimeSlotLegend({
    super.key,
    this.mode = TimeSlotLegendMode.block,
  });

  final TimeSlotLegendMode mode;

  @override
  Widget build(BuildContext context) {
    final items = mode == TimeSlotLegendMode.block
        ? const [
            _LegendItem(
              key: Key('legend-available'),
              label: 'Disponible',
              description: 'Toca para bloquear',
              backgroundColor: AppTheme.slotAvailableBackground,
              borderColor: AppTheme.slotAvailableBorder,
              foregroundColor: AppTheme.slotAvailableForeground,
            ),
            _LegendItem(
              key: Key('legend-blocked'),
              label: 'Bloqueado',
              description: 'Toca para desbloquear',
              backgroundColor: AppTheme.slotBlockedBackground,
              borderColor: AppTheme.slotBlockedBorder,
              foregroundColor: AppTheme.slotBlockedForeground,
              boldSample: true,
            ),
          ]
        : const [
            _LegendItem(
              key: Key('legend-available'),
              label: 'Disponible',
              description: 'Puedes reservar',
              backgroundColor: AppTheme.slotAvailableBackground,
              borderColor: AppTheme.slotAvailableBorder,
              foregroundColor: AppTheme.slotAvailableForeground,
            ),
            _LegendItem(
              key: Key('legend-booked'),
              label: 'Programado',
              description: 'Ya tiene cita',
              backgroundColor: AppTheme.slotBookedBackground,
              borderColor: AppTheme.slotBookedBorder,
              foregroundColor: AppTheme.slotBookedForeground,
            ),
            _LegendItem(
              key: Key('legend-blocked'),
              label: 'Bloqueado',
              description: 'Cerrado por el barbero',
              backgroundColor: AppTheme.slotBlockedBackground,
              borderColor: AppTheme.slotBlockedBorder,
              foregroundColor: AppTheme.slotBlockedForeground,
              boldSample: true,
            ),
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Leyenda',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppTheme.textSecondary,
              ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: items,
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    super.key,
    required this.label,
    required this.description,
    required this.backgroundColor,
    required this.borderColor,
    required this.foregroundColor,
    this.boldSample = false,
  });

  final String label;
  final String description;
  final Color backgroundColor;
  final Color borderColor;
  final Color foregroundColor;
  final bool boldSample;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: Text(
            '09:00',
            style: TextStyle(
              fontSize: 11,
              color: foregroundColor,
              fontWeight: boldSample ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            Text(
              description,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

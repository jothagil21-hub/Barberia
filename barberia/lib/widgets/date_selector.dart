import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/theme/app_theme.dart';

class DateSelector extends StatelessWidget {
  const DateSelector({
    super.key,
    required this.selectedDate,
    required this.onDateChanged,
    this.allowPastDates = false,
  });

  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateChanged;
  final bool allowPastDates;

  @override
  Widget build(BuildContext context) {
    final label = DateFormat('EEEE d MMMM yyyy', 'es').format(selectedDate);
    final formattedLabel = label[0].toUpperCase() + label.substring(1);

    return Card(
      child: ListTile(
        leading: const Icon(Icons.calendar_today, color: AppTheme.accent),
        title: Text(
          formattedLabel,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          final today = DateTime.now();
          final firstDay = allowPastDates
              ? DateTime(2020)
              : DateTime(today.year, today.month, today.day);

          final picked = await showDatePicker(
            context: context,
            initialDate: selectedDate,
            firstDate: firstDay,
            lastDate: today.add(const Duration(days: 365)),
            locale: const Locale('es'),
          );

          if (picked != null) {
            onDateChanged(DateTime(picked.year, picked.month, picked.day));
          }
        },
      ),
    );
  }
}

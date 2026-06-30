import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/providers.dart';
import '../widgets/canceled_appointment_card.dart';
import '../widgets/date_selector.dart';

class CanceledAppointmentsScreen extends ConsumerWidget {
  const CanceledAppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filterDate = ref.watch(canceledFilterDateProvider);
    final canceledAsync = ref.watch(canceledAppointmentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Citas canceladas'),
        actions: [
          if (filterDate != null)
            IconButton(
              tooltip: 'Quitar filtro',
              icon: const Icon(Icons.filter_alt_off),
              onPressed: () {
                ref.read(canceledFilterDateProvider.notifier).clear();
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filtrar por día (opcional)',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                DateSelector(
                  selectedDate: filterDate ?? DateTime.now(),
                  allowPastDates: true,
                  onDateChanged: (date) {
                    ref.read(canceledFilterDateProvider.notifier).setDate(date);
                  },
                ),
              ],
            ),
          ),
          canceledAsync.when(
            loading: () => const Expanded(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Expanded(
              child: Center(child: Text('Error: $error')),
            ),
            data: (appointments) {
              if (appointments.isEmpty) {
                return const Expanded(
                  child: Center(
                    child: Text('No hay citas canceladas'),
                  ),
                );
              }

              return Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: appointments.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final appointment = appointments[index];
                    return CanceledAppointmentCard(
                      appointment: appointment,
                      onTap: () => context.push(
                        '/appointment/${appointment.id}',
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/utils/time_slot_generator.dart';
import '../providers/providers.dart';
import '../widgets/appointment_card.dart';
import '../widgets/barber_selector.dart';
import '../widgets/date_selector.dart';
import '../widgets/home_top_bar.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedDateProvider);
    final appointmentsAsync = ref.watch(appointmentsForDateProvider);
    final scheduleConfig = ref.watch(scheduleConfigProvider);

    return Scaffold(
      body: Column(
        children: [
          const SafeArea(
            bottom: false,
            child: HomeTopBar(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: BarberSelector(),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: DateSelector(
                    selectedDate: selectedDate,
                    allowPastDates: true,
                    onDateChanged: (date) {
                      ref.read(selectedDateProvider.notifier).setDate(date);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Bloquear horarios',
                  onPressed: () => context.push('/schedule-block'),
                  icon: const Icon(Icons.block),
                ),
              ],
            ),
          ),
          appointmentsAsync.when(
            loading: () => const Expanded(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Expanded(
              child: Center(child: Text('Error: $error')),
            ),
            data: (appointments) {
              final totalSlots =
                  TimeSlotGenerator.generateAllSlots(scheduleConfig).length;
              final occupied = appointments.length;
              final available = totalSlots - occupied;

              return Expanded(
                child: appointments.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.event_available, size: 48),
                            const SizedBox(height: 12),
                            const Text('No hay citas para este día'),
                            const SizedBox(height: 8),
                            Text(
                              '$available de $totalSlots horarios disponibles',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '$occupied citas · $available horarios libres (${scheduleConfig.rangeLabel})',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: appointments.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final appointment = appointments[index];
                                return AppointmentCard(
                                  appointment: appointment,
                                  onTap: () => context.push(
                                    '/appointment/${appointment.id}',
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/new'),
        icon: const Icon(Icons.add),
        label: const Text('Nueva cita'),
      ),
    );
  }
}

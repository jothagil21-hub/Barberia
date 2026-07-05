import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';

class BarberSelector extends ConsumerWidget {
  const BarberSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider).value;
    final selectedBarberAsync = ref.watch(selectedBarberIdProvider);
    final barbersAsync = ref.watch(activeBarbersProvider);

    return barbersAsync.when(
      loading: () => const LinearProgressIndicator(minHeight: 2),
      error: (error, _) => Text('Error al cargar barberos: $error'),
      data: (barbers) {
        if (barbers.isEmpty) {
          return const Text('No hay barberos activos.');
        }

        final selectedId = selectedBarberAsync.value;
        final effectiveId = selectedId != null &&
                barbers.any((barber) => barber.id == selectedId)
            ? selectedId
            : barbers.first.id;

        if (selectedId != effectiveId) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(selectedBarberIdProvider.notifier).selectBarber(effectiveId);
          });
        }

        final selectedBarber = barbers.firstWhere(
          (barber) => barber.id == effectiveId,
          orElse: () => barbers.first,
        );

        if (auth?.isStaff == true) {
          return InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Barbero asignado',
              prefixIcon: Icon(Icons.person_outline),
            ),
            child: Text(
              selectedBarber.name,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          );
        }

        return DropdownButtonFormField<int>(
          value: effectiveId,
          decoration: const InputDecoration(
            labelText: 'Barbero',
            prefixIcon: Icon(Icons.person_outline),
          ),
          items: barbers
              .map(
                (barber) => DropdownMenuItem<int>(
                  value: barber.id,
                  child: Text(barber.name),
                ),
              )
              .toList(),
          onChanged: (barberId) {
            if (barberId == null) return;
            ref.read(selectedBarberIdProvider.notifier).selectBarber(barberId);
            refreshAppointments(ref);
          },
        );
      },
    );
  }
}

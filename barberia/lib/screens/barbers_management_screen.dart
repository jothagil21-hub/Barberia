import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/barber.dart';
import '../providers/providers.dart';
import '../widgets/text_input_dialog.dart';

class BarbersManagementScreen extends ConsumerWidget {
  const BarbersManagementScreen({super.key});

  Future<void> _toggleBarber(
    WidgetRef ref,
    BuildContext context,
    Barber barber,
    bool active,
  ) async {
    try {
      final repo = ref.read(barberRepositoryProvider);
      await repo.setBarberActive(barber.id, active);
      refreshBarbers(ref);
      await ref.read(selectedBarberIdProvider.notifier).ensureDefaultBarber();
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $error')),
      );
    }
  }

  Future<bool> _showNameDialog(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String initialName,
    required Future<void> Function(String name) onSave,
  }) async {
    final name = await showTextInputDialog(
      context,
      title: title,
      label: 'Nombre del barbero',
      initialValue: initialName,
    );

    if (name == null || !context.mounted) return false;

    try {
      await onSave(name);
      refreshBarbers(ref);
      await ref.read(selectedBarberIdProvider.notifier).ensureDefaultBarber();
      return true;
    } catch (error) {
      if (!context.mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $error')),
      );
      return false;
    }
  }

  Future<void> _showAddDialog(BuildContext context, WidgetRef ref) async {
    final saved = await _showNameDialog(
      context,
      ref,
      title: 'Nuevo barbero',
      initialName: '',
      onSave: (name) => ref.read(barberRepositoryProvider).createBarber(name),
    );
    if (!saved || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Barbero creado')),
    );
  }

  Future<void> _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    Barber barber,
  ) async {
    final saved = await _showNameDialog(
      context,
      ref,
      title: 'Editar barbero',
      initialName: barber.name,
      onSave: (name) =>
          ref.read(barberRepositoryProvider).updateBarberName(barber.id, name),
    );
    if (!saved || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Barbero actualizado')),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final barbersAsync = ref.watch(allBarbersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Gestión de barberos')),
      body: barbersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
        data: (barbers) {
          if (barbers.isEmpty) {
            return const Center(child: Text('No hay barberos'));
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: barbers.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final barber = barbers[index];
              return Opacity(
                opacity: barber.isActive ? 1 : 0.55,
                child: ListTile(
                  title: Text(barber.name),
                  subtitle: Text(barber.isActive ? 'Activo' : 'Inactivo'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Editar nombre',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _showEditDialog(context, ref, barber),
                      ),
                      Switch(
                        value: barber.isActive,
                        onChanged: (value) =>
                            _toggleBarber(ref, context, barber, value),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo barbero'),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/service_duration_constants.dart';
import '../core/utils/currency_formatter.dart';
import '../data/models/service.dart';
import '../providers/providers.dart';
import '../widgets/text_input_dialog.dart';

class ServicesManagementScreen extends ConsumerWidget {
  const ServicesManagementScreen({super.key});

  Future<void> _toggleService(
    WidgetRef ref,
    BuildContext context,
    BarberService service,
    bool active,
  ) async {
    try {
      final repo = ref.read(serviceRepositoryProvider);
      await repo.setServiceActive(service.id, active);
      refreshServices(ref);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $error')),
      );
    }
  }

  Future<bool> _showServiceDialog(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String initialName,
    required double initialPrice,
    required int initialDurationMinutes,
    required Future<void> Function(String name, double price, int durationMinutes)
        onSave,
    String? successMessage,
  }) async {
    final result = await showServiceInputDialog(
      context,
      title: title,
      initialName: initialName,
      initialPrice: initialPrice,
      initialDurationMinutes: initialDurationMinutes,
    );

    if (result == null || !context.mounted) return false;

    try {
      await onSave(result.name, result.price, result.durationMinutes);
    } catch (error) {
      if (!context.mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $error')),
      );
      return false;
    }
    refreshServices(ref);
    if (successMessage != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
    }
    return true;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicesAsync = ref.watch(allServicesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Catálogo de servicios')),
      body: servicesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
        data: (services) {
          if (services.isEmpty) {
            return const Center(child: Text('No hay servicios'));
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: services.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final service = services[index];
              return Opacity(
                opacity: service.isActive ? 1 : 0.55,
                child: ListTile(
                  title: Text(service.name),
                  subtitle: Text(
                    '${service.isActive ? 'Activo' : 'Inactivo'} · '
                    '${CurrencyFormatter.format(service.price)} · '
                    '${service.durationMinutes} min',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _showServiceDialog(
                          context,
                          ref,
                          title: 'Editar servicio',
                          initialName: service.name,
                          initialPrice: service.price,
                          initialDurationMinutes: service.durationMinutes,
                          onSave: (name, price, durationMinutes) async {
                            final repo = ref.read(serviceRepositoryProvider);
                            await repo.updateService(
                              service.id,
                              name: name,
                              price: price,
                              durationMinutes: durationMinutes,
                            );
                          },
                        ),
                      ),
                      Switch(
                        value: service.isActive,
                        onChanged: (value) =>
                            _toggleService(ref, context, service, value),
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
        onPressed: () => _showServiceDialog(
          context,
          ref,
          title: 'Nuevo servicio',
          initialName: '',
          initialPrice: 0,
          initialDurationMinutes: ServiceDurationConstants.defaultMinutes,
          successMessage: 'Servicio creado',
          onSave: (name, price, durationMinutes) async {
            final repo = ref.read(serviceRepositoryProvider);
            await repo.createService(
              name,
              price: price,
              durationMinutes: durationMinutes,
            );
          },
        ),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo servicio'),
      ),
    );
  }
}

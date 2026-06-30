import 'package:flutter/material.dart';

import '../core/utils/currency_formatter.dart';
import '../data/models/service.dart';

class ServiceCheckboxList extends StatelessWidget {
  const ServiceCheckboxList({
    super.key,
    required this.services,
    required this.selectedIds,
    required this.onChanged,
  });

  final List<BarberService> services;
  final Set<int> selectedIds;
  final void Function(int serviceId, bool selected) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: services.map((service) {
        return CheckboxListTile(
          value: selectedIds.contains(service.id),
          title: Text(service.name),
          subtitle: Text(
            '${CurrencyFormatter.format(service.price)} · ${service.durationMinutes} min',
          ),
          onChanged: (checked) => onChanged(service.id, checked ?? false),
          controlAffinity: ListTileControlAffinity.leading,
        );
      }).toList(),
    );
  }
}

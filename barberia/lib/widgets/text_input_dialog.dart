import 'package:flutter/material.dart';

import '../core/constants/service_duration_constants.dart';

class ServiceInputDialogResult {
  const ServiceInputDialogResult({
    required this.name,
    required this.price,
    required this.durationMinutes,
  });

  final String name;
  final double price;
  final int durationMinutes;
}

Future<String?> showTextInputDialog(
  BuildContext context, {
  required String title,
  required String label,
  String initialValue = '',
  TextCapitalization textCapitalization = TextCapitalization.words,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _TextInputDialog(
      title: title,
      label: label,
      initialValue: initialValue,
      textCapitalization: textCapitalization,
    ),
  );
}

Future<ServiceInputDialogResult?> showServiceInputDialog(
  BuildContext context, {
  required String title,
  String initialName = '',
  double initialPrice = 0,
  int initialDurationMinutes = ServiceDurationConstants.defaultMinutes,
}) {
  return showDialog<ServiceInputDialogResult>(
    context: context,
    builder: (context) => _ServiceInputDialog(
      title: title,
      initialName: initialName,
      initialPrice: initialPrice,
      initialDurationMinutes: initialDurationMinutes,
    ),
  );
}

class _TextInputDialog extends StatefulWidget {
  const _TextInputDialog({
    required this.title,
    required this.label,
    required this.initialValue,
    required this.textCapitalization,
  });

  final String title;
  final String label;
  final String initialValue;
  final TextCapitalization textCapitalization;

  @override
  State<_TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<_TextInputDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final trimmed = _controller.text.trim();
    if (trimmed.isEmpty) return;
    Navigator.pop(context, trimmed);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(labelText: widget.label),
        textCapitalization: widget.textCapitalization,
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

class _ServiceInputDialog extends StatefulWidget {
  const _ServiceInputDialog({
    required this.title,
    required this.initialName,
    required this.initialPrice,
    required this.initialDurationMinutes,
  });

  final String title;
  final String initialName;
  final double initialPrice;
  final int initialDurationMinutes;

  @override
  State<_ServiceInputDialog> createState() => _ServiceInputDialogState();
}

class _ServiceInputDialogState extends State<_ServiceInputDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late int _durationMinutes;

  static final List<int> _durationOptions = List.generate(
    (ServiceDurationConstants.maxMinutes -
            ServiceDurationConstants.minMinutes) ~/
        ServiceDurationConstants.blockMinutes +
        1,
    (index) =>
        ServiceDurationConstants.minMinutes +
        index * ServiceDurationConstants.blockMinutes,
  );

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _priceController = TextEditingController(
      text: widget.initialPrice > 0
          ? widget.initialPrice.toStringAsFixed(2)
          : '',
    );
    _durationMinutes = widget.initialDurationMinutes;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final price =
        double.tryParse(_priceController.text.replaceAll(',', '.')) ?? 0;
    Navigator.pop(
      context,
      ServiceInputDialogResult(
        name: name,
        price: price,
        durationMinutes: _durationMinutes,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Nombre del servicio',
            ),
            textCapitalization: TextCapitalization.sentences,
            autofocus: true,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _priceController,
            decoration: const InputDecoration(
              labelText: 'Precio',
              prefixText: r'$ ',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: _durationMinutes,
            decoration: const InputDecoration(labelText: 'Duración'),
            items: _durationOptions
                .map(
                  (minutes) => DropdownMenuItem(
                    value: minutes,
                    child: Text('$minutes min'),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() => _durationMinutes = value);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

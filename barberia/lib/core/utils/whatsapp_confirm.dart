import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/appointment.dart';

/// Normaliza un teléfono para enlaces wa.me (solo dígitos, código país por defecto 57).
String? normalizePhoneForWhatsApp(
  String phone, {
  String defaultCountryCode = '57',
}) {
  var digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return null;

  if (digits.startsWith('0')) {
    digits = digits.substring(1);
  }

  if (digits.length <= 10 && defaultCountryCode.isNotEmpty) {
    digits = '$defaultCountryCode$digits';
  }

  if (digits.length < 10) return null;
  return digits;
}

String buildBookingConfirmationMessage({
  required Appointment appointment,
  required String shopName,
}) {
  final rawDate = DateFormat('EEEE d \'de\' MMMM', 'es')
      .format(DateTime.parse(appointment.date));
  final dateLabel = rawDate[0].toUpperCase() + rawDate.substring(1);

  final buffer = StringBuffer()
    ..write('Hola ${appointment.clientName}, ')
    ..write('\n\nTu cita en $shopName quedó confirmada para el ')
    ..write('$dateLabel a las ${appointment.time}.');

  if (appointment.barberName != null) {
    buffer.write('\nBarbero: ${appointment.barberName}.');
  }
  if (appointment.services.isNotEmpty) {
    buffer.write('\nServicios: ${appointment.servicesLabel}.');
  }
  buffer.write('\n¡Te esperamos!');

  return buffer.toString();
}

Uri? buildWhatsAppConfirmUri({
  required String phone,
  required String message,
  String defaultCountryCode = '57',
}) {
  final normalized = normalizePhoneForWhatsApp(
    phone,
    defaultCountryCode: defaultCountryCode,
  );
  if (normalized == null) return null;

  return Uri.parse(
    'https://wa.me/$normalized?text=${Uri.encodeComponent(message)}',
  );
}

Future<bool> launchWhatsAppConfirm(Uri uri) {
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// Abre WhatsApp con el mensaje de confirmación (sin diálogo previo).
Future<void> openWhatsAppConfirmation(
  BuildContext context, {
  required Appointment appointment,
  required String shopName,
}) async {
  final phone = appointment.clientPhone?.trim();
  if (phone == null || phone.isEmpty) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Esta cita no tiene teléfono registrado')),
    );
    return;
  }

  final message = buildBookingConfirmationMessage(
    appointment: appointment,
    shopName: shopName,
  );
  final uri = buildWhatsAppConfirmUri(phone: phone, message: message);
  if (uri == null) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Teléfono no válido para WhatsApp')),
    );
    return;
  }

  final launched = await launchWhatsAppConfirm(uri);
  if (!context.mounted) return;
  if (!launched) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No se pudo abrir WhatsApp')),
    );
  }
}

/// Siempre muestra un diálogo tras aceptar, con botón de WhatsApp si hay teléfono.
Future<void> offerWhatsAppAfterAccept(
  BuildContext context, {
  required Appointment appointment,
  required String shopName,
}) async {
  if (!context.mounted) return;

  final phone = appointment.clientPhone?.trim();
  final hasPhone = phone != null && phone.isNotEmpty;
  final uri = hasPhone
      ? buildWhatsAppConfirmUri(
          phone: phone,
          message: buildBookingConfirmationMessage(
            appointment: appointment,
            shopName: shopName,
          ),
        )
      : null;
  final canOpenWhatsApp = uri != null;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (dialogContext) {
      return AlertDialog(
        icon: Icon(
          Icons.check_circle_outline,
          color: Colors.green.shade600,
          size: 48,
        ),
        title: const Text('Solicitud aceptada'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'La cita de ${appointment.clientName} quedó confirmada.',
              textAlign: TextAlign.center,
            ),
            if (!hasPhone) ...[
              const SizedBox(height: 12),
              Text(
                'Esta solicitud no tiene teléfono. No se puede enviar WhatsApp.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.orange.shade700),
              ),
            ] else if (!canOpenWhatsApp) ...[
              const SizedBox(height: 12),
              Text(
                'Teléfono registrado no válido para WhatsApp: $phone',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.orange.shade700),
              ),
            ] else ...[
              const SizedBox(height: 12),
              Text(
                '¿Deseas enviar la confirmación por WhatsApp?',
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (canOpenWhatsApp)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () async {
                      Navigator.of(dialogContext).pop();
                      final launched = await launchWhatsAppConfirm(uri);
                      if (!context.mounted) return;
                      if (!launched) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('No se pudo abrir WhatsApp'),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.chat_outlined),
                    label: const Text('Enviar confirmación por WhatsApp'),
                  ),
                if (canOpenWhatsApp) const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(canOpenWhatsApp ? 'Omitir por ahora' : 'Cerrar'),
                ),
              ],
            ),
          ),
        ],
      );
    },
  );
}

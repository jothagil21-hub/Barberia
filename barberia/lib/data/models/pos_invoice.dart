import 'dart:convert';

class PosInvoiceLine {
  const PosInvoiceLine({
    required this.serviceName,
    required this.durationMinutes,
    required this.unitPrice,
    required this.lineTotal,
  });

  final String serviceName;
  final int durationMinutes;
  final double unitPrice;
  final double lineTotal;

  Map<String, dynamic> toJson() => {
        'serviceName': serviceName,
        'durationMinutes': durationMinutes,
        'unitPrice': unitPrice,
        'lineTotal': lineTotal,
      };

  factory PosInvoiceLine.fromJson(Map<String, dynamic> json) => PosInvoiceLine(
        serviceName: json['serviceName'] as String,
        durationMinutes: json['durationMinutes'] as int,
        unitPrice: (json['unitPrice'] as num).toDouble(),
        lineTotal: (json['lineTotal'] as num).toDouble(),
      );
}

class PosInvoice {
  const PosInvoice({
    required this.id,
    required this.appointmentId,
    required this.number,
    required this.issuedAt,
    required this.clientName,
    this.barberName,
    required this.subtotal,
    required this.lines,
  });

  final int id;
  final int appointmentId;
  final int number;
  final String issuedAt;
  final String clientName;
  final String? barberName;
  final double subtotal;
  final List<PosInvoiceLine> lines;

  factory PosInvoice.fromMap(Map<String, Object?> map) {
    final linesJson = map['lines_json'] as String? ?? '[]';
    final decoded = jsonDecode(linesJson) as List<dynamic>;
    return PosInvoice(
      id: map['id'] as int,
      appointmentId: map['appointment_id'] as int,
      number: map['number'] as int,
      issuedAt: map['issued_at'] as String,
      clientName: map['client_name'] as String,
      barberName: map['barber_name'] as String?,
      subtotal: (map['subtotal'] as num).toDouble(),
      lines: decoded
          .map((e) => PosInvoiceLine.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

import 'api_config.dart';

class AppLoginResult {
  const AppLoginResult({
    required this.token,
    required this.tenantId,
    required this.tenantName,
    required this.userId,
    required this.username,
    required this.role,
    this.barberId,
  });

  final String token;
  final String tenantId;
  final String tenantName;
  final String userId;
  final String username;
  final String role;
  final String? barberId;

  factory AppLoginResult.fromJson(Map<String, dynamic> json) {
    final token = json['token'];
    final tenant = json['tenant'];
    final user = json['user'];
    if (token is! String ||
        token.isEmpty ||
        tenant is! Map<String, dynamic> ||
        user is! Map<String, dynamic>) {
      throw ApiException('Respuesta inválida del servidor al iniciar sesión.');
    }
    final tenantId = tenant['id'];
    final tenantName = tenant['name'];
    final userId = user['id'];
    final username = user['username'];
    final role = user['role'];
    if (tenantId is! String ||
        tenantName is! String ||
        userId is! String ||
        username is! String ||
        role is! String) {
      throw ApiException('Respuesta incompleta del servidor al iniciar sesión.');
    }
    return AppLoginResult(
      token: token,
      tenantId: tenantId,
      tenantName: tenantName,
      userId: userId,
      username: username,
      role: role,
      barberId: user['barberId'] as String?,
    );
  }
}

class PanelLoginResult {
  const PanelLoginResult({
    required this.tenantId,
    required this.userId,
    required this.username,
    required this.role,
    this.assignedBarberServerId,
    this.isOffline = false,
    this.syncWarning,
  });

  final String tenantId;
  final String userId;
  final String username;
  final String role;
  final String? assignedBarberServerId;
  final bool isOffline;
  final String? syncWarning;

  factory PanelLoginResult.fromAppLogin(AppLoginResult result) {
    return PanelLoginResult(
      tenantId: result.tenantId,
      userId: result.userId,
      username: result.username,
      role: result.role,
      assignedBarberServerId: result.barberId,
    );
  }
}

class SyncPullBundle {
  const SyncPullBundle({
    required this.serverTime,
    required this.settings,
    required this.barbers,
    required this.services,
    required this.appointments,
    required this.scheduleBlocks,
    this.posInvoices = const [],
  });

  final String serverTime;
  final SyncSettingsDto settings;
  final List<SyncBarberDto> barbers;
  final List<SyncServiceDto> services;
  final List<SyncAppointmentDto> appointments;
  final List<SyncBlockDto> scheduleBlocks;
  final List<SyncPosInvoiceDto> posInvoices;

  factory SyncPullBundle.fromJson(Map<String, dynamic> json) {
    final settings = json['settings'];
    final serverTime = json['serverTime'];
    if (settings is! Map<String, dynamic> || serverTime is! String) {
      throw ApiException('Respuesta inválida del servidor al sincronizar.');
    }
    return SyncPullBundle(
      serverTime: serverTime,
      settings: SyncSettingsDto.fromJson(settings),
      barbers: (json['barbers'] as List<dynamic>)
          .map((e) => SyncBarberDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      services: (json['services'] as List<dynamic>)
          .map((e) => SyncServiceDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      appointments: (json['appointments'] as List<dynamic>)
          .map((e) => SyncAppointmentDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      scheduleBlocks: (json['scheduleBlocks'] as List<dynamic>)
          .map((e) => SyncBlockDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      posInvoices: (json['posInvoices'] as List<dynamic>? ?? [])
          .map((e) => SyncPosInvoiceDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class SyncSettingsDto {
  const SyncSettingsDto({
    required this.shopName,
    required this.displayName,
    required this.logoUrl,
    required this.scheduleStart,
    required this.scheduleEnd,
    required this.scheduleInterval,
    required this.updatedAt,
  });

  final String shopName;
  final String displayName;
  final String? logoUrl;
  final String scheduleStart;
  final String scheduleEnd;
  final int scheduleInterval;
  final String updatedAt;

  factory SyncSettingsDto.fromJson(Map<String, dynamic> json) => SyncSettingsDto(
        shopName: json['shopName'] as String,
        displayName: json['displayName'] as String,
        logoUrl: json['logoUrl'] as String?,
        scheduleStart: json['scheduleStart'] as String,
        scheduleEnd: json['scheduleEnd'] as String,
        scheduleInterval: json['scheduleInterval'] as int,
        updatedAt: json['updatedAt'] as String,
      );
}

class SyncBarberDto {
  const SyncBarberDto({
    required this.id,
    required this.name,
    required this.active,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final bool active;
  final String updatedAt;

  factory SyncBarberDto.fromJson(Map<String, dynamic> json) => SyncBarberDto(
        id: json['id'] as String,
        name: json['name'] as String,
        active: json['active'] as bool,
        updatedAt: json['updatedAt'] as String,
      );
}

class SyncServiceDto {
  const SyncServiceDto({
    required this.id,
    required this.name,
    required this.price,
    required this.durationMinutes,
    required this.active,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final double price;
  final int durationMinutes;
  final bool active;
  final String updatedAt;

  factory SyncServiceDto.fromJson(Map<String, dynamic> json) => SyncServiceDto(
        id: json['id'] as String,
        name: json['name'] as String,
        price: (json['price'] as num).toDouble(),
        durationMinutes: json['durationMinutes'] as int? ?? 30,
        active: json['active'] as bool,
        updatedAt: json['updatedAt'] as String,
      );
}

class SyncAppointmentDto {
  const SyncAppointmentDto({
    required this.id,
    required this.barberId,
    required this.clientName,
    required this.date,
    required this.time,
    required this.durationMinutes,
    required this.status,
    required this.createdAt,
    required this.canceledAt,
    required this.updatedAt,
    required this.services,
    this.clientPhone,
    this.source,
    this.pendingExpiresAt,
  });

  final String id;
  final String barberId;
  final String clientName;
  final String? clientPhone;
  final String? source;
  final String date;
  final String time;
  final int durationMinutes;
  final String status;
  final String createdAt;
  final String? canceledAt;
  final String? pendingExpiresAt;
  final String updatedAt;
  final List<SyncServiceLineDto> services;

  factory SyncAppointmentDto.fromJson(Map<String, dynamic> json) =>
      SyncAppointmentDto(
        id: json['id'] as String,
        barberId: json['barberId'] as String,
        clientName: json['clientName'] as String,
        clientPhone: json['clientPhone'] as String?,
        source: json['source'] as String?,
        date: json['date'] as String,
        time: json['time'] as String,
        durationMinutes: json['durationMinutes'] as int? ?? 30,
        status: json['status'] as String,
        createdAt: json['createdAt'] as String,
        canceledAt: json['canceledAt'] as String?,
        pendingExpiresAt: json['pendingExpiresAt'] as String?,
        updatedAt: json['updatedAt'] as String,
        services: (json['services'] as List<dynamic>)
            .map((e) => SyncServiceLineDto.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class SyncServiceLineDto {
  const SyncServiceLineDto({
    required this.serviceId,
    required this.unitPrice,
    required this.durationMinutes,
  });

  final String serviceId;
  final double unitPrice;
  final int durationMinutes;

  factory SyncServiceLineDto.fromJson(Map<String, dynamic> json) =>
      SyncServiceLineDto(
        serviceId: json['serviceId'] as String,
        unitPrice: (json['unitPrice'] as num).toDouble(),
        durationMinutes: json['durationMinutes'] as int? ?? 30,
      );
}

class SyncPosInvoiceLineDto {
  const SyncPosInvoiceLineDto({
    required this.serviceName,
    required this.durationMinutes,
    required this.unitPrice,
    required this.lineTotal,
  });

  final String serviceName;
  final int durationMinutes;
  final double unitPrice;
  final double lineTotal;

  factory SyncPosInvoiceLineDto.fromJson(Map<String, dynamic> json) =>
      SyncPosInvoiceLineDto(
        serviceName: json['serviceName'] as String,
        durationMinutes: json['durationMinutes'] as int,
        unitPrice: (json['unitPrice'] as num).toDouble(),
        lineTotal: (json['lineTotal'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'serviceName': serviceName,
        'durationMinutes': durationMinutes,
        'unitPrice': unitPrice,
        'lineTotal': lineTotal,
      };
}

class SyncPosInvoiceDto {
  const SyncPosInvoiceDto({
    required this.id,
    required this.appointmentId,
    required this.number,
    required this.issuedAt,
    required this.clientName,
    required this.barberName,
    required this.subtotal,
    required this.lines,
    required this.updatedAt,
  });

  final String id;
  final String appointmentId;
  final int number;
  final String issuedAt;
  final String clientName;
  final String? barberName;
  final double subtotal;
  final List<SyncPosInvoiceLineDto> lines;
  final String updatedAt;

  factory SyncPosInvoiceDto.fromJson(Map<String, dynamic> json) =>
      SyncPosInvoiceDto(
        id: json['id'] as String,
        appointmentId: json['appointmentId'] as String,
        number: json['number'] as int,
        issuedAt: json['issuedAt'] as String,
        clientName: json['clientName'] as String,
        barberName: json['barberName'] as String?,
        subtotal: (json['subtotal'] as num).toDouble(),
        lines: (json['lines'] as List<dynamic>)
            .map((e) => SyncPosInvoiceLineDto.fromJson(e as Map<String, dynamic>))
            .toList(),
        updatedAt: json['updatedAt'] as String,
      );
}

class SyncBlockDto {
  const SyncBlockDto({
    required this.id,
    required this.barberId,
    required this.date,
    required this.time,
    required this.isFullDay,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String barberId;
  final String date;
  final String? time;
  final bool isFullDay;
  final String createdAt;
  final String updatedAt;

  factory SyncBlockDto.fromJson(Map<String, dynamic> json) => SyncBlockDto(
        id: json['id'] as String,
        barberId: json['barberId'] as String,
        date: json['date'] as String,
        time: json['time'] as String?,
        isFullDay: json['isFullDay'] as bool,
        createdAt: json['createdAt'] as String,
        updatedAt: json['updatedAt'] as String,
      );
}

class SyncPostResult {
  const SyncPostResult({
    required this.serverTime,
    required this.applied,
    required this.conflicts,
    required this.pull,
  });

  final String serverTime;
  final Map<String, Map<String, String>> applied;
  final List<Map<String, dynamic>> conflicts;
  final SyncPullBundle pull;

  factory SyncPostResult.fromJson(Map<String, dynamic> json) => SyncPostResult(
        serverTime: json['serverTime'] as String,
        applied: {
          for (final entry in (json['applied'] as Map<String, dynamic>).entries)
            entry.key: Map<String, String>.from(
              (entry.value as Map).map((k, v) => MapEntry(k.toString(), v.toString())),
            ),
        },
        conflicts: (json['conflicts'] as List<dynamic>)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
        pull: SyncPullBundle.fromJson(json['pull'] as Map<String, dynamic>),
      );
}

class LogoUploadResult {
  const LogoUploadResult({
    required this.logoUrl,
    this.updatedAt,
  });

  final String logoUrl;
  final String? updatedAt;

  factory LogoUploadResult.fromJson(Map<String, dynamic> json) => LogoUploadResult(
        logoUrl: json['logoUrl'] as String? ?? '',
        updatedAt: json['updatedAt'] as String?,
      );
}

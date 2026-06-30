import '../database/schema.dart';
import 'schedule_config.dart';

class AppSettings {
  const AppSettings({
    required this.shopName,
    required this.appDisplayName,
    required this.scheduleConfig,
    this.logoPath,
    this.logoServerUrl,
  });

  final String shopName;
  final String appDisplayName;
  final ScheduleConfig scheduleConfig;
  final String? logoPath;
  final String? logoServerUrl;

  /// Clave para invalidar caché de imagen en UI (URL remota o ruta local).
  String? get logoCacheKey {
    if (logoServerUrl != null && logoServerUrl!.isNotEmpty) {
      return logoServerUrl;
    }
    return logoPath;
  }

  factory AppSettings.defaults() {
    return AppSettings(
      shopName: Schema.defaultShopName,
      appDisplayName: Schema.defaultAppDisplayName,
      scheduleConfig: ScheduleConfig.defaults(),
    );
  }

  AppSettings copyWith({
    String? shopName,
    String? appDisplayName,
    ScheduleConfig? scheduleConfig,
    String? logoPath,
    String? logoServerUrl,
    bool clearLogo = false,
  }) {
    return AppSettings(
      shopName: shopName ?? this.shopName,
      appDisplayName: appDisplayName ?? this.appDisplayName,
      scheduleConfig: scheduleConfig ?? this.scheduleConfig,
      logoPath: clearLogo ? null : (logoPath ?? this.logoPath),
      logoServerUrl: clearLogo ? null : (logoServerUrl ?? this.logoServerUrl),
    );
  }
}

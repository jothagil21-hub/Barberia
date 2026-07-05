class ApiConfig {
  /// URL de producción (Vercel). No se muestra al usuario final.
  static const productionBaseUrl = 'https://barberia-wheat-three.vercel.app';

  /// Override opcional en desarrollo:
  /// `flutter run --dart-define=API_BASE_URL=http://192.168.x.x:3000`
  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');

  static const healthCheckPath = '/api/health';

  /// URL efectiva: define de compilación o producción.
  static String get effectiveBaseUrl {
    final override = normalizeBaseUrl(_envBaseUrl);
    if (override.isNotEmpty) return override;
    return productionBaseUrl;
  }
}

/// Normaliza la URL base del servidor (trim, sin barra final, añade http:// si falta).
String normalizeBaseUrl(String url) {
  var normalized = url.trim().replaceAll(RegExp(r'/+$'), '');
  if (normalized.isEmpty) return normalized;
  if (!normalized.startsWith('http://') && !normalized.startsWith('https://')) {
    normalized = 'http://$normalized';
  }
  return normalized;
}

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

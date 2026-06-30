class ApiConfig {

  /// Placeholder para dispositivo físico en la misma Wi‑Fi que el PC con el backend.

  static const defaultBaseUrl = '';

  static const urlPlaceholder = 'http://192.168.1.17:3001';

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


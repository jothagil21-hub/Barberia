import 'dart:async';

import 'dart:convert';

import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as p;

import 'api_config.dart';

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  String? _baseUrl;

  String? _token;

  static const _timeout = Duration(seconds: 30);

  void configure({required String baseUrl, String? token}) {
    _baseUrl = normalizeBaseUrl(baseUrl);
    _token = token;
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
  }) async {
    final uri = _uri(path, query);
    try {
      final response = await _client.get(uri, headers: _headers()).timeout(_timeout);
      return _decode(response);
    } catch (e) {
      throw _mapTransportError(e);
    }
  }

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
    final uri = _uri(path, null);
    try {
      final response = await _client
          .post(uri, headers: _headers(), body: jsonEncode(body))
          .timeout(_timeout);
      return _decode(response);
    } catch (e) {
      throw _mapTransportError(e);
    }
  }

  Future<Map<String, dynamic>> delete(String path) async {
    final uri = _uri(path, null);
    try {
      final response = await _client.delete(uri, headers: _headers()).timeout(_timeout);
      return _decode(response);
    } catch (e) {
      throw _mapTransportError(e);
    }
  }

  Future<Map<String, dynamic>> uploadMultipart(
    String path,
    File file, {
    String field = 'file',
  }) async {
    final uri = _uri(path, null);
    try {
      final request = http.MultipartRequest('POST', uri);
      if (_token != null) {
        request.headers['Authorization'] = 'Bearer $_token';
      }
      request.files.add(
        await http.MultipartFile.fromPath(
          field,
          file.path,
          filename: p.basename(file.path),
          contentType: _imageContentType(file.path),
        ),
      );
      final streamed = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamed);
      return _decode(response);
    } catch (e) {
      throw _mapTransportError(e);
    }
  }

  Uri _uri(String path, Map<String, String>? query) {
    final base = _baseUrl;
    if (base == null || base.isEmpty) {
      throw ApiException('El servidor no está configurado.');
    }
    return Uri.parse('$base$path').replace(queryParameters: query);
  }

  Map<String, String> _headers() => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Map<String, dynamic> _decode(http.Response response) {
    final rawBody = response.body;
    final contentType = response.headers['content-type']?.toLowerCase() ?? '';

    if (_looksLikeHtml(rawBody, contentType)) {
      throw ApiException(
        'El servidor no es accesible públicamente. '
        'Si eres el administrador, usa el dominio de producción en Vercel '
        'y desactiva Deployment Protection en previews.',
        statusCode: response.statusCode,
      );
    }

    Map<String, dynamic>? body;
    if (rawBody.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawBody);
        if (decoded is Map<String, dynamic>) {
          body = decoded;
        }
      } catch (_) {
        throw ApiException(
          'Respuesta inválida del servidor (no es JSON).',
          statusCode: response.statusCode,
        );
      }
    }

    if (response.statusCode >= 400) {
      final message = body?['error']?.toString() ??
          body?['message']?.toString() ??
          _httpStatusMessage(response.statusCode);
      throw ApiException(message, statusCode: response.statusCode);
    }

    if (body == null || body.isEmpty) {
      throw ApiException(
        'Respuesta vacía del servidor.',
        statusCode: response.statusCode,
      );
    }

    return body;
  }

  bool _looksLikeHtml(String body, String contentType) {
    if (contentType.contains('text/html')) return true;
    final trimmed = body.trimLeft().toLowerCase();
    return trimmed.startsWith('<!doctype') ||
        trimmed.startsWith('<html') ||
        body.contains('Log in to Vercel');
  }

  String _httpStatusMessage(int status) {
    switch (status) {
      case 401:
        return 'Credenciales incorrectas. Revisa usuario y contraseña del panel.';
      case 403:
        return 'No tienes permiso para esta acción.';
      case 404:
        return 'Recurso no encontrado en el servidor.';
      case 503:
        return 'Servidor no disponible. Intenta de nuevo en unos minutos.';
      default:
        return 'Error del servidor (HTTP $status).';
    }
  }

  ApiException _mapTransportError(Object error) {
    if (error is ApiException) return error;

    if (error is TimeoutException) {
      return ApiException(
        'Tiempo de espera agotado. Comprueba tu conexión a internet e intenta de nuevo.',
      );
    }

    if (error is SocketException) {
      return ApiException(
        'No se pudo conectar al servidor. Comprueba tu conexión a internet.',
      );
    }

    if (error is http.ClientException) {
      return ApiException(
        'Error de conexión: ${error.message}.',
      );
    }

    return ApiException('Error de red: $error');
  }

  MediaType? _imageContentType(String filePath) {
    switch (p.extension(filePath).toLowerCase()) {
      case '.jpg':
      case '.jpeg':
        return MediaType('image', 'jpeg');
      case '.png':
        return MediaType('image', 'png');
      case '.webp':
        return MediaType('image', 'webp');
      case '.gif':
        return MediaType('image', 'gif');
      default:
        return null;
    }
  }
}

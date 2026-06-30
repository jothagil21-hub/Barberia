import 'dart:async';

import 'dart:convert';

import 'dart:io';



import 'package:http/http.dart' as http;



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
        await http.MultipartFile.fromPath(field, file.path),
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

      throw ApiException('Indica la URL del servidor (IP de tu PC en la red Wi‑Fi).');

    }

    return Uri.parse('$base$path').replace(queryParameters: query);

  }



  Map<String, String> _headers() => {

        'Content-Type': 'application/json',

        if (_token != null) 'Authorization': 'Bearer $_token',

      };



  Map<String, dynamic> _decode(http.Response response) {

    Map<String, dynamic>? body;

    if (response.body.isNotEmpty) {

      try {

        final decoded = jsonDecode(response.body);

        if (decoded is Map<String, dynamic>) body = decoded;

      } catch (_) {

        /* cuerpo no JSON */

      }

    }



    if (response.statusCode >= 400) {

      final message = body?['error']?.toString() ??

          body?['message']?.toString() ??

          _httpStatusMessage(response.statusCode);

      throw ApiException(message, statusCode: response.statusCode);

    }



    return body ?? {};

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

        return 'Servidor no disponible. ¿Está corriendo el backend y PostgreSQL?';

      default:

        return 'Error del servidor (HTTP $status).';

    }

  }



  ApiException _mapTransportError(Object error) {

    if (error is ApiException) return error;

    if (error is TimeoutException) {

      return ApiException(

        'Tiempo de espera agotado. Comprueba la URL (${ApiConfig.urlPlaceholder}) y que el backend esté activo.',

      );

    }

    if (error is SocketException) {

      return ApiException(

        'No se pudo conectar al servidor. Usa la IP de tu PC en Wi‑Fi (ej. ${ApiConfig.urlPlaceholder}), no localhost.',

      );

    }

    if (error is http.ClientException) {

      return ApiException(

        'Error de conexión: ${error.message}. Verifica la URL y que el teléfono esté en la misma red.',

      );

    }

    return ApiException('Error de red: $error');

  }

}


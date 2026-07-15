import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../error/exception.dart';
import '../storage/secure_storage.dart';
import 'api_config.dart';
import 'session_manager.dart';

/// Client HTTP de l'app chauffeur (lecture seule + auth OTP).
/// - Injecte le Bearer token.
/// - Sur un 401 (hors /auth/*), tente un refresh puis rejoue une seule fois.
/// - Lance [ApiException] / [NetworkException].
class ApiClient {
  final SecureStorage _storage;
  final http.Client _http;

  ApiClient(this._storage, [http.Client? client])
      : _http = client ?? http.Client();

  static const _timeout = Duration(seconds: 25);

  Future<dynamic> get(String path, {Map<String, String>? query}) =>
      _send('GET', path, query: query);

  Future<dynamic> post(String path, [Object? body]) =>
      _send('POST', path, body: body);

  /// Télécharge un binaire (ex. décompte PDF d'un arrêté).
  Future<Uint8List> getBytes(String path) async {
    final uri = _buildUri(path, null);
    final headers = await _buildHeaders();
    headers['Accept'] = '*/*';
    headers.remove('Content-Type');
    try {
      final request = http.Request('GET', uri)..headers.addAll(headers);
      final streamed = await _http.send(request).timeout(_timeout);
      if (streamed.statusCode == 401) {
        final refreshed = await SessionManager.instance.refresh();
        if (refreshed) return getBytes(path);
      }
      final bytes = await streamed.stream.toBytes();
      if (streamed.statusCode >= 200 && streamed.statusCode < 300) return bytes;
      final raw = utf8.decode(bytes);
      throw ApiException(streamed.statusCode,
          raw.trim().isEmpty ? 'Erreur ${streamed.statusCode}' : raw.trim());
    } on TimeoutException {
      throw const NetworkException('Le serveur ne répond pas (timeout).');
    } on http.ClientException catch (e) {
      throw NetworkException('Impossible de joindre le serveur : ${e.message}');
    }
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    bool retry = true,
  }) async {
    final uri = _buildUri(path, query);
    final headers = await _buildHeaders();
    try {
      final request = http.Request(method, uri)..headers.addAll(headers);
      if (body != null) request.body = jsonEncode(body);
      final streamed = await _http.send(request).timeout(_timeout);
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 401 && retry && !path.startsWith('/auth/')) {
        final refreshed = await SessionManager.instance.refresh();
        if (refreshed) {
          return _send(method, path, query: query, body: body, retry: false);
        }
      }
      return _handle(response);
    } on TimeoutException {
      throw const NetworkException('Le serveur ne répond pas (timeout).');
    } on http.ClientException catch (e) {
      throw NetworkException('Impossible de joindre le serveur : ${e.message}');
    }
  }

  dynamic _handle(http.Response response) {
    final status = response.statusCode;
    if (status >= 200 && status < 300) {
      if (response.bodyBytes.isEmpty) return null;
      return jsonDecode(utf8.decode(response.bodyBytes));
    }
    final rawBody = utf8.decode(response.bodyBytes);
    Map<String, dynamic>? parsedBody;
    try {
      parsedBody = jsonDecode(rawBody) as Map<String, dynamic>?;
    } catch (_) {}

    final message = _extractMessage(parsedBody, rawBody) ??
        switch (status) {
          401 => 'Session expirée, veuillez vous reconnecter.',
          403 => 'Action non autorisée.',
          404 => 'Ressource introuvable.',
          >= 500 => 'Erreur serveur ($status).',
          _ => 'Erreur serveur ($status)',
        };
    throw ApiException(status, message, body: parsedBody);
  }

  String? _extractMessage(Map<String, dynamic>? parsed, String rawBody) {
    if (parsed != null) {
      final msg = parsed['message'] ?? parsed['error'] ?? parsed['detail'];
      if (msg is String && msg.trim().isNotEmpty) return msg.trim();
    }
    return rawBody.trim().isNotEmpty ? rawBody.trim() : null;
  }

  Uri _buildUri(String path, Map<String, String>? query) =>
      Uri.parse('${ApiConfig.baseUrl}$path').replace(queryParameters: query);

  Future<Map<String, String>> _buildHeaders() async {
    final token = await _storage.getAccessToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }
}

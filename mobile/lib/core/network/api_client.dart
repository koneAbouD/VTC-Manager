import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../error/exception.dart';
import '../storage/secure_storage.dart';
import '_bytes_io.dart' if (dart.library.html) '_bytes_web.dart';
import 'api_config.dart';

/// Client HTTP partagé par tous les datasources.
/// - Injecte automatiquement le Bearer token.
/// - Sur un 401, tente un refresh token puis rejoue la requête **une seule fois**.
/// - Normalise les réponses JSON (dynamic).
/// - Lance [ApiException] pour les erreurs HTTP et [NetworkException] pour
///   les erreurs réseau (timeout, pas de connexion).
class ApiClient {
  final SecureStorage _storage;
  final http.Client _http;

  ApiClient(this._storage, [http.Client? client])
      : _http = client ?? http.Client();

  static const _timeout = Duration(seconds: 15);

  /// Verrou pour mutualiser un refresh en cours entre plusieurs requêtes
  /// simultanées qui recevraient toutes un 401.
  Completer<bool>? _refreshing;

  // ── Méthodes publiques ──────────────────────────────────────────────────

  Future<dynamic> get(String path, {Map<String, String>? query}) =>
      _send('GET', path, query: query);

  /// Télécharge un fichier binaire (ex. contenu d'un document).
  ///
  /// Sur Flutter Web, utilise XHR avec responseType='arraybuffer' pour éviter
  /// le bug "detached ArrayBuffer" du BrowserClient (ByteConversionSink.add
  /// sur un buffer XHR déjà détaché par le GC).
  /// Sur natif (iOS/Android), utilise le streaming HTTP classique.
  Future<Uint8List> getBytes(String path) async {
    final uri = _buildUri(path, null);
    final headers = await _buildHeaders();
    headers['Accept'] = '*/*';
    headers.remove('Content-Type');

    if (kIsWeb) {
      return _getBytesWeb(path, uri, headers);
    }
    return _getBytesNative(path, uri, headers);
  }

  Future<Uint8List> _getBytesWeb(
    String path,
    Uri uri,
    Map<String, String> headers,
  ) async {
    try {
      final result = await fetchBytesNative(uri, headers, _timeout);
      if (result.statusCode == 401) {
        final refreshed = await _tryRefresh();
        if (refreshed) return getBytes(path);
      }
      if (result.statusCode >= 200 && result.statusCode < 300) {
        return result.bytes;
      }
      final rawBody = utf8.decode(result.bytes);
      throw ApiException(
        result.statusCode,
        rawBody.trim().isEmpty
            ? 'Erreur ${result.statusCode}'
            : rawBody.trim(),
      );
    } on TimeoutException {
      throw const NetworkException('Le serveur ne répond pas (timeout).');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw NetworkException('Impossible de joindre le serveur : $e');
    }
  }

  Future<Uint8List> _getBytesNative(
    String path,
    Uri uri,
    Map<String, String> headers,
  ) async {
    try {
      final request = http.Request('GET', uri)..headers.addAll(headers);
      final streamed = await _http.send(request).timeout(_timeout);

      if (streamed.statusCode == 401) {
        final refreshed = await _tryRefresh();
        if (refreshed) return getBytes(path);
      }

      final parts = <Uint8List>[];
      await for (final chunk in streamed.stream) {
        parts.add(Uint8List.fromList(chunk));
      }
      int totalLen = 0;
      for (final p in parts) {
        totalLen += p.length;
      }
      final bodyBytes = Uint8List(totalLen);
      int offset = 0;
      for (final p in parts) {
        bodyBytes.setRange(offset, offset + p.length, p);
        offset += p.length;
      }

      if (streamed.statusCode >= 200 && streamed.statusCode < 300) {
        return bodyBytes;
      }
      final rawBody = utf8.decode(bodyBytes);
      throw ApiException(
        streamed.statusCode,
        rawBody.trim().isEmpty ? 'Erreur ${streamed.statusCode}' : rawBody.trim(),
      );
    } on TimeoutException {
      throw const NetworkException('Le serveur ne répond pas (timeout).');
    } on http.ClientException catch (e) {
      throw NetworkException('Impossible de joindre le serveur : ${e.message}');
    }
  }

  Future<dynamic> post(String path, Object body,
          {Map<String, String>? query}) =>
      _send('POST', path, body: body, query: query);

  Future<dynamic> put(String path, Object body,
          {Map<String, String>? query}) =>
      _send('PUT', path, body: body, query: query);

  Future<dynamic> delete(String path) => _send('DELETE', path);

  Future<dynamic> patch(String path, [Object? body]) =>
      _send('PATCH', path, body: body);

  /// Envoi multipart/form-data (ex. création d'un chauffeur avec fichiers).
  /// La partie [data] est encodée en JSON avec Content-Type application/json.
  Future<dynamic> postMultipart(
    String path, {
    required Map<String, dynamic> data,
    Uint8List? permisBytes,
    String permisFilename = 'permis.jpg',
    Uint8List? photoBytes,
    String photoFilename = 'photo.jpg',
  }) async {
    final uri = _buildUri(path, null);
    final token = await _storage.getAccessToken();

    final request = http.MultipartRequest('POST', uri)
      ..headers['Accept'] = 'application/json';
    if (token != null) request.headers['Authorization'] = 'Bearer $token';

    request.files.add(http.MultipartFile.fromBytes(
      'data',
      utf8.encode(jsonEncode(data)),
      contentType: MediaType('application', 'json'),
      filename: 'data.json',
    ));

    if (permisBytes != null) {
      request.files.add(http.MultipartFile.fromBytes(
        'permis',
        permisBytes,
        filename: permisFilename,
      ));
    }

    if (photoBytes != null) {
      request.files.add(http.MultipartFile.fromBytes(
        'photo',
        photoBytes,
        filename: photoFilename,
      ));
    }

    try {
      final streamed = await _http.send(request).timeout(_timeout);
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 401) {
        final refreshed = await _tryRefresh();
        if (refreshed) {
          return postMultipart(
            path,
            data: data,
            permisBytes: permisBytes,
            permisFilename: permisFilename,
            photoBytes: photoBytes,
            photoFilename: photoFilename,
          );
        }
      }

      return _handle(response);
    } on TimeoutException {
      throw const NetworkException('Le serveur ne répond pas (timeout).');
    } on http.ClientException catch (e) {
      throw NetworkException('Impossible de joindre le serveur : ${e.message}');
    }
  }

  /// Envoi multipart/form-data en PUT (ex. mise à jour d'un chauffeur avec
  /// éventuellement une nouvelle photo / un nouveau permis).
  ///
  /// La partie [data] est toujours envoyée ; [permisBytes] et [photoBytes]
  /// sont optionnels (le backend les accepte en `required = false`).
  Future<dynamic> putMultipart(
    String path, {
    required Map<String, dynamic> data,
    Uint8List? permisBytes,
    String permisFilename = 'permis.jpg',
    Uint8List? photoBytes,
    String photoFilename = 'photo.jpg',
  }) async {
    final uri = _buildUri(path, null);
    final token = await _storage.getAccessToken();

    final request = http.MultipartRequest('PUT', uri)
      ..headers['Accept'] = 'application/json';
    if (token != null) request.headers['Authorization'] = 'Bearer $token';

    request.files.add(http.MultipartFile.fromBytes(
      'data',
      utf8.encode(jsonEncode(data)),
      contentType: MediaType('application', 'json'),
      filename: 'data.json',
    ));

    if (permisBytes != null) {
      request.files.add(http.MultipartFile.fromBytes(
        'permis',
        permisBytes,
        filename: permisFilename,
      ));
    }

    if (photoBytes != null) {
      request.files.add(http.MultipartFile.fromBytes(
        'photo',
        photoBytes,
        filename: photoFilename,
      ));
    }

    try {
      final streamed = await _http.send(request).timeout(_timeout);
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 401) {
        final refreshed = await _tryRefresh();
        if (refreshed) {
          return putMultipart(
            path,
            data: data,
            permisBytes: permisBytes,
            permisFilename: permisFilename,
            photoBytes: photoBytes,
            photoFilename: photoFilename,
          );
        }
      }

      return _handle(response);
    } on TimeoutException {
      throw const NetworkException('Le serveur ne répond pas (timeout).');
    } on http.ClientException catch (e) {
      throw NetworkException('Impossible de joindre le serveur : ${e.message}');
    }
  }

  /// Envoi multipart/form-data en PUT avec un seul fichier optionnel nommé
  /// [fileField]. Utilisé notamment pour la mise à jour d'un permis.
  Future<dynamic> putMultipartSingle(
    String path, {
    required Map<String, dynamic> data,
    String fileField = 'fichier',
    Uint8List? fileBytes,
    String fileFilename = 'fichier.jpg',
  }) async {
    final uri = _buildUri(path, null);
    final token = await _storage.getAccessToken();

    final request = http.MultipartRequest('PUT', uri)
      ..headers['Accept'] = 'application/json';
    if (token != null) request.headers['Authorization'] = 'Bearer $token';

    request.files.add(http.MultipartFile.fromBytes(
      'data',
      utf8.encode(jsonEncode(data)),
      contentType: MediaType('application', 'json'),
      filename: 'data.json',
    ));

    if (fileBytes != null) {
      request.files.add(http.MultipartFile.fromBytes(
        fileField,
        fileBytes,
        filename: fileFilename,
      ));
    }

    try {
      final streamed = await _http.send(request).timeout(_timeout);
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 401) {
        final refreshed = await _tryRefresh();
        if (refreshed) {
          return putMultipartSingle(
            path,
            data: data,
            fileField: fileField,
            fileBytes: fileBytes,
            fileFilename: fileFilename,
          );
        }
      }

      return _handle(response);
    } on TimeoutException {
      throw const NetworkException('Le serveur ne répond pas (timeout).');
    } on http.ClientException catch (e) {
      throw NetworkException('Impossible de joindre le serveur : ${e.message}');
    }
  }

  /// Envoi multipart/form-data en POST avec un seul fichier nommé [fileField].
  /// [dataPartName] est le nom de la part JSON (défaut : 'metadata').
  Future<dynamic> postMultipartSingle(
    String path, {
    required Map<String, dynamic> data,
    String dataPartName = 'metadata',
    String fileField = 'fichier',
    required Uint8List fileBytes,
    String fileFilename = 'fichier.jpg',
    String? fileContentType,
  }) async {
    final uri = _buildUri(path, null);
    final token = await _storage.getAccessToken();

    final request = http.MultipartRequest('POST', uri)
      ..headers['Accept'] = 'application/json';
    if (token != null) request.headers['Authorization'] = 'Bearer $token';

    request.files.add(http.MultipartFile.fromBytes(
      dataPartName,
      utf8.encode(jsonEncode(data)),
      contentType: MediaType('application', 'json'),
      filename: 'data.json',
    ));

    request.files.add(http.MultipartFile.fromBytes(
      fileField,
      fileBytes,
      filename: fileFilename,
      contentType:
          fileContentType != null ? MediaType.parse(fileContentType) : null,
    ));

    try {
      final streamed = await _http.send(request).timeout(_timeout);
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 401) {
        final refreshed = await _tryRefresh();
        if (refreshed) {
          return postMultipartSingle(
            path,
            data: data,
            dataPartName: dataPartName,
            fileField: fileField,
            fileBytes: fileBytes,
            fileFilename: fileFilename,
            fileContentType: fileContentType,
          );
        }
      }

      return _handle(response);
    } on TimeoutException {
      throw const NetworkException('Le serveur ne répond pas (timeout).');
    } on http.ClientException catch (e) {
      throw NetworkException('Impossible de joindre le serveur : ${e.message}');
    }
  }

  /// Upload d'un seul fichier (champ "file") — utilisé pour les photos véhicule.
  Future<dynamic> postFile(
    String path, {
    required Uint8List bytes,
    String filename = 'photo.jpg',
    String contentType = 'image/jpeg',
  }) async {
    final uri = _buildUri(path, null);
    final token = await _storage.getAccessToken();

    final request = http.MultipartRequest('POST', uri)
      ..headers['Accept'] = 'application/json';
    if (token != null) request.headers['Authorization'] = 'Bearer $token';

    request.files.add(http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: filename,
      contentType: MediaType.parse(contentType),
    ));

    try {
      final streamed = await _http.send(request).timeout(_timeout);
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode == 401) {
        final refreshed = await _tryRefresh();
        if (refreshed) {
          return postFile(path, bytes: bytes, filename: filename, contentType: contentType);
        }
      }
      return _handle(response);
    } on TimeoutException {
      throw const NetworkException('Le serveur ne répond pas (timeout).');
    } on http.ClientException catch (e) {
      throw NetworkException('Impossible de joindre le serveur : ${e.message}');
    }
  }

  // ── Implémentation interne ──────────────────────────────────────────────

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

      // Tentative de refresh automatique sur 401, une seule fois, hors /auth/*
      if (response.statusCode == 401 && retry && _isRefreshable(path)) {
        final refreshed = await _tryRefresh();
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

  /// Rejoue l'endpoint /auth/refresh avec le refresh token stocké.
  /// Les appels concurrents partagent le même [Future] via [_refreshing].
  /// Retourne `true` si les tokens ont été renouvelés.
  Future<bool> _tryRefresh() async {
    // Un refresh est déjà en cours → on attend son résultat
    if (_refreshing != null) return _refreshing!.future;

    final completer = Completer<bool>();
    _refreshing = completer;
    try {
      final refreshToken = await _storage.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        completer.complete(false);
        return false;
      }

      final uri = _buildUri('/auth/refresh', null);
      final request = http.Request('POST', uri)
        ..headers.addAll({
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        })
        ..body = jsonEncode({'refreshToken': refreshToken});

      final streamed = await _http.send(request).timeout(_timeout);
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data is Map<String, dynamic>) {
          final newAccess = data['accessToken'] as String?;
          final newRefresh = data['refreshToken'] as String?;
          if (newAccess != null && newAccess.isNotEmpty) {
            await _storage.saveTokens(
              accessToken: newAccess,
              refreshToken: newRefresh,
            );
            completer.complete(true);
            return true;
          }
        }
      }

      // Refresh HS → on purge la session pour forcer une reconnexion.
      await _storage.clearTokens();
      completer.complete(false);
      return false;
    } catch (_) {
      await _storage.clearTokens();
      if (!completer.isCompleted) completer.complete(false);
      return false;
    } finally {
      _refreshing = null;
    }
  }

  /// On n'essaie pas de refresh pour les endpoints d'auth eux-mêmes
  /// (sinon boucle infinie sur /auth/refresh ou 401 trompeurs sur /auth/login).
  bool _isRefreshable(String path) {
    return !path.startsWith('/auth/');
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

    String message = _extractMessage(parsedBody, rawBody) ??
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

  Uri _buildUri(String path, Map<String, String>? query) {
    return Uri.parse('${ApiConfig.baseUrl}$path')
        .replace(queryParameters: query);
  }

  Future<Map<String, String>> _buildHeaders() async {
    final token = await _storage.getAccessToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }
}

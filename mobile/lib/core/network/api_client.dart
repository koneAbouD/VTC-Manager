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
import 'session_manager.dart';

/// Messages réseau présentés à l'utilisateur — volontairement clairs et sans
/// détail technique (type d'exception, hôte, URI…), qui n'aident pas
/// l'utilisateur et font « bug ».
const String kMsgServeurTimeout =
    'Le serveur met trop de temps à répondre. Vérifiez votre connexion, puis réessayez.';
const String kMsgServeurInjoignable =
    'Impossible de joindre le serveur. Vérifiez votre connexion internet, puis réessayez.';

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

  // 25s : marge confortable pour un VPS distant via réseau mobile
  // (le localhost répondait en <1s, mais la 4G/3G ajoute de la latence).
  static const _timeout = Duration(seconds: 25);

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
        _messageErreurHttp(result.statusCode, null, rawBody),
      );
    } on TimeoutException {
      throw const NetworkException(kMsgServeurTimeout);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const NetworkException(kMsgServeurInjoignable);
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
        _messageErreurHttp(streamed.statusCode, null, rawBody),
      );
    } on TimeoutException {
      throw const NetworkException(kMsgServeurTimeout);
    } on http.ClientException {
      throw const NetworkException(kMsgServeurInjoignable);
    }
  }

  Future<dynamic> post(String path, Object body,
          {Map<String, String>? query}) =>
      _send('POST', path, body: body, query: query);

  Future<dynamic> put(String path, Object body, {Map<String, String>? query}) =>
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
      throw const NetworkException(kMsgServeurTimeout);
    } on http.ClientException {
      throw const NetworkException(kMsgServeurInjoignable);
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
      throw const NetworkException(kMsgServeurTimeout);
    } on http.ClientException {
      throw const NetworkException(kMsgServeurInjoignable);
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
      throw const NetworkException(kMsgServeurTimeout);
    } on http.ClientException {
      throw const NetworkException(kMsgServeurInjoignable);
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
      throw const NetworkException(kMsgServeurTimeout);
    } on http.ClientException {
      throw const NetworkException(kMsgServeurInjoignable);
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
          return postFile(path,
              bytes: bytes, filename: filename, contentType: contentType);
        }
      }
      return _handle(response);
    } on TimeoutException {
      throw const NetworkException(kMsgServeurTimeout);
    } on http.ClientException {
      throw const NetworkException(kMsgServeurInjoignable);
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
      throw const NetworkException(kMsgServeurTimeout);
    } on http.ClientException {
      throw const NetworkException(kMsgServeurInjoignable);
    }
  }

  /// Délègue le refresh au [SessionManager] centralisé (verrou partagé entre
  /// toutes les instances d'ApiClient, persistance et signal d'expiration).
  Future<bool> _tryRefresh() => SessionManager.instance.refresh();

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

    throw ApiException(status, _messageErreurHttp(status, parsedBody, rawBody),
        body: parsedBody);
  }

  /// Construit un message d'erreur lisible : message applicatif du backend s'il
  /// est présent, sinon message générique par code HTTP. Ne renvoie jamais un
  /// corps HTML brut.
  String _messageErreurHttp(
    int status,
    Map<String, dynamic>? parsed,
    String rawBody,
  ) {
    return _extractMessage(parsed, rawBody) ??
        switch (status) {
          400 => 'Requête invalide.',
          401 => 'Session expirée, veuillez vous reconnecter.',
          403 => 'Action non autorisée.',
          404 => 'Ressource introuvable.',
          413 => 'Le document est trop volumineux.',
          >= 500 => 'Erreur serveur ($status).',
          _ => 'Erreur serveur ($status)',
        };
  }

  String? _extractMessage(Map<String, dynamic>? parsed, String rawBody) {
    if (parsed != null) {
      final msg = parsed['message'] ?? parsed['error'] ?? parsed['detail'];
      if (msg is String && msg.trim().isNotEmpty) {
        final champs = _champsRefuses(parsed);
        return champs == null ? msg.trim() : '${msg.trim()} : $champs';
      }
    }
    final body = rawBody.trim();
    if (body.isEmpty) return null;
    // Corps HTML (page d'erreur Spring Whitelabel, nginx, proxy…) : ne jamais
    // le montrer tel quel à l'utilisateur — on laisse le message générique par
    // code HTTP prendre le relais.
    if (_ressembleAHtml(body)) return null;
    return body;
  }

  /// Champs refusés par la validation serveur, rendus lisibles :
  /// « detailMaintenance.elements[0].montant: ne doit pas être nul » devient
  /// « montant (ne doit pas être nul) ». Réservé aux erreurs de validation —
  /// ailleurs (conflit d'affectation, par exemple), `details` porte des données
  /// structurées destinées au code appelant et non à l'écran.
  String? _champsRefuses(Map<String, dynamic> parsed) {
    if (parsed['error'] != 'VALIDATION_ERROR') return null;
    final details = (parsed['details'] as List?)?.whereType<String>() ?? const [];
    final libelles = <String>[];
    for (final d in details) {
      final sep = d.indexOf(': ');
      if (sep <= 0) continue;
      final champ =
          d.substring(0, sep).split('.').last.replaceAll(RegExp(r'\[\d+\]'), '');
      final raison = d.substring(sep + 2).trim();
      libelles.add(raison.isEmpty ? champ : '$champ ($raison)');
    }
    return libelles.isEmpty ? null : libelles.join(', ');
  }

  /// Heuristique simple : le corps commence par une balise et ressemble à un
  /// document HTML plutôt qu'à un message texte lisible.
  bool _ressembleAHtml(String body) {
    if (!body.startsWith('<')) return false;
    final debut = body.toLowerCase();
    return debut.startsWith('<!doctype') ||
        debut.startsWith('<html') ||
        debut.contains('<body') ||
        debut.contains('</');
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

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:tmk_cache/tmk_cache.dart';
import 'package:tmk_pin/tmk_pin.dart' show JwtClaims;

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

/// Réponse 3xx : l'appel a été détourné avant d'atteindre le serveur — portail
/// d'un Wi-Fi public, forfait épuisé, proxy. C'est un problème d'accès au
/// réseau, pas une erreur du serveur : on dit à l'utilisateur quoi faire.
const String kMsgAccesDetourne =
    'Le serveur est inaccessible depuis ce réseau. Sur un Wi-Fi public, '
    'ouvrez votre navigateur pour vous connecter, ou passez sur les données '
    'mobiles, puis réessayez.';

/// 502, 503, 504 : le proxy est joignable mais le serveur derrière ne répond
/// pas (redémarrage, maintenance).
const String kMsgServeurIndisponible =
    'Le serveur est momentanément indisponible. Réessayez dans quelques '
    'instants.';

/// Autre 5xx sans message du backend.
const String kMsgErreurServeur =
    'Une erreur est survenue sur le serveur. Réessayez ; si le problème '
    'persiste, contactez le support.';

/// Code inattendu (1xx, 4xx non prévu…) sans message du backend.
const String kMsgReponseInattendue =
    'Réponse inattendue du serveur. Réessayez dans un instant.';

/// Client HTTP partagé par tous les datasources.
/// - Injecte automatiquement le Bearer token.
/// - Sur un 401, tente un refresh token puis rejoue la requête **une seule fois**.
/// - Normalise les réponses JSON (dynamic).
/// - Lance [ApiException] pour les erreurs HTTP et [NetworkException] pour
///   les erreurs réseau (timeout, pas de connexion, appel détourné par une
///   redirection 3xx).
/// - Sans réseau, rejoue la dernière réponse connue d'une lecture (voir [get]).
class ApiClient {
  final SecureStorage _storage;
  final http.Client _http;
  final ReponseCache _cache;
  final EtatHorsLigne _horsLigne;

  ApiClient(
    this._storage, [
    http.Client? client,
    ReponseCache? cache,
    EtatHorsLigne? horsLigne,
  ])  : _http = client ?? http.Client(),
        _cache = cache ?? ReponseCache.instance,
        _horsLigne = horsLigne ?? EtatHorsLigne.instance;

  // 25s : marge confortable pour un VPS distant via réseau mobile
  // (le localhost répondait en <1s, mais la 4G/3G ajoute de la latence).
  static const _timeout = Duration(seconds: 25);

  // ── Méthodes publiques ──────────────────────────────────────────────────

  /// Lecture. Quand le serveur est hors d'atteinte (pas de réseau, portail
  /// Wi-Fi, maintenance), rejoue la dernière réponse connue de la même URL et
  /// signale au bandeau « hors connexion » de quand elle date.
  ///
  /// Une réponse du serveur, même une erreur, l'emporte toujours : un 403 ou
  /// un 404 n'est jamais masqué par le cache.
  Future<dynamic> get(String path, {Map<String, String>? query}) async {
    if (lectureCacheSeul) {
      final enCache = await lireCache(path, query: query);
      if (enCache == null) throw const NetworkException(_kPasEnCache);
      return enCache;
    }
    try {
      return await _lireServeur(path, query);
    } on NetworkException {
      final secours = await _depuisLeCache(path, query);
      if (secours == null) rethrow;
      return secours.donnees;
    } on ApiException catch (e) {
      if (!_serveurIndisponible(e.statusCode)) rethrow;
      final secours = await _depuisLeCache(path, query);
      if (secours == null) rethrow;
      return secours.donnees;
    }
  }

  /// Exécute [lecture] — un appel ordinaire de datasource ou de repository —
  /// sur le cache seul : chaque [get] rend la dernière réponse enregistrée
  /// de son URL, sans appel au serveur ni bandeau, ou échoue s'il n'y en a
  /// pas (une [NetworkException], que les repositories traduisent en échec).
  ///
  /// De quoi afficher la dernière version connue d'un écran à partir du code
  /// qui le charge, sans écrire une variante « cache » de chaque lecture.
  static Future<T> depuisLeCacheSeul<T>(Future<T> Function() lecture) =>
      runZoned(lecture, zoneValues: {_cacheSeul: true});

  /// Vrai pendant [depuisLeCacheSeul] : un double de test qui ne passe pas
  /// par l'ApiClient s'y comporte comme un cache vide.
  static bool get lectureCacheSeul => Zone.current[_cacheSeul] == true;

  static final _cacheSeul = Object();
  static const _kPasEnCache = 'Aucune réponse en cache.';

  /// Dernière réponse enregistrée de cette lecture, sans aller au serveur :
  /// de quoi afficher un écran aussitôt, le temps que [get] réponde. `null`
  /// si rien n'est en cache. Ne touche pas au bandeau hors connexion — les
  /// données vont être remplacées, elles ne sont pas présentées comme les
  /// dernières disponibles.
  Future<dynamic> lireCache(String path, {Map<String, String>? query}) async {
    if (!_cachable(path)) return null;
    final enCache = await _cache
        .lire(
          _buildUri(path, query).toString(),
          proprietaire: await _proprietaireCourant(),
        )
        .timeout(_attenteCache, onTimeout: () => null);
    return enCache == null ? null : _decoder(enCache.corps);
  }

  /// Lecture faite d'avance, pour que l'écran la trouve hors connexion : la
  /// réponse rejoint le cache, rien n'est rendu. Sans réseau, rien ne se
  /// passe — ni erreur, ni repli sur le cache, ni bandeau.
  ///
  /// Retourne `false` quand le serveur est hors d'atteinte : inutile alors de
  /// tenter les lectures suivantes. Un refus du serveur (403, 404…) ne
  /// concerne que cette lecture-là.
  Future<bool> precharger(String path, {Map<String, String>? query}) async {
    try {
      await _lireServeur(path, query);
    } on NetworkException {
      return false;
    } on ApiException catch (e) {
      return !_serveurIndisponible(e.statusCode);
    } catch (_) {
      // Corps illisible : le serveur, lui, a répondu.
    }
    return true;
  }

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
      throw _erreurHttp(result.statusCode, result.bytes);
    } on TimeoutException {
      throw const NetworkException(kMsgServeurTimeout);
    } on ApiException {
      rethrow;
    } on NetworkException {
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
      throw _erreurHttp(streamed.statusCode, bodyBytes);
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
    String? siDifferent,
  }) async {
    final uri = _buildUri(path, query);
    final headers = await _buildHeaders();

    try {
      final request = http.Request(method, uri)..headers.addAll(headers);
      if (body != null) request.body = jsonEncode(body);
      if (siDifferent != null) request.headers['If-None-Match'] = siDifferent;

      final streamed = await _http.send(request).timeout(_timeout);
      final response = await http.Response.fromStream(streamed);

      // Tentative de refresh automatique sur 401, une seule fois, hors /auth/*
      if (response.statusCode == 401 && retry && _isRefreshable(path)) {
        final refreshed = await _tryRefresh();
        if (refreshed) {
          return _send(method, path,
              query: query, body: body, retry: false, siDifferent: siDifferent);
        }
      }

      if (response.statusCode == 304 && siDifferent != null) {
        _horsLigne.serveurJoignable();
        return _nonModifie;
      }
      _noterReponse(method, path, uri, response, headers['Authorization']);
      return _handle(response);
    } on TimeoutException {
      throw const NetworkException(kMsgServeurTimeout);
    } on http.ClientException {
      throw const NetworkException(kMsgServeurInjoignable);
    }
  }

  // ── Cache hors connexion ────────────────────────────────────────────────

  /// Lecture au serveur, revalidée par l'ETag de la réponse en cache : si
  /// rien n'a changé, le serveur répond 304 sans corps et c'est la réponse
  /// enregistrée qui sert — confirmée à jour.
  Future<dynamic> _lireServeur(String path, Map<String, String>? query) async {
    if (!_cachable(path)) return _send('GET', path, query: query);
    final url = _buildUri(path, query).toString();
    final proprietaire = await _proprietaireCourant();
    // Un disque lent ne retient pas la requête : sans ETag à temps, elle
    // part sans condition.
    final etag = await _cache
        .etag(url, proprietaire: proprietaire)
        .timeout(_attenteCache, onTimeout: () => null);
    final reponse = await _send('GET', path, query: query, siDifferent: etag);
    if (!identical(reponse, _nonModifie)) return reponse;
    final enCache = await _cache.lire(url, proprietaire: proprietaire);
    // Purgée entre la question et la réponse (déconnexion) : on redemande
    // le corps.
    if (enCache == null) return _send('GET', path, query: query);
    unawaited(_cache.confirmer(url));
    return _decoder(enCache.corps);
  }

  /// Au-delà, une lecture du cache est abandonnée : la base s'ouvre en
  /// quelques millisecondes, sauf incident.
  static const _attenteCache = Duration(milliseconds: 500);

  /// Réponse 304 : le corps est celui du cache.
  static const _nonModifie = Object();

  dynamic _decoder(List<int> corps) =>
      corps.isEmpty ? null : jsonDecode(utf8.decode(corps));

  /// Le serveur a répondu : le bandeau hors connexion tombe, et une lecture
  /// réussie devient la réponse de secours de son URL.
  void _noterReponse(
    String method,
    String path,
    Uri uri,
    http.Response response,
    String? autorisation,
  ) {
    final status = response.statusCode;
    if ((status >= 300 && status < 400) || _serveurIndisponible(status)) return;
    _horsLigne.serveurJoignable();
    if (method == 'GET' && status < 300 && _cachable(path)) {
      unawaited(_cache.ecrire(
        uri.toString(),
        response.bodyBytes,
        proprietaire: _proprietaire(autorisation),
        etag: response.headers['etag'],
      ));
    }
  }

  Future<({Object? donnees})?> _depuisLeCache(
    String path,
    Map<String, String>? query,
  ) async {
    if (!_cachable(path)) return null;
    final enCache = await _cache
        .lire(
          _buildUri(path, query).toString(),
          proprietaire: await _proprietaireCourant(),
        )
        .timeout(_attenteCache * 4, onTimeout: () => null);
    if (enCache == null) return null;
    _horsLigne.donneesDuCache(enCache.enregistreLe);
    return (donnees: _decoder(enCache.corps) as Object?);
  }

  /// Compte connecté. Ouverte hors connexion, l'application n'a pas encore de
  /// jeton d'accès : le refresh token sorti du coffre porte le même compte.
  Future<String?> _proprietaireCourant() async {
    try {
      return _proprietaire(
          await _storage.getAccessToken() ?? await _storage.getRefreshToken());
    } catch (_) {
      return null;
    }
  }

  /// 502, 503, 504 : le proxy répond, pas l'application. Pour l'écran, c'est
  /// une coupure comme une autre.
  bool _serveurIndisponible(int status) =>
      status == 502 || status == 503 || status == 504;

  /// Les échanges d'authentification ne se rejouent jamais.
  bool _cachable(String path) => !path.startsWith('/auth/');

  /// Compte (`sub`) auquel appartient une réponse, lu dans le jeton d'accès.
  String? _proprietaire(String? jeton) {
    if (jeton == null) return null;
    final brut = jeton.startsWith('Bearer ') ? jeton.substring(7) : jeton;
    return JwtClaims.parse(brut).string('sub');
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
    throw _erreurHttp(status, response.bodyBytes);
  }

  /// Exception à lever pour une réponse hors 2xx.
  ///
  /// Une redirection (3xx) n'est jamais une réponse du backend, qui n'en émet
  /// pas : c'est le réseau qui a intercepté l'appel. Elle remonte donc comme
  /// une [NetworkException] — l'écran la traite comme « serveur injoignable »
  /// (à la connexion : la saisie n'est pas en cause).
  ///
  /// Le corps est décodé en tolérant un encodage autre que l'UTF-8 (page de
  /// proxy en Latin-1…) : un caractère illisible vaut mieux qu'un plantage du
  /// décodage, qui remonterait à l'écran sous forme d'exception technique.
  Exception _erreurHttp(int status, List<int> corps) {
    if (status >= 300 && status < 400) {
      return const NetworkException(kMsgAccesDetourne);
    }
    final rawBody = utf8.decode(corps, allowMalformed: true);
    final parsedBody = _corpsJson(rawBody);
    return ApiException(
      status,
      _messageErreurHttp(status, parsedBody, rawBody),
      body: parsedBody,
    );
  }

  /// Corps d'erreur JSON du backend, ou null s'il n'en est pas un (page HTML
  /// d'un proxy, corps vide).
  Map<String, dynamic>? _corpsJson(String rawBody) {
    try {
      final decode = jsonDecode(rawBody);
      return decode is Map<String, dynamic> ? decode : null;
    } catch (_) {
      return null;
    }
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
          502 || 503 || 504 => kMsgServeurIndisponible,
          >= 500 => kMsgErreurServeur,
          _ => kMsgReponseInattendue,
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

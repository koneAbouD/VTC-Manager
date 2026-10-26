import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:tmk_cache/tmk_cache.dart';
import 'package:tmk_pin/tmk_pin.dart' show JwtClaims;

import '../error/exception.dart';
import '../storage/secure_storage.dart';
import 'api_config.dart';
import 'session_manager.dart';

/// Messages réseau présentés au chauffeur — clairs et sans détail technique
/// (type d'exception, hôte, code HTTP), qui n'aident pas et font « bug ».
/// Mêmes textes que l'app gestionnaire.
const String kMsgServeurTimeout =
    'Le serveur met trop de temps à répondre. Vérifiez votre connexion, puis réessayez.';
const String kMsgServeurInjoignable =
    'Impossible de joindre le serveur. Vérifiez votre connexion internet, puis réessayez.';

/// Réponse 3xx : l'appel a été détourné avant d'atteindre le serveur — portail
/// d'un Wi-Fi public, forfait épuisé, proxy. C'est un problème d'accès au
/// réseau, pas une erreur du serveur : on dit quoi faire.
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

/// Code inattendu sans message du backend.
const String kMsgReponseInattendue =
    'Réponse inattendue du serveur. Réessayez dans un instant.';

/// Client HTTP de l'app chauffeur (lecture seule + auth OTP).
/// - Injecte le Bearer token.
/// - Sur un 401 (hors /auth/*), tente un refresh puis rejoue une seule fois.
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
  ]) : _http = client ?? http.Client(),
       _cache = cache ?? ReponseCache.instance,
       _horsLigne = horsLigne ?? EtatHorsLigne.instance;

  static const _timeout = Duration(seconds: 25);

  /// Lecture. Quand le serveur est hors d'atteinte (pas de réseau, portail
  /// Wi-Fi, maintenance), rejoue la dernière réponse connue de la même URL et
  /// signale au bandeau « hors connexion » de quand elle date.
  ///
  /// Une réponse du serveur, même une erreur, l'emporte toujours : un 403 ou
  /// un 404 n'est jamais masqué par le cache.
  Future<dynamic> get(String path, {Map<String, String>? query}) async {
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

  Future<dynamic> post(String path, [Object? body]) =>
      _send('POST', path, body: body);

  /// Seule écriture destructive de l'app chauffeur : le retrait de son appareil
  /// des destinataires de notifications, à la déconnexion.
  Future<dynamic> delete(String path) => _send('DELETE', path);

  /// Modification partielle : marquer une notification comme lue.
  Future<dynamic> patch(String path, [Object? body]) =>
      _send('PATCH', path, body: body);

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
      throw _erreurHttp(streamed.statusCode, bytes);
    } on TimeoutException {
      throw const NetworkException(kMsgServeurTimeout);
    } on http.ClientException {
      throw const NetworkException(kMsgServeurInjoignable);
    }
  }

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

      if (response.statusCode == 401 && retry && !path.startsWith('/auth/')) {
        final refreshed = await SessionManager.instance.refresh();
        if (refreshed) {
          return _send(
            method,
            path,
            query: query,
            body: body,
            retry: false,
            siDifferent: siDifferent,
          );
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
      unawaited(
        _cache.ecrire(
          uri.toString(),
          response.bodyBytes,
          proprietaire: _proprietaire(autorisation),
          etag: response.headers['etag'],
        ),
      );
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
        await _storage.getAccessToken() ?? await _storage.getRefreshToken(),
      );
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
  /// une [NetworkException] — l'écran la traite comme « serveur injoignable ».
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
    final message = _extractMessage(parsedBody, rawBody) ??
        switch (status) {
          400 => 'Requête invalide.',
          401 => 'Session expirée, veuillez vous reconnecter.',
          403 => 'Action non autorisée.',
          404 => 'Ressource introuvable.',
          502 || 503 || 504 => kMsgServeurIndisponible,
          >= 500 => kMsgErreurServeur,
          _ => kMsgReponseInattendue,
        };
    return ApiException(status, message, body: parsedBody);
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

  /// Message applicatif du backend s'il est présent. Un corps texte court est
  /// repris tel quel ; un corps HTML (page de proxy, erreur nginx…) ou un JSON
  /// sans message ne l'est jamais : le message générique prend le relais.
  String? _extractMessage(Map<String, dynamic>? parsed, String rawBody) {
    if (parsed != null) {
      final msg = parsed['message'] ?? parsed['error'] ?? parsed['detail'];
      if (msg is String && msg.trim().isNotEmpty) return msg.trim();
      return null;
    }
    final body = rawBody.trim();
    if (body.isEmpty || _ressembleAHtml(body)) return null;
    return body;
  }

  bool _ressembleAHtml(String body) {
    if (!body.startsWith('<')) return false;
    final debut = body.toLowerCase();
    return debut.startsWith('<!doctype') ||
        debut.startsWith('<html') ||
        debut.contains('<body') ||
        debut.contains('</');
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

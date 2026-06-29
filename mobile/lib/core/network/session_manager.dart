import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import '../storage/secure_storage.dart';
import 'api_config.dart';

/// Gestion centralisée de la session et du refresh token.
///
/// Singleton unique partagé par toutes les instances d'[ApiClient] : un seul
/// verrou de refresh, un seul point de persistance des tokens, un seul signal
/// d'expiration.
///
/// Responsabilités :
///  • Rafraîchir l'access token (réactif sur 401 via [refresh], ou proactif
///    via un timer tant que l'app est ouverte/au premier plan).
///  • Émettre [onSessionExpired] quand le refresh token est invalide/expiré
///    afin que la couche présentation déconnecte l'utilisateur.
class SessionManager with WidgetsBindingObserver {
  SessionManager._();
  static final SessionManager instance = SessionManager._();

  final SecureStorage _storage = const SecureStorage();
  http.Client _http = http.Client();

  static const _timeout = Duration(seconds: 25);

  /// On rafraîchit lorsqu'il reste cette fraction de la durée de vie restante,
  /// et au plus tard [_minLeadTime] avant l'expiration.
  static const _refreshAtRemainingFraction = 0.25; // 75 % écoulés
  static const _minLeadTime = Duration(seconds: 30);
  static const _minTimer = Duration(seconds: 5);

  /// Durée d'inactivité (premier plan) au-delà de laquelle l'utilisateur est
  /// déconnecté automatiquement.
  static const _inactivityTimeout = Duration(minutes: 15);

  static const _msgSessionExpiree =
      'Votre session a expiré. Veuillez vous reconnecter.';
  static const _msgInactivite =
      'Vous avez été déconnecté pour inactivité.';

  /// Verrou : mutualise un refresh en cours entre tous les appelants.
  Completer<bool>? _refreshing;
  Timer? _proactiveTimer;
  Timer? _inactivityTimer;
  bool _started = false;

  final StreamController<String> _expiredCtrl =
      StreamController<String>.broadcast();

  /// Émis (une fois) quand la session est perdue (refresh impossible ou
  /// inactivité). La valeur est le message à présenter à l'utilisateur.
  Stream<String> get onSessionExpired => _expiredCtrl.stream;

  /// Permet l'injection d'un client HTTP en test.
  @visibleForTesting
  set httpClient(http.Client client) => _http = client;

  // ── Cycle de vie de la session ─────────────────────────────────────────

  /// À appeler une fois l'utilisateur authentifié (login ou bootstrap réussi).
  /// Démarre le refresh proactif, le timer d'inactivité et l'observation du
  /// cycle de vie de l'app.
  void start() {
    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addObserver(this);
    }
    _scheduleProactiveRefresh();
    _restartInactivityTimer();
  }

  /// À appeler à la déconnexion : arrête tous les timers.
  void stop() {
    _proactiveTimer?.cancel();
    _proactiveTimer = null;
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
    if (_started) {
      _started = false;
      WidgetsBinding.instance.removeObserver(this);
    }
  }

  /// À appeler à chaque interaction utilisateur (tap, scroll, saisie) pour
  /// réarmer le compteur d'inactivité. Sans effet si aucune session active.
  void recordActivity() {
    if (!_started) return;
    _restartInactivityTimer();
  }

  void _restartInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(_inactivityTimeout, _onInactivityTimeout);
  }

  Future<void> _onInactivityTimeout() async {
    // Inactivité prolongée au premier plan → déconnexion.
    await _storage.clearTokens();
    _emitExpired(_msgInactivite);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // Retour au premier plan : refresh FORCÉ systématique (même si le token
        // n'est pas proche d'expirer) + réarmement du compteur d'inactivité.
        unawaited(refresh());
        _restartInactivityTimer();
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        // Arrière-plan : on suspend les timers (pas de travail en fond).
        _proactiveTimer?.cancel();
        _inactivityTimer?.cancel();
      case AppLifecycleState.detached:
        // Fermeture de l'app : on purge les tokens (reconnexion au prochain
        // lancement). Note : non garanti si l'OS tue brutalement le process.
        _proactiveTimer?.cancel();
        _inactivityTimer?.cancel();
        unawaited(_storage.clearTokens());
    }
  }

  // ── Planification du refresh proactif ──────────────────────────────────

  Future<void> _scheduleProactiveRefresh() async {
    _proactiveTimer?.cancel();
    final expiry = await _storage.getAccessTokenExpiry();
    if (expiry == null) return;

    final remaining = expiry.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      // Déjà expiré → refresh immédiat.
      unawaited(refresh());
      return;
    }

    // Rafraîchir quand il reste [_refreshAtRemainingFraction] de la vie, mais
    // au plus tard [_minLeadTime] avant l'expiration.
    final byFraction = remaining * (1 - _refreshAtRemainingFraction);
    final byLeadTime = remaining - _minLeadTime;
    var delay = byFraction < byLeadTime ? byFraction : byLeadTime;
    if (delay < _minTimer) delay = _minTimer;

    _proactiveTimer = Timer(delay, () => unawaited(refresh()));
  }

  // ── Refresh (réactif et proactif passent tous par ici) ─────────────────

  /// Rejoue `/auth/refresh` avec le refresh token stocké.
  /// Les appels concurrents partagent le même [Future] via [_refreshing].
  /// Retourne `true` si les tokens ont été renouvelés.
  Future<bool> refresh() {
    final inFlight = _refreshing;
    if (inFlight != null) return inFlight.future;

    final completer = Completer<bool>();
    _refreshing = completer;
    _doRefresh().then((ok) {
      _refreshing = null;
      completer.complete(ok);
    }).catchError((Object _) {
      _refreshing = null;
      completer.complete(false);
    });
    return completer.future;
  }

  Future<bool> _doRefresh() async {
    final refreshToken = await _storage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      // Plus de refresh token : session perdue.
      _emitExpired(_msgSessionExpiree);
      return false;
    }

    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/auth/refresh');
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
          final expiresIn = (data['expiresIn'] as num?)?.toInt();
          if (newAccess != null && newAccess.isNotEmpty) {
            await _storage.saveTokens(
              accessToken: newAccess,
              refreshToken: newRefresh,
              expiresInSeconds: expiresIn,
            );
            _scheduleProactiveRefresh();
            return true;
          }
        }
        // Réponse 2xx mais corps inattendu → on considère la session perdue.
        await _storage.clearTokens();
        _emitExpired(_msgSessionExpiree);
        return false;
      }

      // Refus du serveur (401/400 invalide ou expiré) → session perdue.
      await _storage.clearTokens();
      _emitExpired(_msgSessionExpiree);
      return false;
    } catch (_) {
      // Erreur réseau transitoire (timeout, pas de connexion) : on NE déconnecte
      // PAS l'utilisateur — on retentera plus tard. Les tokens sont conservés.
      return false;
    }
  }

  void _emitExpired(String message) {
    stop();
    if (!_expiredCtrl.isClosed) _expiredCtrl.add(message);
  }
}

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tmk_pin/tmk_pin.dart';

import '../../../../core/network/session_manager.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories_impl/auth_repository_impl.dart';
import '../../domain/entities/auth_tokens.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/password_login_usecase.dart';
import '../../domain/usecases/request_otp_usecase.dart';
import '../../domain/usecases/set_password_usecase.dart';
import '../../domain/usecases/verify_otp_usecase.dart';
import 'auth_state.dart';
import 'unlock_outcome.dart';

// ── Datasource → Repository → Use cases ───────────────────────────────────────

final _authDatasourceProvider = Provider<AuthRemoteDatasource>(
  (ref) => AuthRemoteDatasource(ref.watch(apiClientProvider)),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(ref.watch(_authDatasourceProvider)),
);

final _requestOtpUseCaseProvider = Provider(
  (ref) => RequestOtpUseCase(ref.watch(authRepositoryProvider)),
);
final _verifyOtpUseCaseProvider = Provider(
  (ref) => VerifyOtpUseCase(ref.watch(authRepositoryProvider)),
);
final _passwordLoginUseCaseProvider = Provider(
  (ref) => PasswordLoginUseCase(ref.watch(authRepositoryProvider)),
);
final _setPasswordUseCaseProvider = Provider(
  (ref) => SetPasswordUseCase(ref.watch(authRepositoryProvider)),
);

/// Verrou local par code d'accès (voir paquet `tmk_pin`).
final pinServiceProvider = Provider<PinService>(
  (_) => PinService(const PinStore(SecureKeyValueStore())),
);

// ── Contrôleur d'état global d'authentification ───────────────────────────────

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

/// Détient l'état d'authentification global et pilote la session.
/// Les erreurs sont levées sous forme de message (String), présentées par les
/// pages via `messageFromError`.
class AuthController extends Notifier<AuthState> {
  late final SecureStorage _storage;
  late final PinService _pin;

  StreamSubscription<LockReason>? _lockSub;

  /// Abonnement au signal d'expiration centralisé du [SessionManager].
  StreamSubscription<String>? _expirySub;

  @override
  AuthState build() {
    _storage = ref.watch(secureStorageProvider);
    _pin = ref.watch(pinServiceProvider);

    // Inactivité ou retour d'arrière-plan : on remet sous clé si un code est
    // configuré, sinon on ferme la session comme auparavant.
    _lockSub = SessionManager.instance.onLockRequested.listen((reason) {
      unawaited(_handleLockRequest(reason));
    });

    // Tokens non renouvelables : le coffre du code peut rester valide (tokens
    // en clair purgés à la fermeture, par exemple). On remet sous clé plutôt
    // que de le détruire — le déverrouillage tranchera.
    _expirySub = SessionManager.instance.onSessionExpired.listen((message) {
      SessionManager.instance.stop();
      unawaited(_handleExpiry(message));
    });

    // Chaque renouvellement de tokens rechiffre le coffre, tant que la session
    // est déverrouillée (sans quoi l'appel est simplement ignoré).
    SessionManager.instance.onTokensRenewed =
        (refreshToken) => unawaited(_pin.updateRefreshToken(refreshToken));

    ref.onDispose(() {
      _lockSub?.cancel();
      _expirySub?.cancel();
      SessionManager.instance.onTokensRenewed = null;
    });

    return const AuthUnknown();
  }

  Future<void> bootstrap() async {
    // Un code d'accès configuré prime : les tokens en clair ont pu être purgés
    // à la fermeture, seul le coffre chiffré fait foi.
    if (await _pin.isConfigured()) {
      state = AuthLocked(displayName: await _pin.displayName());
      return;
    }
    if (await _storage.hasAccessToken()) {
      SessionManager.instance.start();
      // Session ouverte mais pas de code : le cas ne subsiste que pour les
      // appareils connectés avant qu'il devienne obligatoire. On le fait
      // installer maintenant plutôt que d'ouvrir l'application.
      state = AuthPinSetup(displayName: await _displayName());
    } else {
      state = const AuthUnauthenticated();
    }
  }

  // ── Connexion ───────────────────────────────────────────────────────────

  Future<void> requestOtp(String telephone) async {
    final result = await ref.read(_requestOtpUseCaseProvider).call(telephone);
    result.fold((f) => throw f.message, (_) {});
  }

  Future<void> verifyOtp(String telephone, String code) async {
    final result =
        await ref.read(_verifyOtpUseCaseProvider).call(telephone, code);
    await result.fold((f) => throw f.message, _persisterEtActiver);
  }

  Future<void> passwordLogin(String identifiant, String motDePasse) async {
    final result = await ref
        .read(_passwordLoginUseCaseProvider)
        .call(identifiant, motDePasse);
    await result.fold((f) => throw f.message, _persisterEtActiver);
  }

  Future<void> setPassword(String motDePasse) async {
    final result = await ref.read(_setPasswordUseCaseProvider).call(motDePasse);
    result.fold((f) => throw f.message, (_) {});
  }

  Future<void> _persisterEtActiver(AuthTokens tokens) async {
    await _storage.saveTokens(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      expiresInSeconds: tokens.expiresInSeconds,
    );
    // Un éventuel code existant protège un refresh token désormais périmé : il
    // sera reproposé à la volée plutôt que conservé inutilisable.
    await _pin.reset();
    SessionManager.instance.start();

    // Le code d'accès est le seul chemin de retour dans l'application : on le
    // fait choisir avant d'entrer, sans échappatoire.
    state = AuthPinSetup(displayName: await _displayName());
  }

  Future<void> logout() async {
    SessionManager.instance.stop();
    // Déconnexion volontaire : le code d'accès et son coffre disparaissent avec
    // la session — la prochaine ouverture repassera par la connexion.
    await _pin.reset();
    await _storage.clearTokens();
    state = const AuthUnauthenticated();
  }

  // ── Code d'accès ────────────────────────────────────────────────────────

  /// Prénom du chauffeur. Le jeton le porte (`given_name`, renseigné par le
  /// provisionnement Keycloak) ; l'identifiant, lui, est le numéro de
  /// téléphone et n'est jamais affiché.
  Future<String?> _displayName() async =>
      DisplayName.resolve(accessToken: await _storage.getAccessToken());

  Future<String> _accountId() async {
    final claims = JwtClaims.parse(await _storage.getAccessToken());
    return claims.preferredUsername ?? '';
  }

  /// Enregistre le prénom issu de `/me/profil` : source de vérité métier, plus
  /// fiable que le jeton si le gestionnaire a corrigé l'orthographe.
  Future<void> saveDisplayName(String prenom) => _pin.saveDisplayName(prenom);

  Future<bool> isPinConfigured() => _pin.isConfigured();

  /// Installe le code d'accès. Retourne un message d'erreur, ou `null`.
  Future<String?> configurePin(
    String code, {
    bool entrerDansLApplication = true,
  }) async {
    final invalide = PinService.validate(code);
    if (invalide != null) return invalide;

    final refreshToken = await _storage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      return 'Session introuvable. Reconnectez-vous pour définir un code.';
    }

    final displayName = await _displayName();
    await _pin.configure(
      code: code,
      refreshToken: refreshToken,
      account: await _accountId(),
      displayName: displayName,
    );
    if (entrerDansLApplication) state = AuthAuthenticated(displayName);
    return null;
  }

  Future<String?> changePin({
    required String currentCode,
    required String newCode,
  }) async {
    final invalide = PinService.validate(newCode);
    if (invalide != null) return invalide;

    final change =
        await _pin.changeCode(currentCode: currentCode, newCode: newCode);
    return change ? null : 'Code actuel incorrect.';
  }

  /// Remet la session sous clé : les tokens en clair sont effacés, seul le
  /// coffre chiffré subsiste.
  Future<void> lock({String? message}) async {
    SessionManager.instance.stop();
    _pin.lock();
    await _storage.clearTokens();
    state = AuthLocked(
      displayName: await _pin.displayName(),
      message: message,
    );
  }

  Future<void> _handleExpiry(String message) async {
    // Déjà sous clé : ne pas écraser le motif affiché au chauffeur.
    if (state is AuthLocked) return;
    if (await _pin.isConfigured()) {
      await lock();
      return;
    }
    await _storage.clearTokens();
    state = AuthUnauthenticated(message);
  }

  Future<void> _handleLockRequest(LockReason reason) async {
    if (await _pin.isConfigured()) {
      await lock(
        message: reason == LockReason.inactivite
            ? 'Session verrouillée après une période d\'inactivité.'
            : null,
      );
      return;
    }
    SessionManager.instance.stop();
    await _storage.clearTokens();
    state = AuthUnauthenticated(
      reason == LockReason.inactivite
          ? 'Vous avez été déconnecté pour inactivité.'
          : null,
    );
  }

  /// Au-delà de ce délai, le déverrouillage rend la main avec un message
  /// plutôt que de faire patienter devant un écran figé.
  static const _delaiReouverture = Duration(seconds: 8);

  /// Vérifie le code saisi et, s'il est bon, rouvre la session.
  Future<UnlockOutcome> unlock(String code) async {
    final nom = state is AuthLocked ? (state as AuthLocked).displayName : null;
    final result = await _pin.unlock(code);

    switch (result) {
      case UnlockFailure(:final remainingAttempts):
        return UnlockWrong(remainingAttempts);

      case UnlockThrottled(:final remaining):
        return UnlockWait(remaining);

      case UnlockExhausted():
        await _storage.clearTokens();
        state = const AuthUnauthenticated(
          'Code incorrect à plusieurs reprises. Reconnectez-vous.',
        );
        return const UnlockRequiresLogin();

      case UnlockSuccess(:final refreshToken):
        // Le token ressort du coffre le temps de la session.
        await _storage.saveRefreshToken(refreshToken);

        // Le verrou est local : on ne fait pas dépendre l'ouverture d'un
        // aller-retour réseau complet. Au-delà de [_delaiReouverture], on rend
        // la main plutôt que de laisser l'utilisateur devant un écran qui
        // tourne — le client HTTP, lui, patiente jusqu'à 25 s.
        final ok = await SessionManager.instance
            .refresh()
            .timeout(_delaiReouverture, onTimeout: () => false);
        if (ok) {
          SessionManager.instance.start();
          await _syncVaultWithStoredToken();
          state = AuthAuthenticated(nom);
          return const UnlockOk();
        }

        // Échec : le SessionManager purge les tokens quand le serveur refuse le
        // refresh, et les conserve sur une simple panne réseau. La présence du
        // refresh token distingue donc les deux cas.
        final encorePresent = await _storage.getRefreshToken();
        if (encorePresent != null && encorePresent.isNotEmpty) {
          // Le code était bon : on reverrouille sans compter d'échec.
          _pin.lock();
          await _storage.clearTokens();
          return const UnlockOffline(
            'Connexion impossible. Vérifiez votre réseau et réessayez.',
          );
        }

        await _pin.reset();
        state = const AuthUnauthenticated(
          'Votre session a expiré. Veuillez vous reconnecter.',
        );
        return const UnlockRequiresLogin();
    }
  }

  Future<void> _syncVaultWithStoredToken() async {
    final refreshToken = await _storage.getRefreshToken();
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _pin.updateRefreshToken(refreshToken);
    }
  }

  /// Abandon du code depuis l'écran de verrouillage (« Code oublié ? ») :
  /// retour à la connexion complète.
  Future<void> forgetPin() async {
    await _pin.reset();
    await _storage.clearTokens();
    state = const AuthUnauthenticated();
  }
}

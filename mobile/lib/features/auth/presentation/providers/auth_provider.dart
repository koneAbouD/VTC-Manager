import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:tmk_pin/tmk_pin.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/session_manager.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories_impl/auth_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/forgot_password_usecase.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/logout_usecase.dart';
import '../../domain/usecases/refresh_token_usecase.dart';
import '../../domain/usecases/register_usecase.dart';
import 'auth_state.dart';
import 'unlock_outcome.dart';

// ── Infrastructure ──────────────────────────────────────────────────────────

final secureStorageProvider = Provider<SecureStorage>(
  (_) => const SecureStorage(),
);

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(ref.watch(secureStorageProvider)),
);

/// Verrou local par code d'accès (voir paquet `tmk_pin`).
final pinServiceProvider = Provider<PinService>(
  (_) => PinService(const PinStore(SecureKeyValueStore())),
);

// ── Datasource → Repository (injection de dépendances) ──────────────────────

final authRemoteDatasourceProvider = Provider<AuthRemoteDatasource>(
  (ref) => AuthRemoteDatasource(ref.watch(apiClientProvider)),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(
    ref.watch(authRemoteDatasourceProvider),
    ref.watch(secureStorageProvider),
  ),
);

// ── Use cases ───────────────────────────────────────────────────────────────

final loginUseCaseProvider = Provider(
  (ref) => LoginUseCase(ref.watch(authRepositoryProvider)),
);
final registerUseCaseProvider = Provider(
  (ref) => RegisterUseCase(ref.watch(authRepositoryProvider)),
);
final logoutUseCaseProvider = Provider(
  (ref) => LogoutUseCase(ref.watch(authRepositoryProvider)),
);
final refreshTokenUseCaseProvider = Provider(
  (ref) => RefreshTokenUseCase(ref.watch(authRepositoryProvider)),
);
final forgotPasswordUseCaseProvider = Provider(
  (ref) => ForgotPasswordUseCase(ref.watch(authRepositoryProvider)),
);

// ── Notifier ─────────────────────────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  final LoginUseCase _login;
  final RegisterUseCase _register;
  final LogoutUseCase _logout;
  final RefreshTokenUseCase _refresh;
  final ForgotPasswordUseCase _forgotPassword;
  final AuthRepository _repository;
  final PinService _pin;
  final SecureStorage _storage;

  /// Abonnement au signal d'expiration centralisé du [SessionManager].
  StreamSubscription<void>? _expirySub;

  /// Abonnement aux demandes de verrouillage (inactivité, arrière-plan).
  StreamSubscription<LockReason>? _lockSub;

  AuthNotifier({
    required LoginUseCase login,
    required RegisterUseCase register,
    required LogoutUseCase logout,
    required RefreshTokenUseCase refresh,
    required ForgotPasswordUseCase forgotPassword,
    required AuthRepository repository,
    required PinService pin,
    required SecureStorage storage,
  })  : _login = login,
        _register = register,
        _logout = logout,
        _refresh = refresh,
        _forgotPassword = forgotPassword,
        _repository = repository,
        _pin = pin,
        _storage = storage,
        super(const AuthInitial()) {
    // Le SessionManager émet quand il n'a pas pu renouveler les tokens. Le
    // coffre du code d'accès, lui, peut très bien être encore valide (tokens en
    // clair purgés à la fermeture, par exemple) : on remet sous clé au lieu de
    // le détruire. C'est le déverrouillage qui tranchera — refresh accepté, la
    // session rouvre ; refusé, l'utilisateur repart sur la connexion complète.
    _expirySub = SessionManager.instance.onSessionExpired.listen((message) {
      SessionManager.instance.stop();
      unawaited(_handleExpiry(message));
    });

    // Inactivité ou retour d'arrière-plan : on remet sous clé si un code est
    // configuré, sinon on ferme la session comme auparavant.
    _lockSub = SessionManager.instance.onLockRequested.listen((reason) {
      unawaited(_handleLockRequest(reason));
    });

    // Chaque renouvellement de tokens rechiffre le coffre, tant que la session
    // est déverrouillée (sans quoi l'appel est simplement ignoré).
    SessionManager.instance.onTokensRenewed =
        (refreshToken) => unawaited(_pin.updateRefreshToken(refreshToken));
  }

  @override
  void dispose() {
    _expirySub?.cancel();
    _lockSub?.cancel();
    SessionManager.instance.onTokensRenewed = null;
    super.dispose();
  }

  Future<void> _handleExpiry(String message) async {
    // Déjà sous clé : ne pas écraser le motif affiché à l'utilisateur.
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
    // Sans code d'accès, le comportement historique s'applique : déconnexion.
    SessionManager.instance.stop();
    await _storage.clearTokens();
    state = AuthUnauthenticated(
      reason == LockReason.inactivite
          ? 'Vous avez été déconnecté pour inactivité.'
          : null,
    );
  }

  /// Vérifié au démarrage de l'app.
  Future<void> bootstrap() async {
    // Un code d'accès configuré prime : les tokens en clair ont pu être purgés
    // à la fermeture, seul le coffre chiffré fait foi.
    if (await _pin.isConfigured()) {
      state = AuthLocked(displayName: await _pin.displayName());
      return;
    }

    final authenticated = await _repository.isAuthenticated();
    if (!authenticated) {
      state = const AuthUnauthenticated();
      return;
    }
    // Tenter un refresh pour valider la session
    final result = await _refresh.call();
    await result.fold(
      (_) async => state = const AuthUnauthenticated(),
      (_) async {
        SessionManager.instance.start();
        // Session valide, mais pas de code : le cas ne subsiste que pour les
        // appareils connectés avant que le code devienne obligatoire. On le
        // fait installer maintenant plutôt que d'ouvrir l'application.
        state = AuthPinSetup(displayName: await _displayName());
      },
    );
  }

  /// Nom à saluer sur l'écran de verrouillage, lu dans le jeton courant.
  Future<String?> _displayName() async =>
      DisplayName.resolve(accessToken: await _storage.getAccessToken());

  /// Identifiant de connexion auquel rattacher le code d'accès. Lu dans le
  /// jeton plutôt que dans la saisie de l'utilisateur : c'est la valeur
  /// normalisée par Keycloak, stable d'une connexion à l'autre.
  Future<String> _accountId() async {
    final claims = JwtClaims.parse(await _storage.getAccessToken());
    return claims.preferredUsername ?? '';
  }

  Future<void> login(String username, String password) async {
    state = const AuthLoading();
    final result = await _login.call(username, password);
    await result.fold(
      (failure) async => state = AuthError(failure.message),
      (_) async {
        // Un éventuel code existant protège un refresh token désormais périmé :
        // il sera reproposé à la volée plutôt que conservé inutilisable.
        await _pin.reset();
        SessionManager.instance.start();

        // Le code d'accès est le seul chemin de retour dans l'application : on
        // le fait choisir avant d'entrer, sans échappatoire.
        state = AuthPinSetup(displayName: await _displayName());
      },
    );
  }

  // ── Code d'accès ────────────────────────────────────────────────────────

  /// Installe le code d'accès. Retourne un message d'erreur si le code est
  /// refusé, `null` si tout s'est bien passé.
  ///
  /// [entrerDansLApplication] distingue les deux points d'appel : l'installation
  /// qui suit la connexion (l'application s'ouvre ensuite) et le changement
  /// depuis les réglages (la session est déjà ouverte, l'état ne bouge pas).
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
    if (entrerDansLApplication) {
      state = AuthAuthenticated(displayName ?? '');
    }
    return null;
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
        final refreshed = await _refresh.call().timeout(
              _delaiReouverture,
              onTimeout: () => const Left(NetworkFailure(
                'Le serveur met trop de temps à répondre. '
                'Vérifiez votre connexion, puis réessayez.',
              )),
            );

        return refreshed.fold(
          (failure) {
            if (failure is NetworkFailure) {
              // Le code était bon, mais la session n'a pas pu être rouverte :
              // on reverrouille pour ne rien laisser en clair, sans compter
              // d'échec. L'utilisateur réessaiera une fois le réseau revenu.
              _pin.lock();
              unawaited(_storage.clearTokens());
              return UnlockOffline(failure.message);
            }
            // Session révoquée côté serveur : le code ne peut plus rien rouvrir.
            unawaited(_pin.reset());
            state = const AuthUnauthenticated(
              'Votre session a expiré. Veuillez vous reconnecter.',
            );
            return const UnlockRequiresLogin();
          },
          (_) {
            SessionManager.instance.start();
            unawaited(_syncVaultWithStoredToken());
            state = AuthAuthenticated(nom ?? '');
            return const UnlockOk();
          },
        );
    }
  }

  /// Après un refresh, le token renouvelé remplace celui du coffre.
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
    unawaited(_logout.call());
    state = const AuthUnauthenticated();
  }

  /// Change le code depuis les réglages. Retourne un message d'erreur, ou
  /// `null` si le nouveau code est en place.
  Future<String?> changePin({
    required String currentCode,
    required String newCode,
  }) async {
    final invalide = PinService.validate(newCode);
    if (invalide != null) return invalide;

    final change = await _pin.changeCode(
      currentCode: currentCode,
      newCode: newCode,
    );
    return change ? null : 'Code actuel incorrect.';
  }

  /// Un code est-il configuré sur cet appareil ?
  Future<bool> isPinConfigured() => _pin.isConfigured();

  Future<void> register({
    required String username,
    required String email,
    required String password,
    String? firstName,
    String? lastName,
  }) async {
    state = const AuthLoading();
    final result = await _register.call(
      username: username,
      email: email,
      password: password,
      firstName: firstName,
      lastName: lastName,
    );
    result.fold(
      (failure) => state = AuthError(failure.message),
      (_) => state = const AuthUnauthenticated(), // redirige vers login
    );
  }

  Future<void> logout() async {
    SessionManager.instance.stop();
    // Déconnexion volontaire : le code d'accès et son coffre disparaissent avec
    // la session — la prochaine ouverture repassera par la page de connexion.
    await _pin.reset();
    // Redirection immédiate : on bascule l'état AVANT l'appel réseau de
    // révocation (qui peut être lent), puis on révoque en arrière-plan.
    state = const AuthUnauthenticated();
    unawaited(_logout.call());
  }

  Future<String?> forgotPassword(String email) async {
    final result = await _forgotPassword.call(email);
    return result.fold((f) => f.message, (_) => null);
  }
}

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    login: ref.watch(loginUseCaseProvider),
    register: ref.watch(registerUseCaseProvider),
    logout: ref.watch(logoutUseCaseProvider),
    refresh: ref.watch(refreshTokenUseCaseProvider),
    forgotPassword: ref.watch(forgotPasswordUseCaseProvider),
    repository: ref.watch(authRepositoryProvider),
    pin: ref.watch(pinServiceProvider),
    storage: ref.watch(secureStorageProvider),
  );
});

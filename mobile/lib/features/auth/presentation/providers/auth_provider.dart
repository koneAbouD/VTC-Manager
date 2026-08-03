import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:tmk_pin/tmk_pin.dart';
import 'package:tmk_push/tmk_push.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/session_manager.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../notification/data/api_push_registrar.dart';
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

/// Biométrie de l'appareil (Face ID, Touch ID, empreinte…).
final biometricServiceProvider = Provider<BiometricService>(
  (_) => BiometricService(),
);

/// Ce que l'appareil sait faire en biométrie. Calculé une fois par session
/// d'application : le matériel ne change pas, et l'enrôlement est revérifié à
/// chaque tentative par l'OS lui-même.
final biometricAvailabilityProvider = FutureProvider<BiometricAvailability>(
  (ref) => ref.watch(biometricServiceProvider).availability(),
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
  final BiometricService _biometrics;
  final SecureStorage _storage;
  final PushRegistrar _push;

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
    required BiometricService biometrics,
    required SecureStorage storage,
    required PushRegistrar push,
  })  : _login = login,
        _register = register,
        _logout = logout,
        _refresh = refresh,
        _forgotPassword = forgotPassword,
        _repository = repository,
        _pin = pin,
        _biometrics = biometrics,
        _storage = storage,
        _push = push,
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
    PushService.instance.marquerVerrouillee();
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
    // à la fermeture, seul le coffre chiffré fait foi. Sauf après une
    // déconnexion volontaire : le coffre est conservé, mais le refresh token
    // qu'il protège est révoqué — il n'y a plus de session à rouvrir.
    if (await _pin.isConfigured() && !await _storage.isLoggedOut()) {
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
        // Session valide sans code utilisable : soit l'appareil a été connecté
        // avant que le code devienne obligatoire, soit l'application a été
        // fermée pendant la reprise du code. Dans les deux cas, on règle la
        // question du code avant d'ouvrir l'application.
        final displayName = await _displayName();
        state = await _pin.isConfigured()
            ? AuthPinResume(displayName: displayName)
            : AuthPinSetup(displayName: displayName);
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
    try {
      final result = await _login.call(username, password);
      await result.fold(
        (failure) async => state = _echecConnexion(failure),
        (_) async {
          // Un code rattaché à un autre compte n'a rien à faire ici.
          await _pin.resetIfOtherAccount(await _accountId());
          SessionManager.instance.start();

          final displayName = await _displayName();
          // Le code d'accès est le seul chemin de retour dans l'application. S'il
          // existe déjà, on le redemande pour rouvrir le coffre et y ranger le
          // nouveau refresh token ; sinon on le fait choisir. Dans les deux cas,
          // pas d'entrée directe.
          state = await _pin.isConfigured()
              ? AuthPinResume(displayName: displayName)
              : AuthPinSetup(displayName: displayName);
        },
      );
    } catch (e) {
      // Rien ne doit laisser l'écran sur son indicateur d'attente. Une réponse
      // inattendue (corps illisible, coffre en erreur) échappe au découpage en
      // [Failure] et figerait le bouton pour toujours : on rend la main, comme
      // le déverrouillage relâche systématiquement le sien.
      state = AuthError(messageFromError(e), indisponible: true);
    }
  }

  /// Qualifie l'échec d'une connexion. L'écran a besoin de la distinction que
  /// fait déjà le déverrouillage : « le serveur a refusé » (la saisie est en
  /// cause) ou « le serveur n'a pas répondu » (elle ne l'est pas).
  AuthError _echecConnexion(Failure failure) => switch (failure) {
        NetworkFailure() => AuthError(failure.message, indisponible: true),

        // 503 : le backend a lui-même perdu Keycloak. Son message est rédigé
        // pour l'utilisateur, on le reprend tel quel.
        ServerFailure(statusCode: 503) =>
          AuthError(failure.message, indisponible: true),

        // Autre 5xx : le message remonté est technique (« Erreur
        // d'authentification: 400 Bad Request… », renvoyé par exemple quand le
        // compte est désactivé côté Keycloak). On n'en montre rien.
        ServerFailure(:final statusCode) when (statusCode ?? 0) >= 500 =>
          const AuthError(
            'Le serveur a rencontré un problème. Réessayez dans un instant.',
            indisponible: true,
          ),

        _ => AuthError(failure.message),
      };

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
    await _storage.setLoggedOut(false);
    if (entrerDansLApplication) {
      state = AuthAuthenticated(displayName ?? '');
      _ouvrirNotifications();
    }
    return null;
  }

  // ── Notifications push ──────────────────────────────────────────────────

  /// L'application vient de s'ouvrir : l'appareil est déclaré au backend et les
  /// liens profonds retenus pendant le verrouillage peuvent s'ouvrir.
  ///
  /// Appelé à chaque entrée dans l'application, connexion comme déverrouillage.
  /// Un déverrouillage n'est pas précédé d'une connexion — l'application relancée
  /// passe directement par le code d'accès — et sans cela l'appareil ne serait
  /// jamais déclaré. Le réenregistrement est sans effet de bord : le backend
  /// reconnaît le jeton et se contente d'en rafraîchir la date de dernière vue.
  ///
  /// L'autorisation est demandée ici plutôt qu'au lancement : présentée avant
  /// même l'écran de connexion, elle serait refusée par réflexe. Android ne
  /// montre sa boîte de dialogue qu'une fois, les appels suivants se contentant
  /// de rendre la réponse déjà donnée.
  ///
  /// Volontairement non attendu : l'utilisateur n'a pas à patienter derrière un
  /// appel réseau pour voir son accueil.
  void _ouvrirNotifications() {
    PushService.instance.marquerPrete();
    unawaited(_alignerSurLeReglage());
  }

  /// Met l'appareil en conformité avec l'interrupteur des réglages.
  ///
  /// La coupure se rejoue à chaque ouverture, et pas seulement au moment où
  /// l'utilisateur pousse l'interrupteur : c'est ce qui rattrape un retrait que
  /// le réseau avait empêché, sans quoi l'appareil continuerait de sonner alors
  /// que le réglage dit le contraire.
  Future<void> _alignerSurLeReglage() async {
    if (await _storage.notificationsCoupees()) {
      await PushService.instance.couperReception(_push);
      return;
    }
    await PushService.instance.demanderPermission();
    await PushService.instance.attacherSession(_push);
  }

  /// Remet la session sous clé : les tokens en clair sont effacés, seul le
  /// coffre chiffré subsiste.
  Future<void> lock({String? message}) async {
    SessionManager.instance.stop();
    _pin.lock();
    // Une notification touchée pendant le verrouillage attendra le code : la
    // page visée n'a pas à s'afficher derrière l'écran de saisie.
    PushService.instance.marquerVerrouillee();
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
    return _traiterDeverrouillage(await _pin.unlock(code), nom);
  }

  /// Déverrouille par la biométrie de l'appareil, quand l'option est active.
  ///
  /// Un refus de l'OS ne coûte aucun des essais du code : c'est l'OS qui
  /// compte les siens, et il finit par bloquer la biométrie de lui-même. La
  /// temporisation du code, elle, reste opposable — sans quoi la biométrie
  /// offrirait un contournement.
  ///
  /// [onAccepted] est appelé dès que l'OS a reconnu l'utilisateur, avant la
  /// réouverture de session. Il marque la frontière entre l'invite système —
  /// pendant laquelle l'écran ne doit rien afficher, la fenêtre de l'OS étant
  /// déjà par-dessus — et le travail qui suit, lui bien réel.
  Future<UnlockOutcome> unlockWithBiometrics({void Function()? onAccepted}) async {
    final nom = state is AuthLocked ? (state as AuthLocked).displayName : null;

    // Vérifié avant l'invite : inutile de demander un doigt pour refuser
    // ensuite.
    final throttle = await _pin.throttleRemaining();
    if (throttle != null) return UnlockWait(throttle);

    final dispo = await _biometrics.availability();
    if (!dispo.disponible) {
      // Plus rien d'enrôlé (empreinte supprimée depuis l'activation) : on
      // abandonne l'option, le pavé reprend la main.
      await _pin.disableBiometrics();
      return UnlockBiometricsFailed(dispo.raison);
    }

    final autorisation = await _biometrics.authenticate(
      raison: 'Confirmez votre identité pour rouvrir l\'application.',
    );

    switch (autorisation) {
      case BiometricDismissed():
        return const UnlockBiometricsFailed();

      case BiometricUnavailable(:final message, :final definitif):
        if (definitif) await _pin.disableBiometrics();
        return UnlockBiometricsFailed(message);

      case BiometricAccepted():
        onAccepted?.call();
        final result = await _pin.unlockWithBiometrics();
        // `null` : la clé rangée n'ouvre plus le coffre, le service vient de
        // l'abandonner. Le code reste le chemin sûr.
        if (result == null) {
          return const UnlockBiometricsFailed(
            'Le déverrouillage biométrique a été réinitialisé. '
            'Saisissez votre code TMK.',
          );
        }
        return _traiterDeverrouillage(result, nom);
    }
  }

  /// Suite commune aux deux chemins de déverrouillage : le coffre a rendu (ou
  /// non) le refresh token, il reste à rouvrir la session côté serveur.
  Future<UnlockOutcome> _traiterDeverrouillage(
    UnlockResult result,
    String? nom,
  ) async {
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
            _ouvrirNotifications();
            return const UnlockOk();
          },
        );
    }
  }

  // ── Déverrouillage biométrique ──────────────────────────────────────────

  /// Ce que l'appareil sait faire (matériel + enrôlement).
  Future<BiometricAvailability> biometricAvailability() =>
      _biometrics.availability();

  /// L'option est-elle active sur cet appareil ?
  Future<bool> isBiometricsEnabled() => _pin.isBiometricsEnabled();

  /// Faut-il proposer l'activation ? Vrai une seule fois, sur un appareil
  /// compatible où l'option n'est pas déjà en place.
  Future<BiometricAvailability?> biometricsToPropose() async {
    if (await _pin.hasProposedBiometrics()) return null;
    if (await _pin.isBiometricsEnabled()) return null;
    if (!_pin.isUnlocked) return null;

    final dispo = await _biometrics.availability();
    return dispo.disponible ? dispo : null;
  }

  /// Mémorise que la proposition a été faite, acceptée ou non.
  Future<void> markBiometricsProposed() => _pin.markBiometricsProposed();

  /// Active l'option après avoir fait valider la biométrie par l'OS — sans
  /// cette validation, on rangerait la clé pour quelqu'un qui ne saura pas
  /// s'en servir. Retourne un message d'erreur, ou `null` si c'est en place.
  Future<String?> enableBiometrics() async {
    final dispo = await _biometrics.availability();
    if (!dispo.disponible) {
      return dispo.raison ??
          'Le déverrouillage biométrique n\'est pas disponible sur cet '
              'appareil.';
    }

    final autorisation = await _biometrics.authenticate(
      raison: 'Confirmez votre identité pour activer '
          '${dispo.libelleAvecArticle}.',
    );

    switch (autorisation) {
      case BiometricDismissed():
        return 'Activation annulée.';
      case BiometricUnavailable(:final message):
        return message;
      case BiometricAccepted():
        // Échoue si la session s'est reverrouillée entre-temps : la clé du
        // coffre n'est plus en mémoire.
        final ok = await _pin.enableBiometrics();
        return ok
            ? null
            : 'Session verrouillée. Saisissez votre code TMK, puis réessayez.';
    }
  }

  /// Désactive l'option : la clé rangée est effacée.
  Future<void> disableBiometrics() => _pin.disableBiometrics();

  /// Reprise du code existant après une reconnexion ([AuthPinResume]).
  ///
  /// La session est déjà ouverte : la saisie ne sert qu'à re-dériver la clé du
  /// coffre, dont l'ancien refresh token — révoqué par la déconnexion — est
  /// aussitôt remplacé par le neuf. Aucun appel réseau, donc pas de cas
  /// « hors ligne » ici.
  Future<UnlockOutcome> resumePin(String code) async {
    final nom =
        state is AuthPinResume ? (state as AuthPinResume).displayName : null;
    final result = await _pin.unlock(code);

    switch (result) {
      case UnlockFailure(:final remainingAttempts):
        return UnlockWrong(remainingAttempts);

      case UnlockThrottled(:final remaining):
        return UnlockWait(remaining);

      case UnlockExhausted():
        // Le coffre est perdu, mais la session vient d'être ouverte : on
        // enchaîne sur le choix d'un nouveau code plutôt que de renvoyer à la
        // page de connexion.
        state = AuthPinSetup(displayName: nom);
        return const UnlockRequiresLogin();

      case UnlockSuccess():
        // Le coffre porte de nouveau un refresh token vivant : la session
        // redevient simplement verrouillable.
        await _syncVaultWithStoredToken();
        await _storage.setLoggedOut(false);
        state = AuthAuthenticated(nom ?? '');
        _ouvrirNotifications();
        return const UnlockOk();
    }
  }

  /// « Code TMK oublié ? » depuis l'écran de reprise : seul le coffre est
  /// abandonné. La session restant ouverte, on passe directement au choix d'un
  /// nouveau code, sans redemander les identifiants.
  Future<void> restartPinSetup() async {
    final nom =
        state is AuthPinResume ? (state as AuthPinResume).displayName : null;
    await _pin.reset();
    state = AuthPinSetup(displayName: nom);
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
    // Avant la purge des jetons : ensuite, la requête de retrait partirait sans
    // en-tête d'autorisation et serait rejetée.
    await PushService.instance.detacherSession();
    await _storage.clearTokens();
    await _storage.setLoggedOut(true);
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
    // Le code d'accès survit à la déconnexion : la prochaine connexion le
    // redemandera ([AuthPinResume]) au lieu d'en faire choisir un nouveau. Seul
    // « Code TMK oublié ? » efface le coffre (voir [forgetPin]).
    _pin.lock();
    await _storage.setLoggedOut(true);
    // Redirection immédiate : on bascule l'état AVANT l'appel réseau de
    // révocation (qui peut être lent), puis on révoque en arrière-plan.
    state = const AuthUnauthenticated();
    // Retrait de l'appareil puis révocation, dans cet ordre : le retrait a
    // besoin d'un jeton d'accès encore valide. Enchaînés plutôt qu'attendus,
    // pour ne pas retarder le retour à l'écran de connexion.
    unawaited(
      PushService.instance.detacherSession().then((_) => _logout.call()),
    );
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
    biometrics: ref.watch(biometricServiceProvider),
    storage: ref.watch(secureStorageProvider),
    push: ApiPushRegistrar(ref.watch(apiClientProvider)),
  );
});

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

/// Biométrie de l'appareil (Face ID, Touch ID, empreinte…).
final biometricServiceProvider = Provider<BiometricService>(
  (_) => BiometricService(),
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
  late final BiometricService _biometrics;

  StreamSubscription<LockReason>? _lockSub;

  /// Abonnement au signal d'expiration centralisé du [SessionManager].
  StreamSubscription<String>? _expirySub;

  @override
  AuthState build() {
    _storage = ref.watch(secureStorageProvider);
    _pin = ref.watch(pinServiceProvider);
    _biometrics = ref.watch(biometricServiceProvider);

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
    // à la fermeture, seul le coffre chiffré fait foi. Sauf après une
    // déconnexion volontaire : le coffre est conservé, mais le refresh token
    // qu'il protège est révoqué — il n'y a plus de session à rouvrir.
    if (await _pin.isConfigured() && !await _storage.isLoggedOut()) {
      state = AuthLocked(displayName: await _pin.displayName());
      return;
    }
    if (await _storage.hasAccessToken()) {
      SessionManager.instance.start();
      // Session ouverte sans code utilisable : soit l'appareil a été connecté
      // avant que le code devienne obligatoire, soit l'application a été fermée
      // pendant la reprise du code.
      final displayName = await _displayName();
      state = await _pin.isConfigured()
          ? AuthPinResume(displayName: displayName)
          : AuthPinSetup(displayName: displayName);
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
    // Un code rattaché à un autre compte n'a rien à faire ici.
    await _pin.resetIfOtherAccount(await _accountId());
    SessionManager.instance.start();

    final displayName = await _displayName();
    // Le code d'accès est le seul chemin de retour dans l'application. S'il
    // existe déjà, on le redemande pour rouvrir le coffre et y ranger le
    // nouveau refresh token ; sinon on le fait choisir.
    state = await _pin.isConfigured()
        ? AuthPinResume(displayName: displayName)
        : AuthPinSetup(displayName: displayName);
  }

  Future<void> logout() async {
    SessionManager.instance.stop();
    // Le code d'accès survit à la déconnexion : la prochaine connexion le
    // redemandera ([AuthPinResume]) au lieu d'en faire choisir un nouveau. Seul
    // « Code TMK oublié ? » efface le coffre (voir [forgetPin]).
    _pin.lock();
    await _storage.clearTokens();
    await _storage.setLoggedOut(true);
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
    await _storage.setLoggedOut(false);
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
    return _traiterDeverrouillage(await _pin.unlock(code), nom);
  }

  /// Déverrouille par la biométrie de l'appareil, quand l'option est active.
  ///
  /// Un refus de l'OS ne coûte aucun des essais du code : c'est l'OS qui compte
  /// les siens, et il finit par bloquer la biométrie de lui-même. La
  /// temporisation du code, elle, reste opposable — sans quoi la biométrie
  /// offrirait un contournement.
  Future<UnlockOutcome> unlockWithBiometrics() async {
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
      titre: 'Accès à votre espace',
      raison: 'Confirmez votre identité pour rouvrir l\'application.',
    );

    switch (autorisation) {
      case BiometricDismissed():
        return const UnlockBiometricsFailed();

      case BiometricUnavailable(:final message, :final definitif):
        if (definitif) await _pin.disableBiometrics();
        return UnlockBiometricsFailed(message);

      case BiometricAccepted():
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
      titre: 'Activer le déverrouillage',
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
  /// coffre, dont l'ancien refresh token est aussitôt remplacé par le neuf.
  /// Aucun appel réseau, donc pas de cas « hors ligne » ici.
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
        state = AuthAuthenticated(nom);
        return const UnlockOk();
    }
  }

  /// « Code TMK oublié ? » depuis l'écran de reprise : seul le coffre est
  /// abandonné. La session restant ouverte, on passe directement au choix d'un
  /// nouveau code, sans redemander de code OTP.
  Future<void> restartPinSetup() async {
    final nom =
        state is AuthPinResume ? (state as AuthPinResume).displayName : null;
    await _pin.reset();
    state = AuthPinSetup(displayName: nom);
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
    await _storage.setLoggedOut(true);
    state = const AuthUnauthenticated();
  }
}

import 'dart:typed_data';

import 'pin_cipher.dart';
import 'pin_store.dart';

/// Issue d'une tentative de déverrouillage.
sealed class UnlockResult {
  const UnlockResult();
}

/// Code correct : le refresh token a été déchiffré et la session peut reprendre.
class UnlockSuccess extends UnlockResult {
  final String refreshToken;
  const UnlockSuccess(this.refreshToken);
}

/// Code erroné, mais il reste des essais.
class UnlockFailure extends UnlockResult {
  final int remainingAttempts;

  /// Temporisation imposée avant le prochain essai (`null` si aucune).
  final Duration? throttle;

  const UnlockFailure({required this.remainingAttempts, this.throttle});
}

/// Essai refusé sans être compté : la temporisation court encore.
class UnlockThrottled extends UnlockResult {
  final Duration remaining;
  const UnlockThrottled(this.remaining);
}

/// Essais épuisés : le coffre a été purgé, il faut se reconnecter entièrement.
class UnlockExhausted extends UnlockResult {
  const UnlockExhausted();
}

/// Verrou d'application par code d'accès.
///
/// Le code ne remplace pas l'authentification : il rouvre une session déjà
/// obtenue, dont le refresh token n'existe sur l'appareil que sous forme
/// chiffrée. Voir [PinCipher] pour le modèle cryptographique.
///
/// La clé dérivée reste en mémoire tant que la session est déverrouillée, ce
/// qui permet de rechiffrer les tokens renouvelés sans redemander le code.
/// [lock] l'oublie.
class PinService {
  /// Nombre de chiffres du code (5, comme la maquette).
  static const codeLength = 5;

  /// Au-delà, le coffre est purgé et l'utilisateur repart du login.
  static const maxAttempts = 5;

  /// Temporisation appliquée après le n-ième échec (index = nombre d'échecs).
  static const _throttles = <int, Duration>{
    3: Duration(seconds: 5),
    4: Duration(seconds: 15),
  };

  final PinStore _store;
  final int _iterations;

  /// Clé AES dérivée, conservée le temps de la session déverrouillée.
  Uint8List? _key;

  PinService(this._store, {int iterations = PinCipher.defaultIterations})
      : _iterations = iterations;

  /// Vrai si un code est configuré sur cet appareil.
  Future<bool> isConfigured() => _store.hasVault();

  /// Vrai si la session courante a été déverrouillée (clé en mémoire).
  bool get isUnlocked => _key != null;

  /// Prénom à afficher sur l'écran de verrouillage (`null` si inconnu).
  Future<String?> displayName() => _store.readDisplayName();

  /// Compte auquel le code est rattaché (identifiant de connexion).
  Future<String?> account() => _store.readAccount();

  Future<void> saveDisplayName(String? name) => _store.writeDisplayName(name);

  // ── Configuration ────────────────────────────────────────────────────────

  /// Refuse les codes devinables en quelques essais.
  /// Retourne le message d'erreur à afficher, ou `null` si le code convient.
  static String? validate(String code) {
    if (code.length != codeLength) {
      return 'Le code doit comporter $codeLength chiffres.';
    }
    if (!RegExp(r'^\d+$').hasMatch(code)) {
      return 'Le code ne doit contenir que des chiffres.';
    }
    final digits = code.codeUnits;
    if (digits.every((d) => d == digits.first)) {
      return 'Évitez un code composé du même chiffre.';
    }
    final ascending = List.generate(digits.length - 1, (i) => i)
        .every((i) => digits[i + 1] == digits[i] + 1);
    final descending = List.generate(digits.length - 1, (i) => i)
        .every((i) => digits[i + 1] == digits[i] - 1);
    if (ascending || descending) {
      return 'Évitez une suite de chiffres.';
    }
    return null;
  }

  /// Installe le code d'accès et met le refresh token à l'abri.
  ///
  /// [account] rattache le code à un compte : une connexion sous un autre
  /// identifiant devra réinitialiser le code (voir [resetIfOtherAccount]).
  Future<void> configure({
    required String code,
    required String refreshToken,
    required String account,
    String? displayName,
  }) async {
    final (vault, key) = await PinCipher.seal(
      code: code,
      secret: refreshToken,
      iterations: _iterations,
    );
    await _store.writeVault(vault);
    await _store.writeAccount(account);
    await _store.writeDisplayName(displayName);
    await _store.writeAttempts(0);
    await _store.writeLockedUntil(null);
    // Sel neuf, donc clé neuve : celle rangée pour la biométrie n'ouvrirait
    // plus rien. [changeCode] la réinstalle quand l'option était active.
    await _store.writeBiometricKey(null);
    _key = key;
  }

  /// Change le code sans perdre la session : vérifie l'ancien, rechiffre avec
  /// le nouveau. Retourne `false` si l'ancien code est faux.
  Future<bool> changeCode({
    required String currentCode,
    required String newCode,
  }) async {
    final result = await unlock(currentCode);
    if (result is! UnlockSuccess) return false;

    final biometrieActive = await isBiometricsEnabled();
    final account = await _store.readAccount() ?? '';
    await configure(
      code: newCode,
      refreshToken: result.refreshToken,
      account: account,
      displayName: await _store.readDisplayName(),
    );
    // Changer de code ne doit pas faire perdre silencieusement la biométrie :
    // on range la nouvelle clé à la place de l'ancienne.
    if (biometrieActive) await enableBiometrics();
    return true;
  }

  // ── Déverrouillage ───────────────────────────────────────────────────────

  /// Temporisation restante avant d'autoriser un nouvel essai.
  Future<Duration?> throttleRemaining() async {
    final until = await _store.readLockedUntil();
    if (until == null) return null;
    final remaining = until.difference(DateTime.now());
    return remaining > Duration.zero ? remaining : null;
  }

  Future<UnlockResult> unlock(String code) async {
    final throttle = await throttleRemaining();
    if (throttle != null) return UnlockThrottled(throttle);

    final vault = await _store.readVault();
    if (vault == null) return const UnlockExhausted();

    final key = await PinCipher.deriveKey(
      code: code,
      salt: vault.salt,
      iterations: vault.iterations,
    );
    final secret = await PinCipher.open(vault: vault, key: key);

    if (secret != null) {
      await _store.writeAttempts(0);
      await _store.writeLockedUntil(null);
      _key = key;
      return UnlockSuccess(secret);
    }

    final attempts = await _store.readAttempts() + 1;
    if (attempts >= maxAttempts) {
      // Purge : sans le refresh token, l'appareil ne conserve plus rien
      // d'exploitable. L'utilisateur repasse par le login complet.
      await reset();
      return const UnlockExhausted();
    }

    await _store.writeAttempts(attempts);
    final penalty = _throttles[attempts];
    if (penalty != null) {
      await _store.writeLockedUntil(DateTime.now().add(penalty));
    }
    return UnlockFailure(
      remainingAttempts: maxAttempts - attempts,
      throttle: penalty,
    );
  }

  // ── Déverrouillage biométrique ───────────────────────────────────────────

  /// L'option est-elle active sur cet appareil ?
  Future<bool> isBiometricsEnabled() => _store.hasBiometricKey();

  /// Active le déverrouillage biométrique en rangeant la clé du coffre.
  ///
  /// N'est possible que sur une session **déverrouillée** : c'est le
  /// déverrouillage par code qui a produit la clé. Retourne `false` sinon.
  ///
  /// Ne fait rien d'autre : la validation biométrique elle-même appartient à
  /// l'appelant (voir `BiometricService`), qui doit l'exiger avant d'appeler.
  Future<bool> enableBiometrics() async {
    final key = _key;
    if (key == null) return false;
    await _store.writeBiometricKey(key);
    return true;
  }

  /// Désactive l'option : la clé rangée est effacée, le code redevient le seul
  /// chemin. Le coffre, lui, n'est pas touché.
  Future<void> disableBiometrics() => _store.writeBiometricKey(null);

  /// Ouvre le coffre avec la clé rangée, **après** que l'OS a validé la
  /// biométrie.
  ///
  /// Retourne `null` quand la biométrie n'est pas exploitable (option
  /// désactivée, ou clé qui n'ouvre plus le coffre) : à l'appelant de retomber
  /// sur la saisie du code. La temporisation des échecs de code reste opposable,
  /// pour que la biométrie ne serve pas à la contourner.
  Future<UnlockResult?> unlockWithBiometrics() async {
    final throttle = await throttleRemaining();
    if (throttle != null) return UnlockThrottled(throttle);

    final key = await _store.readBiometricKey();
    final vault = await _store.readVault();
    if (key == null || vault == null) return null;

    final secret = await PinCipher.open(vault: vault, key: key);
    if (secret == null) {
      // Clé désynchronisée du coffre (cas théorique : coffre réécrit sans
      // passer par [configure]). On abandonne l'option plutôt que de proposer
      // indéfiniment une biométrie qui n'ouvre rien.
      await disableBiometrics();
      return null;
    }

    await _store.writeAttempts(0);
    await _store.writeLockedUntil(null);
    _key = key;
    return UnlockSuccess(secret);
  }

  /// L'activation a-t-elle déjà été proposée à l'utilisateur ?
  Future<bool> hasProposedBiometrics() => _store.readBiometricAsked();

  /// Mémorise que la proposition a été faite — acceptée ou non, on ne la
  /// représente plus (l'option reste dans les réglages).
  Future<void> markBiometricsProposed() => _store.writeBiometricAsked(true);

  // ── Cycle de vie de la session ───────────────────────────────────────────

  /// Rechiffre le refresh token renouvelé, en réutilisant la clé en mémoire.
  ///
  /// Retourne `false` si la session est verrouillée (rien à faire : le coffre
  /// conserve alors le token précédent, qui reste valide côté Keycloak
  /// puisque la rotation stricte est désactivée).
  Future<bool> updateRefreshToken(String refreshToken) async {
    final key = _key;
    final vault = await _store.readVault();
    if (key == null || vault == null) return false;

    await _store.writeVault(await PinCipher.sealWithKey(
      key: key,
      secret: refreshToken,
      salt: vault.salt,
      iterations: vault.iterations,
    ));
    return true;
  }

  /// Oublie la clé : le code redeviendra nécessaire. Le coffre est conservé,
  /// ainsi que la clé rangée pour la biométrie — c'est précisément ce qui
  /// permet de rouvrir d'un doigt plutôt qu'en cinq chiffres.
  void lock() => _key = null;

  /// Supprime le code et le refresh token conservé (déconnexion, échecs
  /// épuisés, ou désactivation depuis les réglages).
  Future<void> reset() async {
    _key = null;
    await _store.clear();
  }

  /// Réinitialise le code si la connexion se fait sous un autre compte que
  /// celui auquel il était rattaché. Retourne `true` si une purge a eu lieu.
  Future<bool> resetIfOtherAccount(String account) async {
    if (!await isConfigured()) return false;
    if (await _store.readAccount() == account) return false;
    await reset();
    return true;
  }
}

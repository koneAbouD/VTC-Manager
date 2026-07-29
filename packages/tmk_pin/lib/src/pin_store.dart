import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'pin_cipher.dart';

/// Stockage clé/valeur minimal, pour pouvoir tester [PinStore] sans plateforme.
abstract interface class PinKeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// Implémentation réelle : Keychain (iOS) / Keystore (Android).
class SecureKeyValueStore implements PinKeyValueStore {
  final FlutterSecureStorage _storage;

  const SecureKeyValueStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Implémentation en mémoire, réservée aux tests.
class InMemoryKeyValueStore implements PinKeyValueStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

/// Persistance du code d'accès : coffre chiffré, compteur de tentatives et
/// éléments affichés avant déverrouillage (nom, identifiant du compte).
///
/// Le nom affiché et l'identifiant sont volontairement **en clair** : l'écran
/// de verrouillage doit saluer l'utilisateur avant toute saisie, donc avant de
/// disposer de la moindre clé.
class PinStore {
  static const _kSalt = 'pin_salt';
  static const _kNonce = 'pin_nonce';
  static const _kCipher = 'pin_cipher';
  static const _kMac = 'pin_mac';
  static const _kIterations = 'pin_iterations';
  static const _kAttempts = 'pin_attempts';
  static const _kLockedUntil = 'pin_locked_until'; // epoch ms
  static const _kAccount = 'pin_account';
  static const _kDisplayName = 'pin_display_name';
  static const _kBiometricKey = 'pin_biometric_key';
  static const _kBiometricAsked = 'pin_biometric_asked';

  final PinKeyValueStore _store;

  const PinStore(this._store);

  // ── Coffre ───────────────────────────────────────────────────────────────

  Future<PinVault?> readVault() async {
    final salt = await _store.read(_kSalt);
    final nonce = await _store.read(_kNonce);
    final cipher = await _store.read(_kCipher);
    final mac = await _store.read(_kMac);
    if (salt == null || nonce == null || cipher == null || mac == null) {
      return null;
    }
    final iterations =
        int.tryParse(await _store.read(_kIterations) ?? '') ??
            PinCipher.defaultIterations;
    return PinVault(
      salt: base64Decode(salt),
      nonce: base64Decode(nonce),
      cipherText: base64Decode(cipher),
      mac: base64Decode(mac),
      iterations: iterations,
    );
  }

  Future<void> writeVault(PinVault vault) async {
    await _store.write(_kSalt, base64Encode(vault.salt));
    await _store.write(_kNonce, base64Encode(vault.nonce));
    await _store.write(_kCipher, base64Encode(vault.cipherText));
    await _store.write(_kMac, base64Encode(vault.mac));
    await _store.write(_kIterations, vault.iterations.toString());
  }

  Future<bool> hasVault() async => (await _store.read(_kCipher)) != null;

  // ── Tentatives et temporisation ──────────────────────────────────────────

  Future<int> readAttempts() async =>
      int.tryParse(await _store.read(_kAttempts) ?? '') ?? 0;

  Future<void> writeAttempts(int attempts) =>
      _store.write(_kAttempts, attempts.toString());

  /// Persisté (et non gardé en mémoire) pour qu'un redémarrage de l'app ne
  /// remette pas le compteur d'échecs à zéro.
  Future<DateTime?> readLockedUntil() async {
    final ms = int.tryParse(await _store.read(_kLockedUntil) ?? '');
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> writeLockedUntil(DateTime? until) async {
    if (until == null) {
      await _store.delete(_kLockedUntil);
    } else {
      await _store.write(
          _kLockedUntil, until.millisecondsSinceEpoch.toString());
    }
  }

  // ── Identité affichée ────────────────────────────────────────────────────

  Future<String?> readAccount() => _store.read(_kAccount);

  Future<void> writeAccount(String account) => _store.write(_kAccount, account);

  Future<String?> readDisplayName() => _store.read(_kDisplayName);

  Future<void> writeDisplayName(String? name) async {
    if (name == null || name.isEmpty) {
      await _store.delete(_kDisplayName);
    } else {
      await _store.write(_kDisplayName, name);
    }
  }

  // ── Déverrouillage biométrique ───────────────────────────────────────────

  /// Clé du coffre rangée pour le déverrouillage biométrique, ou `null` si
  /// l'option est désactivée.
  ///
  /// Cette clé ouvre le coffre **sans le code** : c'est tout l'intérêt de
  /// l'option, et aussi sa limite. Elle repose donc entièrement sur le magasin
  /// sous-jacent (Keychain iOS / Keystore Android) et sur le fait que le
  /// service appelant n'y touche qu'après une validation biométrique de l'OS.
  /// On range la clé dérivée plutôt que le code lui-même : le code de
  /// l'utilisateur — qu'il réutilise peut-être ailleurs — ne se retrouve jamais
  /// écrit sur l'appareil, et le déverrouillage évite le coût du PBKDF2.
  Future<Uint8List?> readBiometricKey() async {
    final value = await _store.read(_kBiometricKey);
    return value == null ? null : base64Decode(value);
  }

  Future<void> writeBiometricKey(Uint8List? key) async {
    if (key == null) {
      await _store.delete(_kBiometricKey);
    } else {
      await _store.write(_kBiometricKey, base64Encode(key));
    }
  }

  Future<bool> hasBiometricKey() async =>
      (await _store.read(_kBiometricKey)) != null;

  /// L'activation a-t-elle déjà été proposée ? Un refus vaut pour toujours :
  /// l'option reste accessible dans les réglages, mais on ne la redemande plus.
  Future<bool> readBiometricAsked() async =>
      (await _store.read(_kBiometricAsked)) == '1';

  Future<void> writeBiometricAsked(bool asked) async {
    if (asked) {
      await _store.write(_kBiometricAsked, '1');
    } else {
      await _store.delete(_kBiometricAsked);
    }
  }

  // ── Purge ────────────────────────────────────────────────────────────────

  /// Efface tout : plus de code configuré, plus de refresh token conservé.
  Future<void> clear() async {
    for (final key in const [
      _kSalt,
      _kNonce,
      _kCipher,
      _kMac,
      _kIterations,
      _kAttempts,
      _kLockedUntil,
      _kAccount,
      _kDisplayName,
      _kBiometricKey,
      _kBiometricAsked,
    ]) {
      await _store.delete(key);
    }
  }
}

/// Conversion pratique pour les appelants qui manipulent des octets bruts.
extension Uint8ListBase64 on Uint8List {
  String toBase64() => base64Encode(this);
}

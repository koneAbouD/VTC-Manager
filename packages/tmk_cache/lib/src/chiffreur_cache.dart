import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Chiffrement AES-GCM des réponses mises en cache.
///
/// Les réponses portent des montants, des noms et des numéros de téléphone :
/// elles ne touchent jamais le disque en clair. La clé, tirée au hasard au
/// premier usage, vit dans le stockage sécurisé (Keystore / Keychain) ; elle
/// n'a rien à voir avec le code d'accès, qui ne doit pas être redemandé pour
/// lire un écran déjà vu.
///
/// La clé de la ligne sert de données associées : un contenu recopié sous une
/// autre clé ne se déchiffre pas.
class ChiffreurCache {
  static const _kCle = 'tmk_cache_cle_v1';
  static const _longueurNonce = 12;

  final Future<SecretKey> Function() _chargerCle;
  Future<SecretKey>? _cle;

  static final _aes = AesGcm.with256bits();
  static final _sha256 = Sha256();

  ChiffreurCache._(this._chargerCle);

  /// Clé persistée dans le stockage sécurisé de l'appareil.
  factory ChiffreurCache.securise([FlutterSecureStorage? stockage]) {
    final s = stockage ?? const FlutterSecureStorage();
    return ChiffreurCache._(() async {
      final existante = await s.read(key: _kCle);
      if (existante != null) return SecretKey(base64Decode(existante));
      final cle = await _aes.newSecretKey();
      await s.write(key: _kCle, value: base64Encode(await cle.extractBytes()));
      return cle;
    });
  }

  /// Clé fournie : tests.
  factory ChiffreurCache.avecCle(List<int> octets) =>
      ChiffreurCache._(() async => SecretKey(octets));

  /// En cas d'échec (stockage sécurisé indisponible), on réessaiera à l'appel
  /// suivant plutôt que de garder une erreur en mémoire.
  Future<SecretKey> _cleCourante() {
    final future = _cle ??= _chargerCle();
    return future.catchError((Object e) {
      _cle = null;
      throw e;
    });
  }

  /// Identifiant opaque d'une URL : l'URL elle-même (filtres de recherche,
  /// identifiants) ne figure pas dans la base.
  Future<String> hacher(String valeur) async {
    final hash = await _sha256.hash(utf8.encode(valeur));
    return base64UrlEncode(hash.bytes);
  }

  /// nonce (12 octets) ‖ texte chiffré ‖ MAC (16 octets).
  Future<Uint8List> chiffrer(List<int> clair, {required String cle}) async {
    final boite = await _aes.encrypt(
      clair,
      secretKey: await _cleCourante(),
      nonce: _nonce(),
      aad: utf8.encode(cle),
    );
    return boite.concatenation();
  }

  /// Lève une exception si le contenu a été altéré ou chiffré sous une autre
  /// clé (cache d'une installation précédente).
  Future<Uint8List> dechiffrer(Uint8List chiffre, {required String cle}) async {
    final boite = SecretBox.fromConcatenation(
      chiffre,
      nonceLength: _longueurNonce,
      macLength: _aes.macAlgorithm.macLength,
    );
    final clair = await _aes.decrypt(
      boite,
      secretKey: await _cleCourante(),
      aad: utf8.encode(cle),
    );
    return Uint8List.fromList(clair);
  }

  static final _hasard = Random.secure();

  static List<int> _nonce() =>
      List<int>.generate(_longueurNonce, (_) => _hasard.nextInt(256));
}

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '_derive_io.dart' if (dart.library.js_interop) '_derive_web.dart';

/// Coffre chiffré : le refresh token protégé par la clé dérivée du code
/// d'accès. Le sel reste en clair (il n'est pas secret), le contenu ne peut
/// être lu — ni même modifié sans être détecté — sans le bon code.
class PinVault {
  /// Sel de dérivation (16 octets aléatoires, propres à cet appareil).
  final Uint8List salt;

  /// Nonce AES-GCM (12 octets), renouvelé à **chaque** chiffrement.
  final Uint8List nonce;

  /// Texte chiffré suivi du tag d'authentification GCM.
  final Uint8List cipherText;
  final Uint8List mac;

  /// Nombre d'itérations PBKDF2 utilisé — mémorisé pour pouvoir durcir le
  /// paramètre plus tard sans invalider les coffres déjà en place.
  final int iterations;

  const PinVault({
    required this.salt,
    required this.nonce,
    required this.cipherText,
    required this.mac,
    required this.iterations,
  });
}

/// Dérivation de clé et chiffrement authentifié du refresh token.
///
/// Le code d'accès à 5 chiffres n'offre que 100 000 combinaisons : il ne
/// protège rien à lui seul. Sa force vient d'ici — il ne sert pas de mot de
/// passe comparé à un hash, mais de **matériau de dérivation** de la clé qui
/// déchiffre le refresh token. Un code erroné ne produit pas « faux » : il
/// produit une clé qui ne déchiffre rien, et AES-GCM le détecte par son MAC.
class PinCipher {
  const PinCipher._();

  /// Compromis sécurité / réactivité sur mobile. Mesuré à ce niveau : 320 ms
  /// sur un Mac ARM, soit de l'ordre de la seconde sur un téléphone d'entrée
  /// de gamme — perceptible mais acceptable au déverrouillage, et assez coûteux
  /// pour qu'un balayage hors ligne des 100 000 codes possibles se compte en
  /// heures, là où un simple hash SHA-256 les épuiserait en quelques secondes.
  ///
  /// La dérivation s'exécute dans un isolate ([deriveKey]) : l'interface reste
  /// fluide pendant le calcul.
  static const defaultIterations = 50000;

  static const _saltLength = 16;
  static const _nonceLength = 12;

  static final Random _random = Random.secure();

  static Uint8List _randomBytes(int length) {
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = _random.nextInt(256);
    }
    return bytes;
  }

  /// Dérive une clé AES-256 depuis le [code], sans bloquer l'interface.
  ///
  /// La stratégie dépend de la plateforme (isolate sur mobile et bureau, Web
  /// Crypto dans le navigateur) : voir `_derive_io.dart` / `_derive_web.dart`.
  static Future<Uint8List> deriveKey({
    required String code,
    required Uint8List salt,
    required int iterations,
  }) {
    return deriveOffThread(code: code, salt: salt, iterations: iterations);
  }

  /// Crée un coffre pour [secret] à partir d'un code d'accès. Génère un sel
  /// neuf : à n'utiliser qu'à la configuration (ou au changement) du code.
  static Future<(PinVault, Uint8List)> seal({
    required String code,
    required String secret,
    int iterations = defaultIterations,
  }) async {
    final salt = _randomBytes(_saltLength);
    final key = await deriveKey(code: code, salt: salt, iterations: iterations);
    final vault = await sealWithKey(
      key: key,
      secret: secret,
      salt: salt,
      iterations: iterations,
    );
    return (vault, key);
  }

  /// Rechiffre [secret] avec une clé **déjà dérivée**, en conservant le sel.
  ///
  /// Utilisé après chaque renouvellement de token : la session est déverrouillée,
  /// la clé est en mémoire, il n'y a donc pas à redemander le code ni à repayer
  /// le coût de la dérivation.
  static Future<PinVault> sealWithKey({
    required Uint8List key,
    required String secret,
    required Uint8List salt,
    required int iterations,
  }) async {
    final nonce = _randomBytes(_nonceLength);
    final box = await AesGcm.with256bits().encrypt(
      utf8.encode(secret),
      secretKey: SecretKey(key),
      nonce: nonce,
    );
    return PinVault(
      salt: salt,
      nonce: nonce,
      cipherText: Uint8List.fromList(box.cipherText),
      mac: Uint8List.fromList(box.mac.bytes),
      iterations: iterations,
    );
  }

  /// Ouvre le coffre avec une clé dérivée. Retourne `null` si la clé est
  /// mauvaise (code erroné) ou si le coffre a été altéré — les deux cas sont
  /// indiscernables, et c'est voulu : aucune information ne fuit.
  static Future<String?> open({
    required PinVault vault,
    required Uint8List key,
  }) async {
    try {
      final clear = await AesGcm.with256bits().decrypt(
        SecretBox(vault.cipherText, nonce: vault.nonce, mac: Mac(vault.mac)),
        secretKey: SecretKey(key),
      );
      return utf8.decode(clear);
    } on SecretBoxAuthenticationError {
      return null;
    } on FormatException {
      // Déchiffrement « réussi » mais contenu non UTF-8 : coffre corrompu.
      return null;
    }
  }
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Dérivation PBKDF2-HMAC-SHA256 proprement dite, partagée par les deux
/// plateformes. Volontairement une fonction de premier niveau : elle doit
/// pouvoir traverser la frontière d'un isolate.
Future<Uint8List> derivePbkdf2({
  required String code,
  required Uint8List salt,
  required int iterations,
}) async {
  final pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: iterations,
    bits: 256,
  );
  final key = await pbkdf2.deriveKey(
    secretKey: SecretKey(utf8.encode(code)),
    nonce: salt,
  );
  return Uint8List.fromList(await key.extractBytes());
}

import 'dart:typed_data';

import '_pbkdf2.dart';

/// Navigateur : `dart:isolate` n'existe pas (« dart:isolate is not supported
/// on dart4web »), toute tentative de déport échouerait à l'exécution.
///
/// Ce n'est pas une perte : sur le web, `cryptography` s'appuie sur l'API Web
/// Crypto du navigateur, dont le PBKDF2 est implémenté nativement et rendu de
/// façon asynchrone — le thread de l'interface n'est donc pas monopolisé.
Future<Uint8List> deriveOffThread({
  required String code,
  required Uint8List salt,
  required int iterations,
}) {
  return derivePbkdf2(code: code, salt: salt, iterations: iterations);
}

import 'dart:isolate';
import 'dart:typed_data';

import '_pbkdf2.dart';

/// Mobile et bureau : la dérivation coûte quelques centaines de millisecondes
/// de calcul pur, on la déporte dans un isolate pour que l'interface reste
/// fluide pendant la saisie.
Future<Uint8List> deriveOffThread({
  required String code,
  required Uint8List salt,
  required int iterations,
}) {
  // `Isolate.run` copie les arguments : seuls des types simples traversent.
  return Isolate.run(
    () => derivePbkdf2(code: code, salt: salt, iterations: iterations),
  );
}

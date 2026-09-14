import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';

abstract class RecuRepository {
  /// Reçu PDF d'écritures d'un même chauffeur : celles d'un versement, ou
  /// toutes celles d'un encaissement de masse. Le serveur refuse — motif à
  /// l'appui — une écriture annulée ou des chauffeurs mêlés.
  Future<Either<Failure, Uint8List>> getRecuPdf(List<int> operationIds);
}

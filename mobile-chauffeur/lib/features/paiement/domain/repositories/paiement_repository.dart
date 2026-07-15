import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/paiement.dart';

abstract interface class PaiementRepository {
  Future<Either<Failure, Paiement>> initier({
    required String typeCible,
    required int cibleId,
    required String canal,
    required String telephone,
  });

  Future<Either<Failure, Paiement>> statut(String reference);
}

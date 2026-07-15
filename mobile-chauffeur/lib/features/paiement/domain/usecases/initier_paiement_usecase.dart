import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/canal_paiement.dart';
import '../entities/paiement.dart';
import '../repositories/paiement_repository.dart';

class InitierPaiementUseCase {
  final PaiementRepository _repository;
  const InitierPaiementUseCase(this._repository);

  Future<Either<Failure, Paiement>> call({
    required String typeCible,
    required int cibleId,
    required CanalPaiement canal,
    required String telephone,
  }) =>
      _repository.initier(
        typeCible: typeCible,
        cibleId: cibleId,
        canal: canal.api,
        telephone: telephone,
      );
}

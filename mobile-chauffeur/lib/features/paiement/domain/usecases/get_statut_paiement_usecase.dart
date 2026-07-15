import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/paiement.dart';
import '../repositories/paiement_repository.dart';

class GetStatutPaiementUseCase {
  final PaiementRepository _repository;
  const GetStatutPaiementUseCase(this._repository);

  Future<Either<Failure, Paiement>> call(String reference) =>
      _repository.statut(reference);
}

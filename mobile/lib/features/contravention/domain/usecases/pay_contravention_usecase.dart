import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/contravention.dart';
import '../repositories/contravention_repository.dart';

class PayContraventionUseCase {
  final ContraventionRepository _repository;
  const PayContraventionUseCase(this._repository);

  Future<Either<Failure, Contravention>> call(
    int id,
    double montantPaye, {
    String? modePaiement,
    DateTime? dateEncaissement,
    String? reference,
    String? commentaire,
  }) =>
      _repository.payContravention(id, montantPaye,
          modePaiement: modePaiement,
          dateEncaissement: dateEncaissement,
          reference: reference,
          commentaire: commentaire);
}

import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/contravention.dart';
import '../repositories/contravention_repository.dart';

/// Reverse une contravention à l'État : côté serveur, crée l'opération
/// financière de catégorie « Reversement contravention » et solde la ligne.
class ReverseContraventionUseCase {
  final ContraventionRepository _repository;
  const ReverseContraventionUseCase(this._repository);

  Future<Either<Failure, Contravention>> call(int id) =>
      _repository.reverserContravention(id);
}

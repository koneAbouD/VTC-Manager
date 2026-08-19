import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/contravention.dart';
import '../repositories/contravention_repository.dart';

/// Remet en circulation une contravention annulée à tort.
///
/// Elle retrouve le statut que dicte ce que le chauffeur a versé — en attente
/// si rien n'a été payé — et redevient exigible. Le serveur la refuse une fois
/// la période comptable clôturée : le mois a été arrêté sans cette créance.
class RestaurerContraventionUseCase {
  final ContraventionRepository _repository;
  const RestaurerContraventionUseCase(this._repository);

  Future<Either<Failure, Contravention>> call(int id) =>
      _repository.restaurerContravention(id);
}

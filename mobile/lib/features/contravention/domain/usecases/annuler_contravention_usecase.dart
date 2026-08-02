import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/contravention.dart';
import '../repositories/contravention_repository.dart';

/// Annule une contravention saisie à tort.
///
/// Elle n'est pas effacée : tant qu'elle était due, elle a figuré parmi les
/// créances du chauffeur, et les états déjà arrêtés continuent de la porter.
/// Le serveur la refuse dès qu'un mouvement d'argent s'y rattache — versement
/// du chauffeur ou reversement à l'État.
class AnnulerContraventionUseCase {
  final ContraventionRepository _repository;
  const AnnulerContraventionUseCase(this._repository);

  Future<Either<Failure, Contravention>> call(int id, String motif) =>
      _repository.annulerContravention(id, motif);
}

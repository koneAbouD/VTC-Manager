import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/indisponibilite.dart';
import '../repositories/indisponibilite_repository.dart';

class DeclarerIndisponibiliteUseCase {
  final IndisponibiliteRepository _repository;
  const DeclarerIndisponibiliteUseCase(this._repository);

  Future<Either<Failure, Indisponibilite>> call({
    required int chauffeurRemplacantId,
    required String dateDebut,
    String? dateFin,
    String? motif,
    String? commentaire,
  }) =>
      _repository.declarer(
        chauffeurRemplacantId: chauffeurRemplacantId,
        dateDebut: dateDebut,
        dateFin: dateFin,
        motif: motif,
        commentaire: commentaire,
      );
}

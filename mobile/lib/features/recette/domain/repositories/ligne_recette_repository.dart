import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/page_result.dart';
import '../entities/encaissement.dart';
import '../entities/ligne_recette.dart';

abstract interface class LigneRecetteRepository {
  Future<Either<Failure, List<LigneRecette>>> getLignes({
    int? vehiculeId,
    int? chauffeurId,
    StatutLigneRecette? statut,
    DateTime? dateDebut,
    DateTime? dateFin,
  });

  Future<Either<Failure, PageResult<LigneRecette>>> getLignesPage({
    int page,
    int size,
    int? vehiculeId,
    int? chauffeurId,
    StatutLigneRecette? statut,
    DateTime? dateDebut,
    DateTime? dateFin,
  });

  Future<Either<Failure, LigneRecette>> getLigneById(int id);

  Future<Either<Failure, Encaissement>> createEncaissement(
    int ligneId,
    Encaissement encaissement,
  );

  Future<Either<Failure, LigneRecette>> annuler(int id);

  Future<Either<Failure, LigneRecette>> confirmerVersement(int id);

  Future<Either<Failure, List<LigneRecette>>> generer({DateTime? date});
}

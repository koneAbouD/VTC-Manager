import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/page_result.dart';
import '../entities/encaissement_penalite.dart';
import '../entities/ligne_penalite.dart';
import '../entities/ligne_penalite_filtres.dart';

abstract class PenaliteRepository {
  Future<Either<Failure, List<LignePenalite>>> getLignes(LignePenaliteFiltres filtres);

  Future<Either<Failure, PageResult<LignePenalite>>> getLignesPage(
      LignePenaliteFiltres filtres, {int page, int size});

  Future<Either<Failure, LignePenalite>> getLigneById(int id);

  Future<Either<Failure, LignePenalite>> createLigne(Map<String, dynamic> data);

  Future<Either<Failure, LignePenalite>> signalerRetard(Map<String, dynamic> data);

  Future<Either<Failure, EncaissementPenalite>> createEncaissement(
      int ligneId, Map<String, dynamic> data);

  Future<Either<Failure, List<EncaissementPenalite>>> getEncaissements(int ligneId);

  Future<Either<Failure, LignePenalite>> executer(int id);

  Future<Either<Failure, LignePenalite>> notifier(int id);

  Future<Either<Failure, LignePenalite>> demarrer(int id);

  Future<Either<Failure, LignePenalite>> lever(int id);

  Future<Either<Failure, LignePenalite>> annuler(int id, String motif);

  Future<Either<Failure, List<LignePenalite>>> generer({DateTime? date});
}

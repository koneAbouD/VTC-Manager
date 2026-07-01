import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/page_result.dart';
import '../entities/encaissement_cotisation.dart';
import '../entities/ligne_cotisation.dart';
import '../entities/ligne_cotisation_filtres.dart';

abstract interface class LigneCotisationRepository {
  Future<Either<Failure, List<LigneCotisation>>> getLignes(LigneCotisationFiltres filtres);
  Future<Either<Failure, PageResult<LigneCotisation>>> getLignesPage(
      LigneCotisationFiltres filtres, {int page, int size});
  Future<Either<Failure, LigneCotisation>> getLigneById(int id);
  Future<Either<Failure, EncaissementCotisation>> createEncaissement(int ligneId, EncaissementCotisation enc);
  Future<Either<Failure, LigneCotisation>> annuler(int id);
  Future<Either<Failure, List<LigneCotisation>>> generer({DateTime? date});
}

import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/recette.dart';

abstract interface class RecetteRepository {
  Future<Either<Failure, List<Recette>>> getRecettes();
  Future<Either<Failure, Recette>> getRecetteById(int id);
  Future<Either<Failure, Recette>> createRecette(Recette recette);
  Future<Either<Failure, Recette>> updateRecette(int id, Recette recette);
  Future<Either<Failure, void>> deleteRecette(int id);
}

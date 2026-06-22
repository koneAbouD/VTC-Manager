import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/recette.dart';
import '../repositories/recette_repository.dart';

class UpdateRecetteUseCase {
  final RecetteRepository _repository;
  const UpdateRecetteUseCase(this._repository);

  Future<Either<Failure, Recette>> call(int id, Recette recette) =>
      _repository.updateRecette(id, recette);
}

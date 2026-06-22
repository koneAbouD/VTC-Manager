import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/recette.dart';
import '../repositories/recette_repository.dart';

class CreateRecetteUseCase {
  final RecetteRepository _repository;
  const CreateRecetteUseCase(this._repository);

  Future<Either<Failure, Recette>> call(Recette recette) =>
      _repository.createRecette(recette);
}

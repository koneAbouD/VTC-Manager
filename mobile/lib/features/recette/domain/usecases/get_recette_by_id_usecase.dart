import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/recette.dart';
import '../repositories/recette_repository.dart';

class GetRecetteByIdUseCase {
  final RecetteRepository _repository;
  const GetRecetteByIdUseCase(this._repository);

  Future<Either<Failure, Recette>> call(int id) =>
      _repository.getRecetteById(id);
}

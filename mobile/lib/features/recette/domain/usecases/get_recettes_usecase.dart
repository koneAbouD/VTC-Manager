import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/recette.dart';
import '../repositories/recette_repository.dart';

class GetRecettesUseCase {
  final RecetteRepository _repository;
  const GetRecettesUseCase(this._repository);

  Future<Either<Failure, List<Recette>>> call() => _repository.getRecettes();
}

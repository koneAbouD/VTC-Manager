import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/ligne_recette.dart';
import '../repositories/recette_repository.dart';

class GetRecettesUseCase {
  final RecetteRepository _repository;
  const GetRecettesUseCase(this._repository);

  Future<Either<Failure, List<LigneRecette>>> call() => _repository.getRecettes();
}

import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../repositories/recette_repository.dart';

class DeleteRecetteUseCase {
  final RecetteRepository _repository;
  const DeleteRecetteUseCase(this._repository);

  Future<Either<Failure, void>> call(int id) => _repository.deleteRecette(id);
}

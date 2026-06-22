import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../repositories/chauffeur_repository.dart';

class DeleteChauffeurUseCase {
  final ChauffeurRepository _repository;
  const DeleteChauffeurUseCase(this._repository);

  Future<Either<Failure, void>> call(int id) =>
      _repository.deleteChauffeur(id);
}

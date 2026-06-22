import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/chauffeur.dart';
import '../repositories/chauffeur_repository.dart';

class GetChauffeurByIdUseCase {
  final ChauffeurRepository _repository;
  const GetChauffeurByIdUseCase(this._repository);

  Future<Either<Failure, Chauffeur>> call(int id) =>
      _repository.getChauffeurById(id);
}

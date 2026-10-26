import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/profil.dart';
import '../repositories/compte_repository.dart';

class GetProfilUseCase {
  final CompteRepository _repository;
  const GetProfilUseCase(this._repository);

  Future<Either<Failure, Profil>> call() => _repository.getProfil();
}

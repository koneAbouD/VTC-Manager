import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/programme_travail.dart';
import '../repositories/programme_travail_repository.dart';

class CreateProgrammeTravailUseCase {
  final ProgrammeTravailRepository _repository;

  const CreateProgrammeTravailUseCase(this._repository);

  Future<Either<Failure, ProgrammeTravail>> call(
    int vehiculeId,
    ProgrammeTravail programme, {
    bool force = false,
  }) {
    return _repository.createProgramme(vehiculeId, programme, force: force);
  }
}

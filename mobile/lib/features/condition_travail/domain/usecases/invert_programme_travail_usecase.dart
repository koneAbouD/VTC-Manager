import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/programme_travail.dart';
import '../repositories/programme_travail_repository.dart';

class InvertProgrammeTravailUseCase {
  final ProgrammeTravailRepository _repository;

  const InvertProgrammeTravailUseCase(this._repository);

  Future<Either<Failure, ProgrammeTravail>> call(int vehiculeId) {
    return _repository.invertProgramme(vehiculeId);
  }
}

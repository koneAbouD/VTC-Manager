import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/contravention.dart';
import '../repositories/contravention_repository.dart';

class GetContraventionByIdUseCase {
  final ContraventionRepository _repository;
  const GetContraventionByIdUseCase(this._repository);

  Future<Either<Failure, Contravention>> call(int id) =>
      _repository.getContraventionById(id);
}

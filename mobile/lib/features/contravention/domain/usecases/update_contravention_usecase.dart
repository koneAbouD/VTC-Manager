import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/contravention.dart';
import '../repositories/contravention_repository.dart';

class UpdateContraventionUseCase {
  final ContraventionRepository _repository;
  const UpdateContraventionUseCase(this._repository);

  Future<Either<Failure, Contravention>> call(
          int id, Contravention contravention) =>
      _repository.updateContravention(id, contravention);
}

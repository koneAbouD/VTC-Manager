import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/contravention.dart';
import '../repositories/contravention_repository.dart';

class CreateContraventionUseCase {
  final ContraventionRepository _repository;
  const CreateContraventionUseCase(this._repository);

  Future<Either<Failure, Contravention>> call(Contravention contravention) =>
      _repository.createContravention(contravention);
}

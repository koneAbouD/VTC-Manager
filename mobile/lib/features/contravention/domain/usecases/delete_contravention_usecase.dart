import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../repositories/contravention_repository.dart';

class DeleteContraventionUseCase {
  final ContraventionRepository _repository;
  const DeleteContraventionUseCase(this._repository);

  Future<Either<Failure, void>> call(int id) =>
      _repository.deleteContravention(id);
}

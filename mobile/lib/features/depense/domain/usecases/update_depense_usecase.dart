import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/depense.dart';
import '../repositories/depense_repository.dart';

class UpdateDepenseUseCase {
  final DepenseRepository _repository;
  const UpdateDepenseUseCase(this._repository);

  Future<Either<Failure, Depense>> call(int id, Depense depense) =>
      _repository.updateDepense(id, depense);
}

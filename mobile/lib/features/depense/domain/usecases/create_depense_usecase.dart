import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/depense.dart';
import '../repositories/depense_repository.dart';

class CreateDepenseUseCase {
  final DepenseRepository _repository;
  const CreateDepenseUseCase(this._repository);

  Future<Either<Failure, Depense>> call(Depense depense) =>
      _repository.createDepense(depense);
}

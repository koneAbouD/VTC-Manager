import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/depense.dart';
import '../repositories/depense_repository.dart';

class GetDepensesUseCase {
  final DepenseRepository _repository;
  const GetDepensesUseCase(this._repository);

  Future<Either<Failure, List<Depense>>> call() => _repository.getDepenses();
}

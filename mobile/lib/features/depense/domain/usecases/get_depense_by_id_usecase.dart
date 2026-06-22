import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/depense.dart';
import '../repositories/depense_repository.dart';

class GetDepenseByIdUseCase {
  final DepenseRepository _repository;
  const GetDepenseByIdUseCase(this._repository);

  Future<Either<Failure, Depense>> call(int id) =>
      _repository.getDepenseById(id);
}

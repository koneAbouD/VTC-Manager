import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../repositories/depense_repository.dart';

class DeleteDepenseUseCase {
  final DepenseRepository _repository;
  const DeleteDepenseUseCase(this._repository);

  Future<Either<Failure, void>> call(int id) => _repository.deleteDepense(id);
}

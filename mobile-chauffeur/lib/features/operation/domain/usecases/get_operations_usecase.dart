import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/operation_financiere.dart';
import '../repositories/operation_repository.dart';

class GetOperationsUseCase {
  final OperationRepository _repository;
  const GetOperationsUseCase(this._repository);

  Future<Either<Failure, List<OperationFinanciere>>> call() =>
      _repository.getOperations();
}

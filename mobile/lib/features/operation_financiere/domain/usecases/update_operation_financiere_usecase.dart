import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failure.dart';
import '../entities/operation_financiere.dart';
import '../repositories/operation_financiere_repository.dart';

class UpdateOperationFinanciereUseCase {
  final OperationFinanciereRepository _repository;
  const UpdateOperationFinanciereUseCase(this._repository);

  Future<Either<Failure, OperationFinanciere>> call(
          int id, Map<String, dynamic> payload) =>
      _repository.update(id, payload);
}

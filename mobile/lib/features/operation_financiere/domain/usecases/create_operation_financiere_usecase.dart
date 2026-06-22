import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failure.dart';
import '../entities/operation_financiere.dart';
import '../repositories/operation_financiere_repository.dart';

class CreateOperationFinanciereUseCase {
  final OperationFinanciereRepository _repository;
  const CreateOperationFinanciereUseCase(this._repository);

  Future<Either<Failure, OperationFinanciere>> call(
          Map<String, dynamic> payload) =>
      _repository.create(payload);
}

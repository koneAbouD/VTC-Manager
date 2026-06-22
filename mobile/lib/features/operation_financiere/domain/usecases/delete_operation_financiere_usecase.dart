import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failure.dart';
import '../repositories/operation_financiere_repository.dart';

class DeleteOperationFinanciereUseCase {
  final OperationFinanciereRepository _repository;
  const DeleteOperationFinanciereUseCase(this._repository);

  Future<Either<Failure, void>> call(int id) => _repository.delete(id);
}

import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failure.dart';
import '../repositories/operation_financiere_repository.dart';

class AnnulerOperationFinanciereUseCase {
  final OperationFinanciereRepository _repository;
  const AnnulerOperationFinanciereUseCase(this._repository);

  Future<Either<Failure, void>> call(int id) => _repository.annuler(id);
}

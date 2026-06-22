import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failure.dart';
import '../repositories/operation_financiere_repository.dart';

class ValiderOperationFinanciereUseCase {
  final OperationFinanciereRepository _repository;
  const ValiderOperationFinanciereUseCase(this._repository);

  Future<Either<Failure, void>> call(int id) => _repository.valider(id);
}

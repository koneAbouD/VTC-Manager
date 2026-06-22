import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failure.dart';
import '../entities/operation_financiere.dart';
import '../repositories/operation_financiere_repository.dart';

class GetOperationsFinancieresUseCase {
  final OperationFinanciereRepository _repository;
  const GetOperationsFinancieresUseCase(this._repository);

  Future<Either<Failure, List<OperationFinanciere>>> call({
    String? typeOperation,
    String? debut,
    String? fin,
    String? statut,
    String? categorieCode,
  }) => _repository.getAll(
        typeOperation: typeOperation,
        debut: debut,
        fin: fin,
        statut: statut,
        categorieCode: categorieCode,
      );
}

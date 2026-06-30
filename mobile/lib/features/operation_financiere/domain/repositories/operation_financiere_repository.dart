import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failure.dart';
import '../entities/operation_financiere.dart';

abstract class OperationFinanciereRepository {
  Future<Either<Failure, List<OperationFinanciere>>> getAll({
    String? typeOperation,
    String? debut,
    String? fin,
    String? statut,
    String? categorieCode,
  });

  Future<Either<Failure, OperationFinanciere>> getById(int id);

  Future<Either<Failure, OperationFinanciere>> create(
      Map<String, dynamic> payload);

  Future<Either<Failure, OperationFinanciere>> update(
      int id, Map<String, dynamic> payload);

  Future<Either<Failure, void>> delete(int id);

  Future<Either<Failure, void>> annuler(int id);
}

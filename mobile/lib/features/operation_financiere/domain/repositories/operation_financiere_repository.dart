import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/page_result.dart';
import '../entities/operation_financiere.dart';

abstract class OperationFinanciereRepository {
  Future<Either<Failure, List<OperationFinanciere>>> getAll({
    String? typeOperation,
    String? debut,
    String? fin,
    String? statut,
    String? categorieCode,
  });

  Future<Either<Failure, PageResult<OperationFinanciere>>> getPage({
    int page,
    int size,
    String? typeOperation,
    String? debut,
    String? fin,
    String? statut,
    String? categorieCode,
    String? sousCategorieLibelle,
    int? vehiculeId,
    int? chauffeurId,
    String? recherche,
  });

  Future<Either<Failure, OperationFinanciere>> getById(int id);

  Future<Either<Failure, OperationFinanciere>> create(
      Map<String, dynamic> payload);

  Future<Either<Failure, OperationFinanciere>> update(
      int id, Map<String, dynamic> payload);

  Future<Either<Failure, void>> annuler(int id);
}

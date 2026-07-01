import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/page_result.dart';
import '../entities/operation_financiere.dart';
import '../repositories/operation_financiere_repository.dart';

class GetOperationsFinancieresPageUseCase {
  final OperationFinanciereRepository _repository;
  const GetOperationsFinancieresPageUseCase(this._repository);

  Future<Either<Failure, PageResult<OperationFinanciere>>> call({
    int page = 0,
    int size = 20,
    String? typeOperation,
    String? debut,
    String? fin,
    String? statut,
    String? categorieCode,
    String? sousCategorieLibelle,
    int? vehiculeId,
    int? chauffeurId,
    String? recherche,
  }) =>
      _repository.getPage(
        page: page,
        size: size,
        typeOperation: typeOperation,
        debut: debut,
        fin: fin,
        statut: statut,
        categorieCode: categorieCode,
        sousCategorieLibelle: sousCategorieLibelle,
        vehiculeId: vehiculeId,
        chauffeurId: chauffeurId,
        recherche: recherche,
      );
}

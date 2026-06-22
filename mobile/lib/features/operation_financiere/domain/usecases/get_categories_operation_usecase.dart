import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failure.dart';
import '../entities/categorie_operation.dart';
import '../entities/sous_categorie_operation.dart';
import '../repositories/categorie_operation_repository.dart';

class GetCategoriesOperationUseCase {
  final CategorieOperationRepository _repository;
  const GetCategoriesOperationUseCase(this._repository);

  Future<Either<Failure, List<CategorieOperation>>> call(
          {String? typeOperation, bool includeSousCategorie = false}) =>
      _repository.getAll(
          typeOperation: typeOperation,
          includeSousCategorie: includeSousCategorie);

  Future<Either<Failure, List<SousCategorieOperation>>> getSousCategories(
          {required int categorieId}) =>
      _repository.getSousCategories(categorieId: categorieId);
}

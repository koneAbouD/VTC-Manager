import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failure.dart';
import '../entities/categorie_operation.dart';
import '../entities/sous_categorie_operation.dart';

abstract class CategorieOperationRepository {
  Future<Either<Failure, List<CategorieOperation>>> getAll(
      {String? typeOperation, bool includeSousCategorie = false});

  Future<Either<Failure, List<SousCategorieOperation>>> getSousCategories(
      {required int categorieId});
}

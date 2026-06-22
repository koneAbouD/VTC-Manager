import 'package:fpdart/fpdart.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/categorie_operation.dart';
import '../../domain/entities/sous_categorie_operation.dart';
import '../../domain/repositories/categorie_operation_repository.dart';
import '../datasources/categorie_operation_remote_datasource.dart';

class CategorieOperationRepositoryImpl
    implements CategorieOperationRepository {
  final CategorieOperationRemoteDatasource _datasource;
  const CategorieOperationRepositoryImpl(this._datasource);

  @override
  Future<Either<Failure, List<CategorieOperation>>> getAll(
      {String? typeOperation, bool includeSousCategorie = false}) async {
    try {
      return Right(await _datasource.getAll(
          typeOperation: typeOperation,
          includeSousCategorie: includeSousCategorie));
    } on ApiException catch (e) {
      return Left(_map(e));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<SousCategorieOperation>>> getSousCategories(
      {required int categorieId}) async {
    try {
      return Right(
          await _datasource.getSousCategories(categorieId: categorieId));
    } on ApiException catch (e) {
      return Left(_map(e));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  Failure _map(ApiException e) {
    if (e.statusCode == 404) return NotFoundFailure(e.message);
    if (e.statusCode >= 400 && e.statusCode < 500) return ValidationFailure(e.message);
    return ServerFailure(e.message, statusCode: e.statusCode);
  }
}

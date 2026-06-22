import 'package:fpdart/fpdart.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/recette.dart';
import '../../domain/repositories/recette_repository.dart';
import '../datasources/recette_remote_datasource.dart';
import '../models/recette_model.dart';

class RecetteRepositoryImpl implements RecetteRepository {
  final RecetteRemoteDatasource _datasource;
  const RecetteRepositoryImpl(this._datasource);

  @override
  Future<Either<Failure, List<Recette>>> getRecettes() async {
    try {
      final result = await _datasource.getRecettes();
      return Right(result);
    } on ApiException catch (e) {
      return Left(_mapApiException(e));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Recette>> getRecetteById(int id) async {
    try {
      final result = await _datasource.getRecetteById(id);
      return Right(result);
    } on ApiException catch (e) {
      return Left(_mapApiException(e));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Recette>> createRecette(Recette recette) async {
    try {
      final model = RecetteModel.fromEntity(recette);
      final result = await _datasource.createRecette(model);
      return Right(result);
    } on ApiException catch (e) {
      return Left(_mapApiException(e));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Recette>> updateRecette(
      int id, Recette recette) async {
    try {
      final model = RecetteModel.fromEntity(recette);
      final result = await _datasource.updateRecette(id, model);
      return Right(result);
    } on ApiException catch (e) {
      return Left(_mapApiException(e));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteRecette(int id) async {
    try {
      await _datasource.deleteRecette(id);
      return const Right(null);
    } on ApiException catch (e) {
      return Left(_mapApiException(e));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  Failure _mapApiException(ApiException e) {
    if (e.statusCode == 404) return NotFoundFailure(e.message);
    if (e.statusCode == 401 || e.statusCode == 403) {
      return AuthFailure(e.message);
    }
    if (e.statusCode >= 400 && e.statusCode < 500) {
      return ValidationFailure(e.message);
    }
    return ServerFailure(e.message, statusCode: e.statusCode);
  }
}

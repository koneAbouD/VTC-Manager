import 'package:fpdart/fpdart.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/depense.dart';
import '../../domain/repositories/depense_repository.dart';
import '../datasources/depense_remote_datasource.dart';
import '../models/depense_model.dart';

class DepenseRepositoryImpl implements DepenseRepository {
  final DepenseRemoteDatasource _datasource;
  const DepenseRepositoryImpl(this._datasource);

  @override
  Future<Either<Failure, List<Depense>>> getDepenses() async {
    try {
      final result = await _datasource.getDepenses();
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
  Future<Either<Failure, Depense>> getDepenseById(int id) async {
    try {
      final result = await _datasource.getDepenseById(id);
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
  Future<Either<Failure, Depense>> createDepense(Depense depense) async {
    try {
      final model = DepenseModel.fromEntity(depense);
      final result = await _datasource.createDepense(model);
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
  Future<Either<Failure, Depense>> updateDepense(
      int id, Depense depense) async {
    try {
      final model = DepenseModel.fromEntity(depense);
      final result = await _datasource.updateDepense(id, model);
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
  Future<Either<Failure, void>> deleteDepense(int id) async {
    try {
      await _datasource.deleteDepense(id);
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

import 'package:fpdart/fpdart.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/operation_financiere.dart';
import '../../domain/repositories/operation_financiere_repository.dart';
import '../datasources/operation_financiere_remote_datasource.dart';

class OperationFinanciereRepositoryImpl
    implements OperationFinanciereRepository {
  final OperationFinanciereRemoteDatasource _datasource;
  const OperationFinanciereRepositoryImpl(this._datasource);

  @override
  Future<Either<Failure, List<OperationFinanciere>>> getAll({
    String? typeOperation,
    String? debut,
    String? fin,
    String? statut,
    String? categorieCode,
  }) async {
    try {
      final result = await _datasource.getAll(
          typeOperation: typeOperation,
          debut: debut,
          fin: fin,
          statut: statut,
          categorieCode: categorieCode);
      return Right(result);
    } on ApiException catch (e) {
      return Left(_map(e));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, OperationFinanciere>> getById(int id) async {
    try {
      return Right(await _datasource.getById(id));
    } on ApiException catch (e) {
      return Left(_map(e));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, OperationFinanciere>> create(
      Map<String, dynamic> payload) async {
    try {
      return Right(await _datasource.create(payload));
    } on ApiException catch (e) {
      return Left(_map(e));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, OperationFinanciere>> update(
      int id, Map<String, dynamic> payload) async {
    try {
      return Right(await _datasource.update(id, payload));
    } on ApiException catch (e) {
      return Left(_map(e));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> delete(int id) async {
    try {
      await _datasource.delete(id);
      return const Right(null);
    } on ApiException catch (e) {
      return Left(_map(e));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> valider(int id) async {
    try {
      await _datasource.valider(id);
      return const Right(null);
    } on ApiException catch (e) {
      return Left(_map(e));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> annuler(int id) async {
    try {
      await _datasource.annuler(id);
      return const Right(null);
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
    if (e.statusCode == 401 || e.statusCode == 403) return AuthFailure(e.message);
    if (e.statusCode == 409) return ConflictFailure(e.message);
    if (e.statusCode >= 400 && e.statusCode < 500) return ValidationFailure(e.message);
    return ServerFailure(e.message, statusCode: e.statusCode);
  }
}

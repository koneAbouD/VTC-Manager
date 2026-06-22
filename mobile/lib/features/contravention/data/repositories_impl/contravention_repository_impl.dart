import 'package:fpdart/fpdart.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/contravention.dart';
import '../../domain/repositories/contravention_repository.dart';
import '../datasources/contravention_remote_datasource.dart';
import '../models/contravention_model.dart';

class ContraventionRepositoryImpl implements ContraventionRepository {
  final ContraventionRemoteDatasource _datasource;
  const ContraventionRepositoryImpl(this._datasource);

  @override
  Future<Either<Failure, List<Contravention>>> getContraventions() async {
    try {
      final result = await _datasource.getContraventions();
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
  Future<Either<Failure, Contravention>> getContraventionById(int id) async {
    try {
      final result = await _datasource.getContraventionById(id);
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
  Future<Either<Failure, Contravention>> createContravention(
      Contravention contravention) async {
    try {
      final model = ContraventionModel.fromEntity(contravention);
      final result = await _datasource.createContravention(model);
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
  Future<Either<Failure, Contravention>> updateContravention(
      int id, Contravention contravention) async {
    try {
      final model = ContraventionModel.fromEntity(contravention);
      final result = await _datasource.updateContravention(id, model);
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
  Future<Either<Failure, void>> deleteContravention(int id) async {
    try {
      await _datasource.deleteContravention(id);
      return const Right(null);
    } on ApiException catch (e) {
      return Left(_mapApiException(e));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Contravention>> payContravention(
      int id, double montantPaye) async {
    try {
      final result = await _datasource.payContravention(id, montantPaye);
      return Right(result);
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

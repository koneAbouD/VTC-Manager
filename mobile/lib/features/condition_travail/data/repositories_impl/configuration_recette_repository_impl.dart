import 'package:fpdart/fpdart.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/configuration_recette.dart';
import '../../domain/repositories/configuration_recette_repository.dart';
import '../datasources/configuration_recette_remote_datasource.dart';
import '../models/configuration_recette_model.dart';

class ConfigurationRecetteRepositoryImpl
    implements ConfigurationRecetteRepository {
  final ConfigurationRecetteRemoteDatasource _datasource;

  const ConfigurationRecetteRepositoryImpl(this._datasource);

  @override
  Future<Either<Failure, ConfigurationRecette>> getConfiguration(
    int vehiculeId,
  ) async {
    try {
      return Right(await _datasource.getConfiguration(vehiculeId));
    } on ApiException catch (e) {
      return Left(_mapApiException(e));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, ConfigurationRecette>> createConfiguration(
    int vehiculeId,
    ConfigurationRecette configuration,
  ) async {
    try {
      final model = ConfigurationRecetteModel.fromEntity(configuration);
      return Right(await _datasource.createConfiguration(vehiculeId, model));
    } on ApiException catch (e) {
      return Left(_mapApiException(e));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, ConfigurationRecette>> updateConfiguration(
    int vehiculeId,
    ConfigurationRecette configuration,
  ) async {
    try {
      final model = ConfigurationRecetteModel.fromEntity(configuration);
      return Right(await _datasource.updateConfiguration(vehiculeId, model));
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

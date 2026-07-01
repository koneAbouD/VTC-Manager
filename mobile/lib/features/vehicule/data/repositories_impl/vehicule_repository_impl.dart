import 'package:fpdart/fpdart.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/page_result.dart';
import '../../domain/entities/vehicule.dart';
import '../../domain/repositories/vehicule_repository.dart';
import '../datasources/vehicule_remote_datasource.dart';
import '../models/vehicule_model.dart';

class VehiculeRepositoryImpl implements VehiculeRepository {
  final VehiculeRemoteDatasource _datasource;
  const VehiculeRepositoryImpl(this._datasource);

  @override
  Future<Either<Failure, List<Vehicule>>> getVehicules() async {
    try {
      final result = await _datasource.getVehicules();
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
  Future<Either<Failure, PageResult<Vehicule>>> getVehiculesPage({
    int page = 0,
    int size = 20,
    String? statut,
  }) async {
    try {
      final result = await _datasource.getVehiculesPage(
        page: page,
        size: size,
        statut: statut,
      );
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
  Future<Either<Failure, Vehicule>> getVehiculeById(int id) async {
    try {
      final result = await _datasource.getVehiculeById(id);
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
  Future<Either<Failure, Vehicule>> createVehicule(Vehicule vehicule) async {
    try {
      final model = VehiculeModel.fromEntity(vehicule);
      final result = await _datasource.createVehicule(model);
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
  Future<Either<Failure, Vehicule>> updateVehicule(
      int id, Vehicule vehicule) async {
    try {
      final model = VehiculeModel.fromEntity(vehicule);
      final result = await _datasource.updateVehicule(id, model);
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
  Future<Either<Failure, void>> deleteVehicule(int id) async {
    try {
      await _datasource.deleteVehicule(id);
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
    if (e.statusCode == 409) return ConflictFailure(e.message);
    if (e.statusCode == 401 || e.statusCode == 403) {
      return AuthFailure(e.message);
    }
    if (e.statusCode >= 400 && e.statusCode < 500) {
      return ValidationFailure(e.message);
    }
    return ServerFailure(e.message, statusCode: e.statusCode);
  }
}

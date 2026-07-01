import 'package:fpdart/fpdart.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/page_result.dart';
import '../../domain/entities/maintenance.dart';
import '../../domain/repositories/maintenance_repository.dart';
import '../datasources/maintenance_remote_datasource.dart';
import '../models/maintenance_model.dart';

class MaintenanceRepositoryImpl implements MaintenanceRepository {
  final MaintenanceRemoteDatasource _datasource;
  const MaintenanceRepositoryImpl(this._datasource);

  @override
  Future<Either<Failure, List<Maintenance>>> getMaintenances({
    String? dateDebut,
    String? dateFin,
    String? statut,
    int? vehiculeId,
  }) async {
    try {
      final result = await _datasource.getMaintenances(
        dateDebut: dateDebut,
        dateFin: dateFin,
        statut: statut,
        vehiculeId: vehiculeId,
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
  Future<Either<Failure, PageResult<Maintenance>>> getMaintenancesPage({
    int page = 0,
    int size = 20,
    String? dateDebut,
    String? dateFin,
    String? statut,
    int? vehiculeId,
  }) async {
    try {
      final result = await _datasource.getMaintenancesPage(
        page: page,
        size: size,
        dateDebut: dateDebut,
        dateFin: dateFin,
        statut: statut,
        vehiculeId: vehiculeId,
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
  Future<Either<Failure, Maintenance>> getMaintenanceById(int id) async {
    try {
      final result = await _datasource.getMaintenanceById(id);
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
  Future<Either<Failure, Maintenance>> createMaintenance(
      Maintenance maintenance) async {
    try {
      final model = MaintenanceModel.fromEntity(maintenance);
      final result = await _datasource.createMaintenance(model);
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
  Future<Either<Failure, Maintenance>> updateMaintenance(
      int id, Maintenance maintenance) async {
    try {
      final model = MaintenanceModel.fromEntity(maintenance);
      final result = await _datasource.updateMaintenance(id, model);
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
  Future<Either<Failure, void>> deleteMaintenance(int id) async {
    try {
      await _datasource.deleteMaintenance(id);
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
  Future<Either<Failure, Maintenance>> annulerMaintenance(int id) async {
    try {
      return Right(await _datasource.annulerMaintenance(id));
    } on ApiException catch (e) {
      return Left(_mapApiException(e));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Maintenance>> completeMaintenance(
      int id, double cout) async {
    try {
      final result = await _datasource.completeMaintenance(id, cout);
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

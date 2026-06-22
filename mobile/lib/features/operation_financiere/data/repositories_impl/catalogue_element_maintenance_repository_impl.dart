import 'package:fpdart/fpdart.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/catalogue_element_maintenance.dart';
import '../../domain/repositories/catalogue_element_maintenance_repository.dart';
import '../datasources/catalogue_element_maintenance_remote_datasource.dart';

class CatalogueElementMaintenanceRepositoryImpl
    implements CatalogueElementMaintenanceRepository {
  final CatalogueElementMaintenanceRemoteDatasource _datasource;
  const CatalogueElementMaintenanceRepositoryImpl(this._datasource);

  @override
  Future<Either<Failure, List<CatalogueElementMaintenance>>> getAll() async {
    try {
      return Right(await _datasource.getAll());
    } on ApiException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }
}

import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failure.dart';
import '../entities/catalogue_element_maintenance.dart';

abstract class CatalogueElementMaintenanceRepository {
  Future<Either<Failure, List<CatalogueElementMaintenance>>> getAll();
}

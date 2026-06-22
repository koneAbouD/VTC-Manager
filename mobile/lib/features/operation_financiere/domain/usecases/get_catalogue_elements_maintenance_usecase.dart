import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failure.dart';
import '../entities/catalogue_element_maintenance.dart';
import '../repositories/catalogue_element_maintenance_repository.dart';

class GetCatalogueElementsMaintenanceUseCase {
  final CatalogueElementMaintenanceRepository _repository;
  const GetCatalogueElementsMaintenanceUseCase(this._repository);

  Future<Either<Failure, List<CatalogueElementMaintenance>>> call() =>
      _repository.getAll();
}

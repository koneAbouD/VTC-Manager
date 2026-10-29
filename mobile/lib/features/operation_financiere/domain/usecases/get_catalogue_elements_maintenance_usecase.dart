import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failure.dart';
import '../entities/catalogue_element_maintenance.dart';
import '../repositories/catalogue_element_maintenance_repository.dart';

class GetCatalogueElementsMaintenanceUseCase {
  final CatalogueElementMaintenanceRepository _repository;
  const GetCatalogueElementsMaintenanceUseCase(this._repository);

  Future<Either<Failure, List<CatalogueElementMaintenance>>> call(
          {int? vehiculeId, int? categorieTypeId}) =>
      _repository.getAll(
          vehiculeId: vehiculeId, categorieTypeId: categorieTypeId);
}

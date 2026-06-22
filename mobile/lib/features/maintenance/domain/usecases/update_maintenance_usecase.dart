import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/maintenance.dart';
import '../repositories/maintenance_repository.dart';

class UpdateMaintenanceUseCase {
  final MaintenanceRepository _repository;
  const UpdateMaintenanceUseCase(this._repository);

  Future<Either<Failure, Maintenance>> call(int id, Maintenance maintenance) =>
      _repository.updateMaintenance(id, maintenance);
}

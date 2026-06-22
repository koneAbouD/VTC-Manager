import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/maintenance.dart';
import '../repositories/maintenance_repository.dart';

class CreateMaintenanceUseCase {
  final MaintenanceRepository _repository;
  const CreateMaintenanceUseCase(this._repository);

  Future<Either<Failure, Maintenance>> call(Maintenance maintenance) =>
      _repository.createMaintenance(maintenance);
}

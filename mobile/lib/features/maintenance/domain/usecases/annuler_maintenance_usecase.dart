import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/maintenance.dart';
import '../repositories/maintenance_repository.dart';

class AnnulerMaintenanceUseCase {
  final MaintenanceRepository _repository;
  const AnnulerMaintenanceUseCase(this._repository);

  Future<Either<Failure, Maintenance>> call(int id) =>
      _repository.annulerMaintenance(id);
}

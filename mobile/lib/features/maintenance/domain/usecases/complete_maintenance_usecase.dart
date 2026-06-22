import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/maintenance.dart';
import '../repositories/maintenance_repository.dart';

class CompleteMaintenanceUseCase {
  final MaintenanceRepository _repository;
  const CompleteMaintenanceUseCase(this._repository);

  Future<Either<Failure, Maintenance>> call(int id, double cout) =>
      _repository.completeMaintenance(id, cout);
}

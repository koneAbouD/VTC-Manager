import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../repositories/maintenance_repository.dart';

class DeleteMaintenanceUseCase {
  final MaintenanceRepository _repository;
  const DeleteMaintenanceUseCase(this._repository);

  Future<Either<Failure, void>> call(int id) =>
      _repository.deleteMaintenance(id);
}

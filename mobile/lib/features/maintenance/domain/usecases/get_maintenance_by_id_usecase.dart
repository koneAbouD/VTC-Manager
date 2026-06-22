import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/maintenance.dart';
import '../repositories/maintenance_repository.dart';

class GetMaintenanceByIdUseCase {
  final MaintenanceRepository _repository;
  const GetMaintenanceByIdUseCase(this._repository);

  Future<Either<Failure, Maintenance>> call(int id) =>
      _repository.getMaintenanceById(id);
}

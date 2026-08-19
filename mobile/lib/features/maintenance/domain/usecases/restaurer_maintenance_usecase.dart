import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/maintenance.dart';
import '../repositories/maintenance_repository.dart';

/// Remet en circulation une maintenance annulée à tort : elle repasse en
/// planifiée, l'intervention est de nouveau à faire.
///
/// Le serveur la refuse une fois la période comptable clôturée.
class RestaurerMaintenanceUseCase {
  final MaintenanceRepository _repository;
  const RestaurerMaintenanceUseCase(this._repository);

  Future<Either<Failure, Maintenance>> call(int id) =>
      _repository.restaurerMaintenance(id);
}

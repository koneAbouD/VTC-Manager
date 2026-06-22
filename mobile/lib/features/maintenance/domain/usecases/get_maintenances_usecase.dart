import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/maintenance.dart';
import '../repositories/maintenance_repository.dart';

class GetMaintenancesUseCase {
  final MaintenanceRepository _repository;
  const GetMaintenancesUseCase(this._repository);

  Future<Either<Failure, List<Maintenance>>> call({
    String? dateDebut,
    String? dateFin,
    String? statut,
    int? vehiculeId,
  }) =>
      _repository.getMaintenances(
        dateDebut: dateDebut,
        dateFin: dateFin,
        statut: statut,
        vehiculeId: vehiculeId,
      );
}

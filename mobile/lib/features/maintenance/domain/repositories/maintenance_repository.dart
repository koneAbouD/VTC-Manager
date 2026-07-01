import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/page_result.dart';
import '../entities/maintenance.dart';

abstract interface class MaintenanceRepository {
  Future<Either<Failure, List<Maintenance>>> getMaintenances({
    String? dateDebut,
    String? dateFin,
    String? statut,
    int? vehiculeId,
  });

  Future<Either<Failure, PageResult<Maintenance>>> getMaintenancesPage({
    int page,
    int size,
    String? dateDebut,
    String? dateFin,
    String? statut,
    int? vehiculeId,
  });
  Future<Either<Failure, Maintenance>> getMaintenanceById(int id);
  Future<Either<Failure, Maintenance>> createMaintenance(Maintenance maintenance);
  Future<Either<Failure, Maintenance>> updateMaintenance(int id, Maintenance maintenance);
  Future<Either<Failure, void>> deleteMaintenance(int id);
  Future<Either<Failure, Maintenance>> annulerMaintenance(int id);
  Future<Either<Failure, Maintenance>> completeMaintenance(int id, double cout);
}

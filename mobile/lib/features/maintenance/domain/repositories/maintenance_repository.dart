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

  /// [recherche] : mot-clé libre confronté côté serveur au type de maintenance,
  /// à l'immatriculation du véhicule et au nom du prestataire.
  Future<Either<Failure, PageResult<Maintenance>>> getMaintenancesPage({
    int page,
    int size,
    String? dateDebut,
    String? dateFin,
    String? statut,
    int? vehiculeId,
    String? recherche,
  });
  Future<Either<Failure, Maintenance>> getMaintenanceById(int id);
  Future<Either<Failure, Maintenance>> createMaintenance(Maintenance maintenance);
  Future<Either<Failure, Maintenance>> updateMaintenance(int id, Maintenance maintenance);
  Future<Either<Failure, void>> deleteMaintenance(int id);
  /// Annule l'intervention. [motif] est obligatoire : il justifie le retrait
  /// du programme et reste attaché à la maintenance.
  Future<Either<Failure, Maintenance>> annulerMaintenance(int id, String motif);

  /// Remet une maintenance annulée en circulation : elle repasse en planifiée.
  /// Refusé par le serveur si la période est clôturée.
  Future<Either<Failure, Maintenance>> restaurerMaintenance(int id);
  Future<Either<Failure, Maintenance>> completeMaintenance(
    int id,
    double cout, {
    bool aCredit,
    DateTime? dateEcheance,
  });
}

import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/page_result.dart';
import '../entities/maintenance.dart';
import '../entities/synthese_maintenances.dart';

abstract interface class MaintenanceRepository {
  Future<Either<Failure, List<Maintenance>>> getMaintenances({
    String? dateDebut,
    String? dateFin,
    String? statut,
    int? vehiculeId,
  });

  /// [recherche] : mot-clé libre confronté côté serveur au type de maintenance,
  /// au nom des éléments, à l'immatriculation du véhicule et au nom du
  /// prestataire.
  /// [categorieTypeIds] : types retenus, vide pour tous. [enRetard] : seules
  /// les planifiées dont la date prévue est passée.
  Future<Either<Failure, PageResult<Maintenance>>> getMaintenancesPage({
    int page,
    int size,
    String? dateDebut,
    String? dateFin,
    String? statut,
    int? vehiculeId,
    String? recherche,
    List<int> categorieTypeIds,
    bool enRetard,
  });

  /// Compteurs de la page Maintenances sur la même sélection que la liste,
  /// sans le statut : ils servent à le choisir.
  Future<Either<Failure, SyntheseMaintenances>> getSynthese({
    String? dateDebut,
    String? dateFin,
    int? vehiculeId,
    String? recherche,
    List<int> categorieTypeIds,
  });
  Future<Either<Failure, Maintenance>> getMaintenanceById(int id);
  /// Planifie une intervention. Si sa date prévue est passée, le serveur la
  /// termine aussitôt : [aCredit] et [dateEcheance] disent alors comment elle
  /// est réglée — sinon ils n'ont pas d'objet.
  Future<Either<Failure, Maintenance>> createMaintenance(
    Maintenance maintenance, {
    bool aCredit,
    DateTime? dateEcheance,
  });
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

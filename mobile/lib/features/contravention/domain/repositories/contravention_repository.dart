import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/page_result.dart';
import '../entities/contravention.dart';

abstract interface class ContraventionRepository {
  Future<Either<Failure, List<Contravention>>> getContraventions();

  /// [recherche] : mot-clé libre confronté côté serveur à l'immatriculation du
  /// véhicule, au nom/prénom du chauffeur et au numéro de contravention.
  Future<Either<Failure, PageResult<Contravention>>> getContraventionsPage({
    int page,
    int size,
    int? chauffeurId,
    int? vehiculeId,
    String? dateDebut,
    String? dateFin,
    String? recherche,
  });
  Future<Either<Failure, Contravention>> getContraventionById(int id);
  Future<Either<Failure, Contravention>> createContravention(
      Contravention contravention);
  Future<Either<Failure, Contravention>> updateContravention(
      int id, Contravention contravention);
  Future<Either<Failure, void>> deleteContravention(int id);
  Future<Either<Failure, Contravention>> payContravention(
      int id, double montantPaye);

  /// Reverse la contravention à l'État (crée l'opération de reversement).
  Future<Either<Failure, Contravention>> reverserContravention(int id);

  /// Annule la contravention : elle reste au registre, motif à l'appui.
  Future<Either<Failure, Contravention>> annulerContravention(
      int id, String motif);

  /// Remet une contravention annulée en circulation : elle retrouve le statut
  /// que dicte ce qui a été versé. Refusé par le serveur si la période est
  /// clôturée.
  Future<Either<Failure, Contravention>> restaurerContravention(int id);
}

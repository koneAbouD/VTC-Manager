import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/page_result.dart';
import '../entities/encaissement.dart';
import '../entities/ligne_recette.dart';
import '../../../../core/models/apercu_reaffectation.dart';
import '../../../../core/models/encaissement_lot.dart';

abstract interface class LigneRecetteRepository {
  Future<Either<Failure, List<LigneRecette>>> getLignes({
    int? vehiculeId,
    int? chauffeurId,
    StatutLigneRecette? statut,
    DateTime? dateDebut,
    DateTime? dateFin,
  });

  /// [recherche] : mot-clé libre confronté côté serveur à l'immatriculation du
  /// véhicule et au nom/prénom du chauffeur.
  Future<Either<Failure, PageResult<LigneRecette>>> getLignesPage({
    int page,
    int size,
    int? vehiculeId,
    int? chauffeurId,
    StatutLigneRecette? statut,
    DateTime? dateDebut,
    DateTime? dateFin,
    String? recherche,
  });

  Future<Either<Failure, LigneRecette>> getLigneById(int id);

  Future<Either<Failure, Encaissement>> createEncaissement(
    int ligneId,
    Encaissement encaissement,
  );

  /// Encaisse plusieurs lignes d'un seul versement : mode, date et commentaire
  /// communs, un montant par ligne. Le lot n'est pas un tout ou rien — la
  /// réponse porte le verdict de chaque ligne, motif compris.
  Future<Either<Failure, ResultatEncaissementLot>> createEncaissementsLot({
    required List<MontantLigne> lignes,
    required ModeEncaissement modeEncaissement,
    required DateTime dateEncaissement,
    String? reference,
    String? commentaire,
  });

  Future<Either<Failure, LigneRecette>> annuler(int id, String motif);

  /// Remet une ligne annulée en circulation : elle retrouve le statut que
  /// dictent ses versements. Refusé par le serveur si la période est clôturée.
  /// Ce qu'il faut savoir avant de déplacer la créance : les chauffeurs
  /// jugés par le serveur, et les impacts réels du déplacement.
  Future<Either<Failure, ApercuReaffectation>> getApercuReaffectation(int id);

  /// Porte la créance au compte d'un autre chauffeur : la ligne, ses écritures
  /// d'encaissement et la pénalité qu'elle a pu engendrer changent de débiteur.
  /// Aucun montant ne bouge. Refusé par le serveur si un arrêté l'a consignée,
  /// si les livres du jour sont fermés, ou si le chauffeur visé conduisait un
  /// autre véhicule ce jour-là.
  Future<Either<Failure, LigneRecette>> reaffecterChauffeur(
    int id,
    int chauffeurId,
    String motif,
  );

  /// Corrige le jour d'un versement déjà enregistré : l'encaissement et
  /// l'écriture qu'il a produite au journal changent de date ensemble. Aucun
  /// montant ne bouge. Refusé par le serveur si un arrêté a consigné la ligne,
  /// si la période est close, si la caisse a été comptée à l'une des deux
  /// dates, ou si le versement a été extourné.
  Future<Either<Failure, LigneRecette>> modifierDateEncaissement(
    int ligneId,
    int encaissementId,
    DateTime date,
  );

  Future<Either<Failure, LigneRecette>> restaurer(int id);

  Future<Either<Failure, LigneRecette>> confirmerVersement(int id);

  Future<Either<Failure, List<LigneRecette>>> generer({DateTime? date});
}

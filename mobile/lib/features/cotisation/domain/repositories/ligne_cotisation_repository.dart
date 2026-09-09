import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/page_result.dart';
import '../entities/encaissement_cotisation.dart';
import '../entities/ligne_cotisation.dart';
import '../entities/ligne_cotisation_filtres.dart';
import '../entities/totaux_cotisation.dart';
import '../../../../core/models/apercu_reaffectation.dart';
import '../../../../core/models/encaissement_lot.dart';

abstract interface class LigneCotisationRepository {
  Future<Either<Failure, List<LigneCotisation>>> getLignes(LigneCotisationFiltres filtres);
  Future<Either<Failure, PageResult<LigneCotisation>>> getLignesPage(
      LigneCotisationFiltres filtres, {int page, int size});
  /// Cumuls de la sélection, calculés par le serveur sur toutes les lignes et
  /// non sur les pages chargées. Le statut des filtres est ignoré : ces
  /// montants servent justement à en choisir un.
  Future<Either<Failure, TotauxCotisation>> getTotaux(LigneCotisationFiltres filtres);
  Future<Either<Failure, LigneCotisation>> getLigneById(int id);
  Future<Either<Failure, EncaissementCotisation>> createEncaissement(int ligneId, EncaissementCotisation enc);
  /// Encaisse plusieurs lignes d'un seul versement : mode, date et commentaire
  /// communs, un montant par ligne. Le lot n'est pas un tout ou rien — la
  /// réponse porte le verdict de chaque ligne, motif compris.
  Future<Either<Failure, ResultatEncaissementLot>> createEncaissementsLot({
    required List<MontantLigne> lignes,
    required ModePaiementCotisation modeEncaissement,
    required DateTime dateEncaissement,
    String? reference,
    String? commentaire,
  });

  Future<Either<Failure, LigneCotisation>> annuler(int id, String motif);

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
  Future<Either<Failure, LigneCotisation>> reaffecterChauffeur(
    int id,
    int chauffeurId,
    String motif,
  );

  /// Corrige le jour d'un versement déjà enregistré : l'encaissement et
  /// l'écriture qu'il a produite au journal changent de date ensemble. Aucun
  /// montant ne bouge. Refusé par le serveur si un arrêté a consigné la ligne,
  /// si la période est close, si la caisse a été comptée à l'une des deux
  /// dates, ou si le versement a été extourné.
  Future<Either<Failure, LigneCotisation>> modifierDateEncaissement(
    int ligneId,
    int encaissementId,
    DateTime date,
  );

  Future<Either<Failure, LigneCotisation>> restaurer(int id);
  Future<Either<Failure, List<LigneCotisation>>> generer({DateTime? date});
}

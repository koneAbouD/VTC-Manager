import 'ligne_penalite.dart';

class LignePenaliteFiltres {
  final int? vehiculeId;
  final int? chauffeurId;
  final TypeSanctionLigne? typeSanction;
  final StatutLignePenalite? statut;
  final DateTime? dateDebut;
  final DateTime? dateFin;

  /// Mot-clé libre : immatriculation du véhicule ou nom/prénom du chauffeur.
  /// Évalué côté serveur, sur l'ensemble des lignes et non la page chargée.
  final String? recherche;

  const LignePenaliteFiltres({
    this.vehiculeId,
    this.chauffeurId,
    this.typeSanction,
    this.statut,
    this.dateDebut,
    this.dateFin,
    this.recherche,
  });
}

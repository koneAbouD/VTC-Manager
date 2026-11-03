import 'ligne_cotisation.dart';

class LigneCotisationFiltres {
  final int? vehiculeId;
  final int? chauffeurId;
  final StatutLigneCotisation? statut;

  /// Plusieurs statuts à la fois (liste paginée) ; vide = tous.
  final Set<StatutLigneCotisation> statuts;
  final DateTime? dateDebut;
  final DateTime? dateFin;

  /// Mot-clé libre : immatriculation du véhicule ou nom/prénom du chauffeur.
  /// Évalué côté serveur, sur l'ensemble des lignes et non la page chargée.
  final String? recherche;

  const LigneCotisationFiltres({
    this.vehiculeId,
    this.chauffeurId,
    this.statut,
    this.statuts = const {},
    this.dateDebut,
    this.dateFin,
    this.recherche,
  });
}

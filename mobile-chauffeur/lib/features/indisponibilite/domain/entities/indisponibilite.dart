/// Indisponibilité déclarée par le chauffeur (congé, maladie…).
class Indisponibilite {
  final int? id;
  final String? dateDebut;
  final String? dateFin;
  final String? motif;
  final String? commentaire;
  final String? statut; // PLANIFIEE, EN_COURS, TERMINEE, ANNULEE
  final String? remplacantNom;

  const Indisponibilite({
    this.id,
    this.dateDebut,
    this.dateFin,
    this.motif,
    this.commentaire,
    this.statut,
    this.remplacantNom,
  });

  bool get estEnCours => (statut ?? '').toUpperCase() == 'EN_COURS';
  bool get estTerminable {
    final s = (statut ?? '').toUpperCase();
    return s == 'EN_COURS' || s == 'PLANIFIEE';
  }
}

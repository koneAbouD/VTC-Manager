/// Recette (ligne) telle que consultée par le chauffeur.
class LigneRecette {
  final int id;
  final String? date;
  final double? montantAttendu;
  final double? montantRestant;
  final String? statut;

  const LigneRecette({
    required this.id,
    this.date,
    this.montantAttendu,
    this.montantRestant,
    this.statut,
  });

  bool get estAnnulee => (statut ?? '').toUpperCase() == 'ANNULEE';
  bool get resteAPayer => !estAnnulee && (montantRestant ?? 0) > 0;
}

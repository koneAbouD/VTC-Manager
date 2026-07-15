/// Cotisation (ligne) telle que consultée par le chauffeur.
class LigneCotisation {
  final int id;
  final String? date;
  final String? nom;
  final double? montantDu;
  final double? montantRestant;
  final String? statut;

  const LigneCotisation({
    required this.id,
    this.date,
    this.nom,
    this.montantDu,
    this.montantRestant,
    this.statut,
  });

  bool get estAnnulee => (statut ?? '').toUpperCase() == 'ANNULEE';
  bool get resteAPayer => !estAnnulee && (montantRestant ?? 0) > 0;
}

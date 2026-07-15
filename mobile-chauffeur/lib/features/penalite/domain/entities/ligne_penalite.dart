/// Pénalité / amende consultée par le chauffeur.
class LignePenalite {
  final int id;
  final String? date;
  final String? type;
  final String? typeSanction;
  final double? montant;
  final double? montantRestant;
  final String? statut;

  const LignePenalite({
    required this.id,
    this.date,
    this.type,
    this.typeSanction,
    this.montant,
    this.montantRestant,
    this.statut,
  });
}

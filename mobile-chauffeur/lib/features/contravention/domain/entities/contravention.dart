/// Contravention (infraction routière) consultée par le chauffeur.
class Contravention {
  final int id;
  final String? date;
  final String? type;
  final String? lieu;
  final double? montant;
  final double? montantPaye;
  final String? statut;

  const Contravention({
    required this.id,
    this.date,
    this.type,
    this.lieu,
    this.montant,
    this.montantPaye,
    this.statut,
  });
}

/// Opération financière liée au chauffeur ou à son véhicule.
class OperationFinanciere {
  final int id;
  final String? libelle;
  final double? montant;
  final bool isRevenu;
  final String? date;
  final String? vehicule;
  final String? chauffeur;
  final String? statut;

  const OperationFinanciere({
    required this.id,
    this.libelle,
    this.montant,
    this.isRevenu = true,
    this.date,
    this.vehicule,
    this.chauffeur,
    this.statut,
  });

  bool get estAnnulee => (statut ?? '').toUpperCase() == 'ANNULEE';
}

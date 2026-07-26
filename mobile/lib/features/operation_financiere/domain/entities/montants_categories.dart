/// Montant total par « catégorie » (buckets UI de la page Opérations) pour les
/// filtres courants hors filtre catégorie — alimente les info-bulles des chips.
class MontantsCategories {
  final double total;
  final double recette;
  final double cotisation;
  final double penalite;
  final double maintenance;
  final double document;

  const MontantsCategories({
    this.total = 0,
    this.recette = 0,
    this.cotisation = 0,
    this.penalite = 0,
    this.maintenance = 0,
    this.document = 0,
  });

  static const zero = MontantsCategories();

  factory MontantsCategories.fromJson(Map<String, dynamic> j) =>
      MontantsCategories(
        total: (j['total'] as num?)?.toDouble() ?? 0,
        recette: (j['recette'] as num?)?.toDouble() ?? 0,
        cotisation: (j['cotisation'] as num?)?.toDouble() ?? 0,
        penalite: (j['penalite'] as num?)?.toDouble() ?? 0,
        maintenance: (j['maintenance'] as num?)?.toDouble() ?? 0,
        document: (j['document'] as num?)?.toDouble() ?? 0,
      );
}

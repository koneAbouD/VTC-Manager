class CatalogueElementMaintenance {
  final int id;
  final String libelle;
  final bool actif;

  /// Montant pré-rempli à la sélection dans une opération de maintenance.
  final double? montantDefaut;

  /// URL présignée de l'image d'illustration (facultative).
  final String? imageUrl;

  const CatalogueElementMaintenance({
    required this.id,
    required this.libelle,
    required this.actif,
    this.montantDefaut,
    this.imageUrl,
  });
}

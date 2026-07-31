class ElementMaintenance {
  final int? id;
  final int? catalogueElementId;
  final String? catalogueElementLibelle;
  final String? libelle;

  /// Exemplaires posés. Toujours ≥ 1 : une ligne muette vaut une pièce.
  final int quantite;

  /// TOTAL de la ligne — quantité × prix unitaire, pas le prix d'un
  /// exemplaire. C'est ce champ que somment le coût de l'intervention et la
  /// répartition des dettes.
  final double montant;

  /// Fournisseur de la ligne. Null = le partenaire de l'intervention, cas
  /// courant où un seul prestataire fait tout.
  final int? partenaireId;
  final String? partenaireNom;

  const ElementMaintenance({
    this.id,
    this.catalogueElementId,
    this.catalogueElementLibelle,
    this.libelle,
    this.quantite = 1,
    required this.montant,
    this.partenaireId,
    this.partenaireNom,
  });

  String get effectiveLibelle => catalogueElementLibelle ?? libelle ?? '';

  /// Prix d'un exemplaire. Retrouvé par division plutôt que stocké : le total
  /// est la seule valeur qui fait foi, deux champs finiraient par diverger.
  double get prixUnitaire => quantite > 0 ? montant / quantite : montant;

  /// Libellé tel qu'on le lit dans une liste : « Pneu avant × 4 ». Le nombre
  /// n'apparaît qu'à partir de deux — « × 1 » n'apprendrait rien.
  String get libelleAvecQuantite =>
      quantite > 1 ? '$effectiveLibelle × $quantite' : effectiveLibelle;
}

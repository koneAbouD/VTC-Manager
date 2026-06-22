class ElementMaintenance {
  final int? id;
  final int? catalogueElementId;
  final String? catalogueElementLibelle;
  final String? libelle;
  final double montant;

  const ElementMaintenance({
    this.id,
    this.catalogueElementId,
    this.catalogueElementLibelle,
    this.libelle,
    required this.montant,
  });

  String get effectiveLibelle => catalogueElementLibelle ?? libelle ?? '';
}

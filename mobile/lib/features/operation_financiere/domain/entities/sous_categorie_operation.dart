class SousCategorieOperation {
  final int id;
  final String code;
  final String libelle;
  final int categorieId;
  final String? categorieLibelle;
  final bool actif;

  const SousCategorieOperation({
    required this.id,
    required this.code,
    required this.libelle,
    required this.categorieId,
    this.categorieLibelle,
    required this.actif,
  });
}

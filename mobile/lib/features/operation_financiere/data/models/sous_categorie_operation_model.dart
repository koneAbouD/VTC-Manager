import '../../domain/entities/sous_categorie_operation.dart';

class SousCategorieOperationModel extends SousCategorieOperation {
  const SousCategorieOperationModel({
    required super.id,
    required super.code,
    required super.libelle,
    required super.categorieId,
    required super.categorieLibelle,
    required super.actif,
  });

  factory SousCategorieOperationModel.fromJson(Map<String, dynamic> json) {
    // Format imbriqué (includeSousCategorie=true) : categorieId direct
    // Format liste indépendante : categorie: { id, libelle }
    final cat = json['categorie'] as Map<String, dynamic>?;
    final categorieId = json['categorieId'] as int?
        ?? cat?['id'] as int?
        ?? 0;
    final categorieLibelle = cat?['libelle'] as String?;
    return SousCategorieOperationModel(
      id: json['id'] as int,
      code: json['code'] as String,
      libelle: json['libelle'] as String,
      categorieId: categorieId,
      categorieLibelle: categorieLibelle,
      actif: json['actif'] as bool? ?? true,
    );
  }
}

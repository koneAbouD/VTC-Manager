import '../../domain/entities/categorie_operation.dart';
import '../../domain/enums/type_operation.dart';
import 'sous_categorie_operation_model.dart';

class CategorieOperationModel extends CategorieOperation {
  const CategorieOperationModel({
    required super.id,
    required super.code,
    required super.libelle,
    required super.typeOperation,
    required super.actif,
    super.sousCategorie,
  });

  factory CategorieOperationModel.fromJson(Map<String, dynamic> json) {
    final scJson = json['sousCategorie'] as Map<String, dynamic>?;
    return CategorieOperationModel(
      id: json['id'] as int,
      code: json['code'] as String,
      libelle: json['libelle'] as String,
      typeOperation:
          TypeOperationExt.fromString(json['typeOperation'] as String),
      actif: json['actif'] as bool? ?? true,
      sousCategorie: scJson != null
          ? SousCategorieOperationModel.fromJson(scJson)
          : null,
    );
  }
}

import '../enums/type_operation.dart';
import 'sous_categorie_operation.dart';

class CategorieOperation {
  final int id;
  final String code;
  final String libelle;
  final TypeOperation typeOperation;
  final bool actif;
  final SousCategorieOperation? sousCategorie;

  const CategorieOperation({
    required this.id,
    required this.code,
    required this.libelle,
    required this.typeOperation,
    required this.actif,
    this.sousCategorie,
  });
}

import 'detail_maintenance.dart';
import '../enums/mode_paiement.dart';
import '../enums/statut_operation.dart';
import '../enums/type_operation.dart';

class OperationFinanciere {
  final int? id;
  final String? reference;
  final TypeOperation typeOperation;
  final int? categorieId;
  final String? categorieCode;
  final String? categorieLibelle;
  final int? sousCategorieId;
  final String? sousCategorieLibelle;
  final String? sousCategorieCode;
  final int? chauffeurId;
  final String? chauffeurNom;
  final int? vehiculeId;
  final String? vehiculeNom;
  final double montant;
  final ModePaiement? modePaiement;
  final DateTime dateOperation;
  final String? commentaire;
  final StatutOperation statut;
  final DetailMaintenance? detailMaintenance;

  const OperationFinanciere({
    this.id,
    this.reference,
    required this.typeOperation,
    this.categorieId,
    this.categorieCode,
    this.categorieLibelle,
    this.sousCategorieId,
    this.sousCategorieLibelle,
    this.sousCategorieCode,
    this.chauffeurId,
    this.chauffeurNom,
    this.vehiculeId,
    this.vehiculeNom,
    required this.montant,
    this.modePaiement,
    required this.dateOperation,
    this.commentaire,
    this.statut = StatutOperation.BROUILLON,
    this.detailMaintenance,
  });

  /// Vrai si l'opération appartient au groupe "Maintenances"
  /// (déterminé par le libellé de la sous-catégorie côté backend,
  ///  sans dépendre d'un code de catégorie figé).
  bool get isMaintenance =>
      sousCategorieLibelle?.toLowerCase() == 'maintenances';
}

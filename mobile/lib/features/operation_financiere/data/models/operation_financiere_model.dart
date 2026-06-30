import '../../domain/entities/operation_financiere.dart';
import '../../domain/enums/mode_paiement.dart';
import '../../domain/enums/statut_operation.dart';
import '../../domain/enums/type_operation.dart';
import 'detail_maintenance_model.dart';

class OperationFinanciereModel extends OperationFinanciere {
  const OperationFinanciereModel({
    super.id,
    super.reference,
    required super.typeOperation,
    super.categorieId,
    super.categorieCode,
    super.categorieLibelle,
    super.sousCategorieId,
    super.sousCategorieLibelle,
    super.sousCategorieCode,
    super.chauffeurId,
    super.chauffeurNom,
    super.vehiculeId,
    super.vehiculeNom,
    required super.montant,
    super.modePaiement,
    required super.dateOperation,
    super.dateReference,
    super.commentaire,
    super.statut,
    super.detailMaintenance,
  });

  factory OperationFinanciereModel.fromJson(Map<String, dynamic> json) {
    final cat = json['categorie'] as Map<String, dynamic>?;
    // sousCategorie peut être au premier niveau (opération manuelle)
    // ou seulement via categorie.sousCategorie (opérations auto-générées).
    final sousCat = (json['sousCategorie'] as Map<String, dynamic>?)
        ?? (cat?['sousCategorie'] as Map<String, dynamic>?);
    final chauffeur = json['chauffeur'] as Map<String, dynamic>?;
    final vehicule = json['vehicule'] as Map<String, dynamic>?;
    final dm = json['detailMaintenance'] as Map<String, dynamic>?;

    // ChauffeurResponse : champs 'prenom' et 'nom' directs
    final prenom = chauffeur?['prenom'] as String? ?? '';
    final nom = chauffeur?['nom'] as String? ?? '';
    final chauffeurNom = '$prenom $nom'.trim();

    // VehiculeResponse expose l'immatriculation (ex: "AA-123-BB"), pas de
    // champ 'libelle' → on lit 'immatriculation', avec repli sur 'libelle'
    // au cas où un autre endpoint le fournirait.
    final vehiculeNom = (vehicule?['immatriculation'] as String?) ??
        (vehicule?['libelle'] as String?);

    final mpStr = json['modePaiement'] as String?;
    final statutStr = json['statut'] as String? ?? 'ENCAISSE';

    return OperationFinanciereModel(
      id: (json['id'] as num?)?.toInt(),
      reference: json['reference'] as String?,
      typeOperation:
          TypeOperationExt.fromString(json['typeOperation'] as String),
      categorieId: (cat?['id'] as num?)?.toInt(),
      categorieCode: cat?['code'] as String?,
      categorieLibelle: cat?['libelle'] as String?,
      sousCategorieId: (sousCat?['id'] as num?)?.toInt(),
      sousCategorieLibelle: sousCat?['libelle'] as String?,
      sousCategorieCode: sousCat?['code'] as String?,
      chauffeurId: (chauffeur?['id'] as num?)?.toInt(),
      chauffeurNom: chauffeurNom.isEmpty ? null : chauffeurNom,
      vehiculeId: (vehicule?['id'] as num?)?.toInt(),
      vehiculeNom: vehiculeNom?.isEmpty == true ? null : vehiculeNom,
      montant: (json['montant'] as num? ?? 0).toDouble(),
      modePaiement:
          mpStr != null ? ModePaiementExt.fromString(mpStr) : null,
      dateOperation: DateTime.parse(json['dateOperation'] as String),
      dateReference: json['dateReference'] != null
          ? DateTime.tryParse(json['dateReference'] as String)
          : null,
      commentaire: json['commentaire'] as String?,
      statut: StatutOperationExt.fromString(statutStr),
      detailMaintenance:
          dm != null ? DetailMaintenanceModel.fromJson(dm) : null,
    );
  }
}

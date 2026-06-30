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

  /// Date "métier" de référence (date de la période concernée pour un
  /// encaissement : recette / cotisation / faute). Null pour les autres
  /// opérations → on retombe sur [dateOperation].
  final DateTime? dateReference;
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
    this.dateReference,
    this.commentaire,
    this.statut = StatutOperation.ENCAISSE,
    this.detailMaintenance,
  });

  /// Date à afficher sur les lignes d'opération : la date métier si présente
  /// (encaissement de période), sinon la date de l'opération.
  DateTime get dateAffichee => dateReference ?? dateOperation;

  /// Connecteur de date relatif, recalculé à CHAQUE affichage (donc « hier »
  /// devient « avant-hier » le lendemain, etc.) — aucune tâche planifiée requise :
  ///   aujourd'hui   → "d'aujourd'hui"
  ///   hier          → "d'hier"
  ///   avant-hier    → "d'avant-hier"
  ///   au-delà       → "du JJ/MM/AAAA"
  /// Destiné à suffixer un libellé, ex. « Encaissement recettes d'hier ».
  String get libelleDateRelative {
    final d = dateAffichee;
    final jour = DateTime(d.year, d.month, d.day);
    final maintenant = DateTime.now();
    final aujourdhui = DateTime(maintenant.year, maintenant.month, maintenant.day);
    final ecartJours = aujourdhui.difference(jour).inDays;
    String deux(int n) => n.toString().padLeft(2, '0');
    return switch (ecartJours) {
      0 => "d'aujourd'hui",
      1 => "d'hier",
      2 => "d'avant-hier",
      _ => 'du ${deux(d.day)}/${deux(d.month)}/${d.year}',
    };
  }

  /// Vrai si l'opération appartient au groupe "Maintenances"
  /// (déterminé par le libellé de la sous-catégorie côté backend,
  ///  sans dépendre d'un code de catégorie figé).
  bool get isMaintenance =>
      sousCategorieLibelle?.toLowerCase() == 'maintenances';
}

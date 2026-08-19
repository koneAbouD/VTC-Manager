import '../../../../core/utils/libelle_operation.dart' as date_relative;
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

  /// Tiers de l'écriture : garage, assureur, bailleur… Facultatif.
  final int? partenaireId;
  final String? partenaireNom;
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

  /// Écriture contre-passée par celle-ci : non nul sur une extourne, dont le
  /// montant est l'opposé de l'origine.
  final int? extourneDeId;

  /// Renseignés sur une écriture qui a été extournée.
  final DateTime? annuleLe;
  final String? motifAnnulation;

  /// Faux pour une écriture que le backend refuse de retoucher en place :
  /// encaissement (recette, cotisation, pénalité, contravention), dépense issue
  /// d'une maintenance, extourne ou écriture déjà extournée. L'action
  /// « Modifier » est alors masquée ; l'annulation, elle, reste ouverte.
  final bool modifiable;

  /// Faux quand le backend refuserait la contre-passation : écriture déjà
  /// corrigée (extourne, écriture extournée ou annulée), ou arrêté — période
  /// comptable close, caisse comptée — couvrant sa date. Le bouton « Annuler »
  /// est alors masqué. La règle est tenue côté serveur : ne pas la redéduire
  /// ici, les deux versions divergeraient.
  ///
  /// Faux par défaut quand la réponse ne porte pas le drapeau : en l'absence
  /// d'information, on ne propose pas une action qui pourrait être refusée.
  final bool annulable;

  /// Cette écriture est une contre-passation.
  bool get estUneExtourne => extourneDeId != null;

  /// Cette écriture a été contre-passée : elle reste au journal, neutralisée.
  bool get estExtournee => annuleLe != null;

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
    this.partenaireId,
    this.partenaireNom,
    required this.montant,
    this.modePaiement,
    required this.dateOperation,
    this.dateReference,
    this.commentaire,
    this.statut = StatutOperation.ENCAISSE,
    this.detailMaintenance,
    this.extourneDeId,
    this.annuleLe,
    this.motifAnnulation,
    this.modifiable = false,
    this.annulable = false,
  });

  /// Date à afficher sur les lignes d'opération : la date métier si présente
  /// (encaissement de période), sinon la date de l'opération.
  DateTime get dateAffichee => dateReference ?? dateOperation;

  /// Connecteur de date relatif de la date métier, ex. « d'hier ».
  /// Voir [libelleDateRelative] (partagé avec le rapport financier).
  String get libelleDateRelative => date_relative.libelleDateRelative(dateAffichee);

  /// Vrai si l'opération appartient au groupe "Maintenances"
  /// (déterminé par le libellé de la sous-catégorie côté backend,
  ///  sans dépendre d'un code de catégorie figé).
  bool get isMaintenance =>
      sousCategorieLibelle?.toLowerCase() == 'maintenances';

  /// Vrai si l'opération est un encaissement (recette / cotisation / pénalité).
  /// Seuls ces types conservent la date relative dans leur libellé de ligne ;
  /// les autres opérations (dépenses, maintenance…) s'affichent sans date.
  bool get estEncaissement =>
      date_relative.estCategorieEncaissement(categorieCode);

  /// Libellé du titre affiché sur les lignes d'opération (Accueil, liste des
  /// opérations, rapport financier) : « Catégorie d'hier » pour un
  /// encaissement, « Catégorie » seul sinon.
  String get libelleLigne => date_relative.libelleLigneOperation(
        categorieCode: categorieCode,
        categorie: categorieLibelle ?? typeOperation.libelle,
        date: dateAffichee,
      );
}

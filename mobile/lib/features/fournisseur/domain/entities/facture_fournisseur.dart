/// Où en est le règlement d'une facture reçue.
enum StatutFacture {
  aPayer,
  partiellementPayee,
  payee,
  annulee;

  static StatutFacture fromJson(String? v) => switch (v) {
        'A_PAYER' => aPayer,
        'PARTIELLEMENT_PAYEE' => partiellementPayee,
        'PAYEE' => payee,
        'ANNULEE' => annulee,
        _ => aPayer,
      };

  String get label => switch (this) {
        aPayer => 'À payer',
        partiellementPayee => 'Partiellement payée',
        payee => 'Payée',
        annulee => 'Annulée',
      };

  /// Vrai tant que la facture pèse sur la dette.
  bool get estOuverte => this == aPayer || this == partiellementPayee;
}

/// Facture reçue d'un fournisseur : c'est elle qui porte la charge, à sa date.
class FactureFournisseur {
  final int? id;
  final String? reference;
  final int? fournisseurId;
  final String? fournisseurNom;
  final String? numeroPiece;
  final int? categorieId;
  final String? categorieLibelle;
  final int? vehiculeId;
  final String? vehiculeImmatriculation;
  final DateTime dateFacture;
  final DateTime dateEcheance;
  final double montant;
  final double montantPaye;

  /// Ce qui reste à payer.
  final double restantDu;
  final StatutFacture statut;

  /// Échue et non soldée.
  final bool enRetard;
  final String? description;
  final String? motifAnnulation;

  const FactureFournisseur({
    this.id,
    this.reference,
    this.fournisseurId,
    this.fournisseurNom,
    this.numeroPiece,
    this.categorieId,
    this.categorieLibelle,
    this.vehiculeId,
    this.vehiculeImmatriculation,
    required this.dateFacture,
    required this.dateEcheance,
    required this.montant,
    this.montantPaye = 0,
    this.restantDu = 0,
    this.statut = StatutFacture.aPayer,
    this.enRetard = false,
    this.description,
    this.motifAnnulation,
  });

  factory FactureFournisseur.fromJson(Map<String, dynamic> j) =>
      FactureFournisseur(
        id: (j['id'] as num?)?.toInt(),
        reference: j['reference'] as String?,
        fournisseurId: (j['fournisseurId'] as num?)?.toInt(),
        fournisseurNom: j['fournisseurNom'] as String?,
        numeroPiece: j['numeroPiece'] as String?,
        categorieId: (j['categorieId'] as num?)?.toInt(),
        categorieLibelle: j['categorieLibelle'] as String?,
        vehiculeId: (j['vehiculeId'] as num?)?.toInt(),
        vehiculeImmatriculation: j['vehiculeImmatriculation'] as String?,
        dateFacture: DateTime.parse(j['dateFacture'] as String),
        dateEcheance: DateTime.parse(j['dateEcheance'] as String),
        montant: (j['montant'] as num?)?.toDouble() ?? 0,
        montantPaye: (j['montantPaye'] as num?)?.toDouble() ?? 0,
        restantDu: (j['restantDu'] as num?)?.toDouble() ?? 0,
        statut: StatutFacture.fromJson(j['statut'] as String?),
        enRetard: j['enRetard'] as bool? ?? false,
        description: j['description'] as String?,
        motifAnnulation: j['motifAnnulation'] as String?,
      );

  /// Jours de retard sur l'échéance, 0 si la facture n'est pas en retard.
  int joursDeRetard(DateTime maintenant) {
    if (!enRetard) return 0;
    final jour = DateTime(maintenant.year, maintenant.month, maintenant.day);
    final echeance =
        DateTime(dateEcheance.year, dateEcheance.month, dateEcheance.day);
    return jour.difference(echeance).inDays;
  }
}

/// Un règlement déjà passé sur une facture.
class ReglementFacture {
  final int? operationId;
  final String? reference;
  final DateTime date;
  final double montant;
  final String? modePaiement;
  final String? commentaire;

  /// Règlement contre-passé : il ne compte plus dans le restant dû.
  final bool extourne;

  const ReglementFacture({
    this.operationId,
    this.reference,
    required this.date,
    required this.montant,
    this.modePaiement,
    this.commentaire,
    this.extourne = false,
  });

  factory ReglementFacture.fromJson(Map<String, dynamic> j) => ReglementFacture(
        operationId: (j['operationId'] as num?)?.toInt(),
        reference: j['reference'] as String?,
        date: DateTime.parse(j['date'] as String),
        montant: (j['montant'] as num?)?.toDouble() ?? 0,
        modePaiement: j['modePaiement'] as String?,
        commentaire: j['commentaire'] as String?,
        extourne: j['extourne'] as bool? ?? false,
      );
}

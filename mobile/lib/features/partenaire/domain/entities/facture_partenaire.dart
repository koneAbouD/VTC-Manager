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

/// Un poste couvert par une dette : l'élément de maintenance et sa part.
class LigneDette {
  final String libelle;
  final double montant;

  const LigneDette({required this.libelle, required this.montant});

  factory LigneDette.fromJson(Map<String, dynamic> j) => LigneDette(
        libelle: j['libelle'] as String? ?? '',
        montant: (j['montant'] as num?)?.toDouble() ?? 0,
      );
}

/// Facture reçue d'un partenaire : c'est elle qui porte la charge, à sa date.
class FacturePartenaire {
  final int? id;
  final String? reference;
  final int? partenaireId;
  final String? partenaireNom;
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

  /// Intervention d'origine, quand la dette naît d'une maintenance.
  final int? maintenanceId;

  /// Ce que la dette paie, ligne à ligne. Vide pour une facture saisie.
  final List<LigneDette> lignes;

  const FacturePartenaire({
    this.id,
    this.reference,
    this.partenaireId,
    this.partenaireNom,
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
    this.maintenanceId,
    this.lignes = const [],
  });

  factory FacturePartenaire.fromJson(Map<String, dynamic> j) =>
      FacturePartenaire(
        id: (j['id'] as num?)?.toInt(),
        reference: j['reference'] as String?,
        partenaireId: (j['partenaireId'] as num?)?.toInt(),
        partenaireNom: j['partenaireNom'] as String?,
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
        maintenanceId: (j['maintenanceId'] as num?)?.toInt(),
        lignes: (j['lignes'] as List?)
                ?.map((e) => LigneDette.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );

  /// Jours de retard sur l'échéance, 0 si la facture n'est pas en retard.
  int joursDeRetard(DateTime maintenant) {
    if (!enRetard) return 0;
    final jour = DateTime(maintenant.year, maintenant.month, maintenant.day);
    final echeance =
        DateTime(dateEcheance.year, dateEcheance.month, dateEcheance.day);
    return jour.difference(echeance).inDays;
  }

  /// Vrai quand la dette vient d'un atelier plutôt que d'une facture reçue.
  bool get issueDeMaintenance => maintenanceId != null;
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

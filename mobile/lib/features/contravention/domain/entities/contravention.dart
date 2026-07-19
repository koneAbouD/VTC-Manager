class Contravention {
  final int? id;
  final DateTime dateInfraction;
  final String? typeInfraction;
  final String? lieu;
  final String? description;
  final double montant;
  final double? cotisation;
  final double? montantPaye;
  final String? statut;
  final DateTime? datePaiement;
  final int? chauffeurId;
  final String? chauffeurNom;
  final int? vehiculeId;
  final String? vehiculeNom;

  // ── Champs propres aux contraventions de l'État importées par PDF ──────────
  final String? numeroContravention;
  final String? heureInfraction; // "HH:mm:ss"
  final int? vitesseRelevee;
  final String? codeInfraction;
  final String? documentSourcePath;
  final String? statutRattachement; // AUTO | MANUEL | A_RATTACHER

  const Contravention({
    this.id,
    required this.dateInfraction,
    this.typeInfraction,
    this.lieu,
    this.description,
    required this.montant,
    this.cotisation,
    this.montantPaye,
    this.statut,
    this.datePaiement,
    this.chauffeurId,
    this.chauffeurNom,
    this.vehiculeId,
    this.vehiculeNom,
    this.numeroContravention,
    this.heureInfraction,
    this.vitesseRelevee,
    this.codeInfraction,
    this.documentSourcePath,
    this.statutRattachement,
  });

  bool get isPaid => statut == 'PAYEE' || statut == 'PAYE';
  bool get isPartial =>
      statut == 'PARTIELLEMENT_PAYEE' || statut == 'PARTIELLEMENT_PAYE';

  /// Reversée à l'État (opération « Reversement contravention » créée).
  bool get isReverse => statut == 'REVERSE' || statut == 'REVERSEE';

  /// Annulée.
  bool get isCancelled => statut == 'ANNULE' || statut == 'ANNULEE';

  /// Contravention soldée : plus aucun règlement ni reversement à effectuer.
  bool get isRegle => isPaid || isReverse || isCancelled;

  /// Vrai si la contravention n'a pas encore de chauffeur déterminé.
  bool get aRattacher =>
      statutRattachement == 'A_RATTACHER' || chauffeurId == null;

  Contravention copyWith({
    int? id,
    DateTime? dateInfraction,
    String? typeInfraction,
    String? lieu,
    String? description,
    double? montant,
    double? cotisation,
    double? montantPaye,
    String? statut,
    DateTime? datePaiement,
    int? chauffeurId,
    String? chauffeurNom,
    int? vehiculeId,
    String? vehiculeNom,
    String? numeroContravention,
    String? heureInfraction,
    int? vitesseRelevee,
    String? codeInfraction,
    String? documentSourcePath,
    String? statutRattachement,
  }) {
    return Contravention(
      id: id ?? this.id,
      dateInfraction: dateInfraction ?? this.dateInfraction,
      typeInfraction: typeInfraction ?? this.typeInfraction,
      lieu: lieu ?? this.lieu,
      description: description ?? this.description,
      montant: montant ?? this.montant,
      cotisation: cotisation ?? this.cotisation,
      montantPaye: montantPaye ?? this.montantPaye,
      statut: statut ?? this.statut,
      datePaiement: datePaiement ?? this.datePaiement,
      chauffeurId: chauffeurId ?? this.chauffeurId,
      chauffeurNom: chauffeurNom ?? this.chauffeurNom,
      vehiculeId: vehiculeId ?? this.vehiculeId,
      vehiculeNom: vehiculeNom ?? this.vehiculeNom,
      numeroContravention: numeroContravention ?? this.numeroContravention,
      heureInfraction: heureInfraction ?? this.heureInfraction,
      vitesseRelevee: vitesseRelevee ?? this.vitesseRelevee,
      codeInfraction: codeInfraction ?? this.codeInfraction,
      documentSourcePath: documentSourcePath ?? this.documentSourcePath,
      statutRattachement: statutRattachement ?? this.statutRattachement,
    );
  }
}

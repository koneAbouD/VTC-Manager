/// Solde de compte courant d'un tiers (chauffeur ou véhicule) : le fonds de
/// cotisation restituable face aux créances ouvertes, ventilées par antériorité.
/// net = fonds − créances (positif = en faveur du chauffeur).
class CompteCourant {
  final int tiersId;
  final String libelle;
  final double fondsCotisation;
  final double du0a7Jours;
  final double du8a30Jours;
  final double duPlus30Jours;
  final double totalCreances;
  final double net;

  const CompteCourant({
    required this.tiersId,
    required this.libelle,
    required this.fondsCotisation,
    required this.du0a7Jours,
    required this.du8a30Jours,
    required this.duPlus30Jours,
    required this.totalCreances,
    required this.net,
  });

  bool get estCrediteur => net > 0;

  factory CompteCourant.fromJson(Map<String, dynamic> j) => CompteCourant(
        tiersId: (j['tiersId'] as num).toInt(),
        libelle: j['libelle'] ?? '',
        fondsCotisation: (j['fondsCotisation'] as num?)?.toDouble() ?? 0,
        du0a7Jours: (j['du0a7Jours'] as num?)?.toDouble() ?? 0,
        du8a30Jours: (j['du8a30Jours'] as num?)?.toDouble() ?? 0,
        duPlus30Jours: (j['duPlus30Jours'] as num?)?.toDouble() ?? 0,
        totalCreances: (j['totalCreances'] as num?)?.toDouble() ?? 0,
        net: (j['net'] as num?)?.toDouble() ?? 0,
      );
}

/// Ligne snapshot d'un arrêté : cotisation (CREDIT) ou créance compensée (DEBIT).
class LigneArrete {
  final String document; // COTISATION | RECETTE | PENALITE | CONTRAVENTION
  final int documentId;
  final int? chauffeurId;
  final int? vehiculeId;
  final double montant;
  final String sens; // CREDIT | DEBIT

  const LigneArrete({
    required this.document,
    required this.documentId,
    this.chauffeurId,
    this.vehiculeId,
    required this.montant,
    required this.sens,
  });

  bool get estCredit => sens == 'CREDIT';

  factory LigneArrete.fromJson(Map<String, dynamic> j) => LigneArrete(
        document: j['document'] ?? '',
        documentId: (j['documentId'] as num).toInt(),
        chauffeurId: (j['chauffeurId'] as num?)?.toInt(),
        vehiculeId: (j['vehiculeId'] as num?)?.toInt(),
        montant: (j['montant'] as num?)?.toDouble() ?? 0,
        sens: j['sens'] ?? '',
      );
}

/// Règlement d'un arrêté pour un bénéficiaire chauffeur.
class ReglementArrete {
  final int chauffeurId;
  final String? chauffeurNom;
  final double totalCotisations;
  final double totalCreancesCompensees;
  final double montantNet;
  final double reliquatReporte;
  final String? modePaiement;
  final int? operationDecaissementId;

  const ReglementArrete({
    required this.chauffeurId,
    this.chauffeurNom,
    required this.totalCotisations,
    required this.totalCreancesCompensees,
    required this.montantNet,
    required this.reliquatReporte,
    this.modePaiement,
    this.operationDecaissementId,
  });

  bool get aRestitution => montantNet > 0;

  factory ReglementArrete.fromJson(Map<String, dynamic> j) => ReglementArrete(
        chauffeurId: (j['chauffeurId'] as num).toInt(),
        chauffeurNom: j['chauffeurNom'],
        totalCotisations: (j['totalCotisations'] as num?)?.toDouble() ?? 0,
        totalCreancesCompensees:
            (j['totalCreancesCompensees'] as num?)?.toDouble() ?? 0,
        montantNet: (j['montantNet'] as num?)?.toDouble() ?? 0,
        reliquatReporte: (j['reliquatReporte'] as num?)?.toDouble() ?? 0,
        modePaiement: j['modePaiement'],
        operationDecaissementId: (j['operationDecaissementId'] as num?)?.toInt(),
      );
}

/// Arrêté de compte : en-tête + lignes snapshot + règlements. Sert aussi à l'aperçu.
class ArreteCompte {
  final int? id;
  final String perimetre; // CHAUFFEUR | VEHICULE
  final int perimetreId;
  final String? perimetreLibelle;
  final DateTime periodeDebut;
  final DateTime periodeFin;
  final DateTime? dateArrete;
  final String? reference;
  final String? statut;
  final String? motifAnnulation;
  final double totalRestitue;
  final List<LigneArrete> lignes;
  final List<ReglementArrete> reglements;

  const ArreteCompte({
    this.id,
    required this.perimetre,
    required this.perimetreId,
    this.perimetreLibelle,
    required this.periodeDebut,
    required this.periodeFin,
    this.dateArrete,
    this.reference,
    this.statut,
    this.motifAnnulation,
    required this.totalRestitue,
    required this.lignes,
    required this.reglements,
  });

  bool get estAnnule => statut == 'ANNULE';

  /// Total des créances compensées, tous bénéficiaires confondus.
  double get totalCompense =>
      reglements.fold(0, (s, r) => s + r.totalCreancesCompensees);

  /// Total des reliquats reportés (créances non couvertes).
  double get totalReliquat =>
      reglements.fold(0, (s, r) => s + r.reliquatReporte);

  factory ArreteCompte.fromJson(Map<String, dynamic> j) => ArreteCompte(
        id: (j['id'] as num?)?.toInt(),
        perimetre: j['perimetre'] ?? 'CHAUFFEUR',
        perimetreId: (j['perimetreId'] as num).toInt(),
        perimetreLibelle: j['perimetreLibelle'],
        periodeDebut: DateTime.parse(j['periodeDebut'] as String),
        periodeFin: DateTime.parse(j['periodeFin'] as String),
        dateArrete: j['dateArrete'] != null
            ? DateTime.parse(j['dateArrete'] as String)
            : null,
        reference: j['reference'],
        statut: j['statut'],
        motifAnnulation: j['motifAnnulation'],
        totalRestitue: (j['totalRestitue'] as num?)?.toDouble() ?? 0,
        lignes: ((j['lignes'] as List?) ?? [])
            .map((e) => LigneArrete.fromJson(e as Map<String, dynamic>))
            .toList(),
        reglements: ((j['reglements'] as List?) ?? [])
            .map((e) => ReglementArrete.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

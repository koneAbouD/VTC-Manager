/// Compte de résultat de gestion en cascade (une période, une base).
class CompteResultatData {
  final int annee;
  final int mois;

  /// CAISSE | ENGAGEMENT
  final String base;
  final double produitsExploitation;
  final double chargesVariables;
  final double margeSurCoutsVariables;
  final double chargesFixes;
  final double excedentBrutExploitation;
  final double amortissements;
  final double resultatGestion;

  /// Produits engagement − produits caisse (variation des créances).
  final double pontCreances;

  const CompteResultatData({
    required this.annee,
    required this.mois,
    required this.base,
    required this.produitsExploitation,
    required this.chargesVariables,
    required this.margeSurCoutsVariables,
    required this.chargesFixes,
    required this.excedentBrutExploitation,
    required this.amortissements,
    required this.resultatGestion,
    required this.pontCreances,
  });

  factory CompteResultatData.fromJson(Map<String, dynamic> j) =>
      CompteResultatData(
        annee: (j['annee'] as num?)?.toInt() ?? 0,
        mois: (j['mois'] as num?)?.toInt() ?? 0,
        base: j['base'] ?? 'CAISSE',
        produitsExploitation: _d(j['produitsExploitation']),
        chargesVariables: _d(j['chargesVariables']),
        margeSurCoutsVariables: _d(j['margeSurCoutsVariables']),
        chargesFixes: _d(j['chargesFixes']),
        excedentBrutExploitation: _d(j['excedentBrutExploitation']),
        amortissements: _d(j['amortissements']),
        resultatGestion: _d(j['resultatGestion']),
        pontCreances: _d(j['pontCreances']),
      );

  static double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;
}

/// Marge sur coûts variables d'un véhicule (comparateur de flotte).
class MargeVehiculeData {
  final int vehiculeId;
  final String immatriculation;
  final double produits;
  final double chargesVariables;
  final double marge;

  /// Nombre de jours d'immobilisation (indisponibilité véhicule) sur la période.
  final int joursImmobilisation;

  const MargeVehiculeData({
    required this.vehiculeId,
    required this.immatriculation,
    required this.produits,
    required this.chargesVariables,
    required this.marge,
    this.joursImmobilisation = 0,
  });

  factory MargeVehiculeData.fromJson(Map<String, dynamic> j) =>
      MargeVehiculeData(
        vehiculeId: (j['vehiculeId'] as num).toInt(),
        immatriculation: j['immatriculation'] ?? '',
        produits: (j['produits'] as num?)?.toDouble() ?? 0,
        chargesVariables: (j['chargesVariables'] as num?)?.toDouble() ?? 0,
        marge: (j['marge'] as num?)?.toDouble() ?? 0,
        joursImmobilisation: (j['joursImmobilisation'] as num?)?.toInt() ?? 0,
      );
}

/// Bilan de gestion : photo des stocks à une date.
class BilanData {
  final DateTime date;
  final double tresorerie;
  final double creancesChauffeurs;
  final double immobilisationsNettes;
  final double totalActif;
  final double detteEtatContraventions;
  final double situationNette;

  const BilanData({
    required this.date,
    required this.tresorerie,
    required this.creancesChauffeurs,
    required this.immobilisationsNettes,
    required this.totalActif,
    required this.detteEtatContraventions,
    required this.situationNette,
  });

  factory BilanData.fromJson(Map<String, dynamic> j) => BilanData(
        date: DateTime.parse(j['date']),
        tresorerie: (j['tresorerie'] as num?)?.toDouble() ?? 0,
        creancesChauffeurs: (j['creancesChauffeurs'] as num?)?.toDouble() ?? 0,
        immobilisationsNettes:
            (j['immobilisationsNettes'] as num?)?.toDouble() ?? 0,
        totalActif: (j['totalActif'] as num?)?.toDouble() ?? 0,
        detteEtatContraventions:
            (j['detteEtatContraventions'] as num?)?.toDouble() ?? 0,
        situationNette: (j['situationNette'] as num?)?.toDouble() ?? 0,
      );
}

/// Période comptable mensuelle clôturée.
class CloturePeriodeData {
  final int id;
  final int annee;
  final int mois;
  final DateTime dateCloture;

  const CloturePeriodeData({
    required this.id,
    required this.annee,
    required this.mois,
    required this.dateCloture,
  });

  factory CloturePeriodeData.fromJson(Map<String, dynamic> j) =>
      CloturePeriodeData(
        id: (j['id'] as num).toInt(),
        annee: (j['annee'] as num).toInt(),
        mois: (j['mois'] as num).toInt(),
        dateCloture: DateTime.parse(j['dateCloture']),
      );
}

/// Résultat d'une clôture de caisse.
class ClotureCaisseData {
  final int id;
  final double soldeTheorique;
  final double soldeCompte;
  final double ecart;

  const ClotureCaisseData({
    required this.id,
    required this.soldeTheorique,
    required this.soldeCompte,
    required this.ecart,
  });

  factory ClotureCaisseData.fromJson(Map<String, dynamic> j) =>
      ClotureCaisseData(
        id: (j['id'] as num).toInt(),
        soldeTheorique: (j['soldeTheorique'] as num?)?.toDouble() ?? 0,
        soldeCompte: (j['soldeCompte'] as num?)?.toDouble() ?? 0,
        ecart: (j['ecart'] as num?)?.toDouble() ?? 0,
      );
}

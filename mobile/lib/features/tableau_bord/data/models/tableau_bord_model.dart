/// Modèles du tableau de bord de supervision, servis par
/// `GET /tableau-bord`.
///
/// Tous les ratios sont nullables : le backend renvoie `null` — et non zéro —
/// quand le dénominateur est absent (aucun produit sur la période, marge nulle,
/// mois précédent vide). Un taux sans base n'existe pas ; l'affichage doit
/// écrire « — », pas « 0 % ».
library;

/// Cadrage de la lecture : période observée, base comptable, avancement.
class PeriodeTableauBord {
  final int annee;
  final int mois;
  final String label;
  final String base;
  final int joursEcoules;
  final int joursPeriode;
  final bool moisEnCours;
  final bool cloture;

  const PeriodeTableauBord({
    required this.annee,
    required this.mois,
    required this.label,
    required this.base,
    required this.joursEcoules,
    required this.joursPeriode,
    required this.moisEnCours,
    required this.cloture,
  });

  factory PeriodeTableauBord.fromJson(Map<String, dynamic> json) =>
      PeriodeTableauBord(
        annee: (json['annee'] as num?)?.toInt() ?? 0,
        mois: (json['mois'] as num?)?.toInt() ?? 0,
        label: json['label'] as String? ?? '',
        base: json['base'] as String? ?? 'CAISSE',
        joursEcoules: (json['joursEcoules'] as num?)?.toInt() ?? 0,
        joursPeriode: (json['joursPeriode'] as num?)?.toInt() ?? 0,
        moisEnCours: json['moisEnCours'] as bool? ?? false,
        cloture: json['cloture'] as bool? ?? false,
      );
}

/// Point de la courbe de tendance mensuelle (résultat = EBE).
class PointSerie {
  final int annee;
  final int mois;
  final String label;
  final double produits;
  final double charges;
  final double resultat;

  const PointSerie({
    required this.annee,
    required this.mois,
    required this.label,
    required this.produits,
    required this.charges,
    required this.resultat,
  });

  factory PointSerie.fromJson(Map<String, dynamic> json) => PointSerie(
        annee: (json['annee'] as num?)?.toInt() ?? 0,
        mois: (json['mois'] as num?)?.toInt() ?? 0,
        label: json['label'] as String? ?? '',
        produits: (json['produits'] as num?)?.toDouble() ?? 0,
        charges: (json['charges'] as num?)?.toDouble() ?? 0,
        resultat: (json['resultat'] as num?)?.toDouble() ?? 0,
      );
}

/// Bloc « est-ce que je gagne de l'argent » : cascade du compte de résultat et
/// ratios de structure.
class SanteFinanciere {
  final double produits;
  final double chargesVariables;
  final double margeSurCoutsVariables;
  final double chargesFixes;
  final double excedentBrutExploitation;
  final double amortissements;
  final double dotationProvisions;
  final double resultatGestion;
  final double? tauxMargeVariable;
  final double? tauxCharges;
  final double? pointMort;
  final double? tauxCouverturePointMort;
  final double? variationProduitsPct;
  final double? variationResultatPct;
  final List<PointSerie> serie;

  const SanteFinanciere({
    required this.produits,
    required this.chargesVariables,
    required this.margeSurCoutsVariables,
    required this.chargesFixes,
    required this.excedentBrutExploitation,
    required this.amortissements,
    required this.dotationProvisions,
    required this.resultatGestion,
    required this.tauxMargeVariable,
    required this.tauxCharges,
    required this.pointMort,
    required this.tauxCouverturePointMort,
    required this.variationProduitsPct,
    required this.variationResultatPct,
    required this.serie,
  });

  factory SanteFinanciere.fromJson(Map<String, dynamic> json) => SanteFinanciere(
        produits: (json['produits'] as num?)?.toDouble() ?? 0,
        chargesVariables: (json['chargesVariables'] as num?)?.toDouble() ?? 0,
        margeSurCoutsVariables:
            (json['margeSurCoutsVariables'] as num?)?.toDouble() ?? 0,
        chargesFixes: (json['chargesFixes'] as num?)?.toDouble() ?? 0,
        excedentBrutExploitation:
            (json['excedentBrutExploitation'] as num?)?.toDouble() ?? 0,
        amortissements: (json['amortissements'] as num?)?.toDouble() ?? 0,
        dotationProvisions: (json['dotationProvisions'] as num?)?.toDouble() ?? 0,
        resultatGestion: (json['resultatGestion'] as num?)?.toDouble() ?? 0,
        tauxMargeVariable: (json['tauxMargeVariable'] as num?)?.toDouble(),
        tauxCharges: (json['tauxCharges'] as num?)?.toDouble(),
        pointMort: (json['pointMort'] as num?)?.toDouble(),
        tauxCouverturePointMort:
            (json['tauxCouverturePointMort'] as num?)?.toDouble(),
        variationProduitsPct: (json['variationProduitsPct'] as num?)?.toDouble(),
        variationResultatPct: (json['variationResultatPct'] as num?)?.toDouble(),
        serie: (json['serie'] as List<dynamic>? ?? [])
            .map((e) => PointSerie.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  /// Charges totales de la période (variables + fixes).
  double get chargesTotales => chargesVariables + chargesFixes;
}

/// Chauffeur débiteur au palmarès de la balance âgée.
class Debiteur {
  final int? chauffeurId;
  final String nom;
  final int nbLignes;
  final double total;
  final double plus30Jours;

  const Debiteur({
    required this.chauffeurId,
    required this.nom,
    required this.nbLignes,
    required this.total,
    required this.plus30Jours,
  });

  factory Debiteur.fromJson(Map<String, dynamic> json) => Debiteur(
        chauffeurId: (json['chauffeurId'] as num?)?.toInt(),
        nom: json['nom'] as String? ?? '',
        nbLignes: (json['nbLignes'] as num?)?.toInt() ?? 0,
        total: (json['total'] as num?)?.toDouble() ?? 0,
        plus30Jours: (json['plus30Jours'] as num?)?.toDouble() ?? 0,
      );
}

/// Bloc « est-ce que l'argent rentre » : trésorerie, encours et vitesse de
/// recouvrement.
class CashCreances {
  final double tresorerieDisponible;
  final double creancesBrutes;
  final double creances0a7Jours;
  final double creances8a30Jours;
  final double creancesPlus30Jours;
  final double? partCreancesRisque;
  final double provisionCreances;
  final double creancesNettes;
  final double? tauxRecouvrement;
  final double resteAEncaisserPeriode;
  final double? dso;
  final double aReverserEtat;
  final int nbChauffeursDebiteurs;
  final List<Debiteur> topDebiteurs;

  const CashCreances({
    required this.tresorerieDisponible,
    required this.creancesBrutes,
    required this.creances0a7Jours,
    required this.creances8a30Jours,
    required this.creancesPlus30Jours,
    required this.partCreancesRisque,
    required this.provisionCreances,
    required this.creancesNettes,
    required this.tauxRecouvrement,
    required this.resteAEncaisserPeriode,
    required this.dso,
    required this.aReverserEtat,
    required this.nbChauffeursDebiteurs,
    required this.topDebiteurs,
  });

  factory CashCreances.fromJson(Map<String, dynamic> json) => CashCreances(
        tresorerieDisponible:
            (json['tresorerieDisponible'] as num?)?.toDouble() ?? 0,
        creancesBrutes: (json['creancesBrutes'] as num?)?.toDouble() ?? 0,
        creances0a7Jours: (json['creances0a7Jours'] as num?)?.toDouble() ?? 0,
        creances8a30Jours: (json['creances8a30Jours'] as num?)?.toDouble() ?? 0,
        creancesPlus30Jours:
            (json['creancesPlus30Jours'] as num?)?.toDouble() ?? 0,
        partCreancesRisque: (json['partCreancesRisque'] as num?)?.toDouble(),
        provisionCreances: (json['provisionCreances'] as num?)?.toDouble() ?? 0,
        creancesNettes: (json['creancesNettes'] as num?)?.toDouble() ?? 0,
        tauxRecouvrement: (json['tauxRecouvrement'] as num?)?.toDouble(),
        resteAEncaisserPeriode:
            (json['resteAEncaisserPeriode'] as num?)?.toDouble() ?? 0,
        dso: (json['dso'] as num?)?.toDouble(),
        aReverserEtat: (json['aReverserEtat'] as num?)?.toDouble() ?? 0,
        nbChauffeursDebiteurs:
            (json['nbChauffeursDebiteurs'] as num?)?.toInt() ?? 0,
        topDebiteurs: (json['topDebiteurs'] as List<dynamic>? ?? [])
            .map((e) => Debiteur.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Véhicule au palmarès de la période, mesuré à sa marge nette.
class VehiculePerformance {
  final int? vehiculeId;
  final String immatriculation;
  final double produits;
  final double marge;
  final double margeNette;
  final int joursImmobilisation;

  const VehiculePerformance({
    required this.vehiculeId,
    required this.immatriculation,
    required this.produits,
    required this.marge,
    required this.margeNette,
    required this.joursImmobilisation,
  });

  factory VehiculePerformance.fromJson(Map<String, dynamic> json) =>
      VehiculePerformance(
        vehiculeId: (json['vehiculeId'] as num?)?.toInt(),
        immatriculation: json['immatriculation'] as String? ?? '',
        produits: (json['produits'] as num?)?.toDouble() ?? 0,
        marge: (json['marge'] as num?)?.toDouble() ?? 0,
        margeNette: (json['margeNette'] as num?)?.toDouble() ?? 0,
        joursImmobilisation:
            (json['joursImmobilisation'] as num?)?.toInt() ?? 0,
      );
}

/// Bloc « est-ce que mon actif produit » : occupation du parc et rendement au
/// véhicule.
class PerformanceFlotte {
  final int parcActif;
  final int enService;
  final int disponibles;
  final int enMaintenance;
  final int immobilises;
  final int horsParc;
  final double tauxDisponibilite;
  final double tauxUtilisation;
  final double revenuParVehiculeActif;
  final double revenuJournalierMoyen;
  final int joursImmobilisation;
  final double? tauxImmobilisation;
  final double manqueAGagnerImmobilisation;
  final double margeNetteMoyenne;
  final int nbVehiculesDeficitaires;
  final int nbVehiculesEvalues;
  final List<VehiculePerformance> meilleurs;
  final List<VehiculePerformance> moinsBons;

  const PerformanceFlotte({
    required this.parcActif,
    required this.enService,
    required this.disponibles,
    required this.enMaintenance,
    required this.immobilises,
    required this.horsParc,
    required this.tauxDisponibilite,
    required this.tauxUtilisation,
    required this.revenuParVehiculeActif,
    required this.revenuJournalierMoyen,
    required this.joursImmobilisation,
    required this.tauxImmobilisation,
    required this.manqueAGagnerImmobilisation,
    required this.margeNetteMoyenne,
    required this.nbVehiculesDeficitaires,
    required this.nbVehiculesEvalues,
    required this.meilleurs,
    required this.moinsBons,
  });

  factory PerformanceFlotte.fromJson(Map<String, dynamic> json) =>
      PerformanceFlotte(
        parcActif: (json['parcActif'] as num?)?.toInt() ?? 0,
        enService: (json['enService'] as num?)?.toInt() ?? 0,
        disponibles: (json['disponibles'] as num?)?.toInt() ?? 0,
        enMaintenance: (json['enMaintenance'] as num?)?.toInt() ?? 0,
        immobilises: (json['immobilises'] as num?)?.toInt() ?? 0,
        horsParc: (json['horsParc'] as num?)?.toInt() ?? 0,
        tauxDisponibilite: (json['tauxDisponibilite'] as num?)?.toDouble() ?? 0,
        tauxUtilisation: (json['tauxUtilisation'] as num?)?.toDouble() ?? 0,
        revenuParVehiculeActif:
            (json['revenuParVehiculeActif'] as num?)?.toDouble() ?? 0,
        revenuJournalierMoyen:
            (json['revenuJournalierMoyen'] as num?)?.toDouble() ?? 0,
        joursImmobilisation:
            (json['joursImmobilisation'] as num?)?.toInt() ?? 0,
        tauxImmobilisation: (json['tauxImmobilisation'] as num?)?.toDouble(),
        manqueAGagnerImmobilisation:
            (json['manqueAGagnerImmobilisation'] as num?)?.toDouble() ?? 0,
        margeNetteMoyenne: (json['margeNetteMoyenne'] as num?)?.toDouble() ?? 0,
        nbVehiculesDeficitaires:
            (json['nbVehiculesDeficitaires'] as num?)?.toInt() ?? 0,
        nbVehiculesEvalues: (json['nbVehiculesEvalues'] as num?)?.toInt() ?? 0,
        meilleurs: (json['meilleurs'] as List<dynamic>? ?? [])
            .map((e) => VehiculePerformance.fromJson(e as Map<String, dynamic>))
            .toList(),
        moinsBons: (json['moinsBons'] as List<dynamic>? ?? [])
            .map((e) => VehiculePerformance.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Bloc « qu'est-ce qui menace la suite ».
class AlertesTableauBord {
  final int documentsExpirantSous30Jours;
  final int maintenancesDuesSous7Jours;
  final int permisExpires;
  final int vidangesDues;
  final int immobilisationsLongues;
  final int vehiculesSansChauffeur;

  const AlertesTableauBord({
    required this.documentsExpirantSous30Jours,
    required this.maintenancesDuesSous7Jours,
    required this.permisExpires,
    required this.vidangesDues,
    required this.immobilisationsLongues,
    required this.vehiculesSansChauffeur,
  });

  factory AlertesTableauBord.fromJson(Map<String, dynamic> json) =>
      AlertesTableauBord(
        documentsExpirantSous30Jours:
            (json['documentsExpirantSous30Jours'] as num?)?.toInt() ?? 0,
        maintenancesDuesSous7Jours:
            (json['maintenancesDuesSous7Jours'] as num?)?.toInt() ?? 0,
        permisExpires: (json['permisExpires'] as num?)?.toInt() ?? 0,
        vidangesDues: (json['vidangesDues'] as num?)?.toInt() ?? 0,
        immobilisationsLongues:
            (json['immobilisationsLongues'] as num?)?.toInt() ?? 0,
        vehiculesSansChauffeur:
            (json['vehiculesSansChauffeur'] as num?)?.toInt() ?? 0,
      );

  /// Total des signaux ouverts, pour la pastille de synthèse.
  int get total =>
      documentsExpirantSous30Jours +
      maintenancesDuesSous7Jours +
      permisExpires +
      vidangesDues +
      immobilisationsLongues +
      vehiculesSansChauffeur;
}

/// Réponse complète de `GET /tableau-bord`.
class TableauBordModel {
  final PeriodeTableauBord periode;
  final SanteFinanciere finance;
  final CashCreances cash;
  final PerformanceFlotte flotte;
  final AlertesTableauBord alertes;

  const TableauBordModel({
    required this.periode,
    required this.finance,
    required this.cash,
    required this.flotte,
    required this.alertes,
  });

  factory TableauBordModel.fromJson(Map<String, dynamic> json) =>
      TableauBordModel(
        periode: PeriodeTableauBord.fromJson(
            json['periode'] as Map<String, dynamic>? ?? const {}),
        finance: SanteFinanciere.fromJson(
            json['finance'] as Map<String, dynamic>? ?? const {}),
        cash: CashCreances.fromJson(
            json['cash'] as Map<String, dynamic>? ?? const {}),
        flotte: PerformanceFlotte.fromJson(
            json['flotte'] as Map<String, dynamic>? ?? const {}),
        alertes: AlertesTableauBord.fromJson(
            json['alertes'] as Map<String, dynamic>? ?? const {}),
      );
}

/// Ce que le serveur répond quand l'écran de réaffectation s'ouvre : qui peut
/// reprendre la créance, et ce que le déplacement entraînera.
///
/// Miroir de `ApercuReaffectationResponse`. Un seul aller-retour : deux appels
/// séparés feraient apparaître la liste puis, un instant plus tard, les
/// conséquences — et le second échouerait parfois seul, laissant un écran à
/// moitié su.
class ApercuReaffectation {
  final List<CandidatChauffeur> candidats;
  final ImpactsReaffectation impacts;

  const ApercuReaffectation({required this.candidats, required this.impacts});

  factory ApercuReaffectation.fromJson(Map<String, dynamic> json) {
    return ApercuReaffectation(
      candidats: (json['candidats'] as List<dynamic>? ?? [])
          .map((c) => CandidatChauffeur.fromJson(c as Map<String, dynamic>))
          .toList(),
      impacts: ImpactsReaffectation.fromJson(
          json['impacts'] as Map<String, dynamic>? ?? const {}),
    );
  }
}

/// Un chauffeur, jugé par le serveur.
///
/// L'écran n'a rien à recalculer : la règle « un chauffeur, un véhicule, un
/// jour » vit d'un seul côté, et un client qui la rejouerait finirait par
/// diverger d'elle. Un candidat non éligible reste affiché, grisé, avec sa
/// raison — le masquer laisserait le chercher.
class CandidatChauffeur {
  final int id;
  final String nom;

  /// Il figure au programme du véhicule ce jour-là, remplacements compris.
  /// Sert à ranger la liste, jamais à filtrer.
  final bool auProgramme;

  /// C'est le chauffeur que la ligne porte déjà.
  final bool actuel;

  final bool eligible;

  /// Ce qui l'empêche d'être choisi ; ou, quand il l'est, ce qu'il porte déjà
  /// ce jour-là.
  final String? motif;

  const CandidatChauffeur({
    required this.id,
    required this.nom,
    this.auProgramme = false,
    this.actuel = false,
    this.eligible = true,
    this.motif,
  });

  factory CandidatChauffeur.fromJson(Map<String, dynamic> json) {
    return CandidatChauffeur(
      id: json['chauffeurId'] as int,
      nom: json['nom'] as String? ?? 'Chauffeur',
      auProgramme: json['auProgramme'] as bool? ?? false,
      actuel: json['actuel'] as bool? ?? false,
      // Absent = non éligible : mieux vaut un candidat refusé à tort qu'un
      // choix que le serveur rejettera.
      eligible: json['eligible'] as bool? ?? false,
      motif: json['motif'] as String?,
    );
  }
}

/// Ce que la réaffectation entraînera, en faits chiffrés.
///
/// Des faits et non des phrases : le nom du chauffeur choisi et le format des
/// montants ne sont connus qu'ici. Ce que l'écran ne pouvait pas savoir, en
/// revanche, c'est s'il existe réellement une pénalité à emmener — il
/// l'annonçait auparavant dans tous les cas.
class ImpactsReaffectation {
  final double montantCreance;
  final int encaissementsRattaches;
  final double montantEncaisse;
  final int penalitesQuiSuivent;
  final double montantPenalites;

  const ImpactsReaffectation({
    this.montantCreance = 0,
    this.encaissementsRattaches = 0,
    this.montantEncaisse = 0,
    this.penalitesQuiSuivent = 0,
    this.montantPenalites = 0,
  });

  factory ImpactsReaffectation.fromJson(Map<String, dynamic> json) {
    return ImpactsReaffectation(
      montantCreance: (json['montantCreance'] as num?)?.toDouble() ?? 0,
      encaissementsRattaches: json['encaissementsRattaches'] as int? ?? 0,
      montantEncaisse: (json['montantEncaisse'] as num?)?.toDouble() ?? 0,
      penalitesQuiSuivent: json['penalitesQuiSuivent'] as int? ?? 0,
      montantPenalites: (json['montantPenalites'] as num?)?.toDouble() ?? 0,
    );
  }
}

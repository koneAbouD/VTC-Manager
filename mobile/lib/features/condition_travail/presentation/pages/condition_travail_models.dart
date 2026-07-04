/// Modèles locaux pour les conditions de travail (utilisés dans le wizard
/// et le sélecteur sans créer de dépendance circulaire).
library;

class CotisationLocal {
  final int? id;
  final String nom;
  final double montant;

  const CotisationLocal({this.id, required this.nom, required this.montant});

  factory CotisationLocal.fromJson(Map<String, dynamic> j) => CotisationLocal(
        id: j['id'] as int?,
        nom: j['nom'] as String? ?? '',
        montant: (j['montant'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'nom': nom,
        'montant': montant,
      };
}

class SanctionTypeLocal {
  final String code;
  final String label;
  final String paramType; // DUREE_SECONDES | DUREE_MINUTES | MONTANT | TAUX

  const SanctionTypeLocal({
    required this.code,
    required this.label,
    required this.paramType,
  });

  factory SanctionTypeLocal.fromJson(Map<String, dynamic> j) =>
      SanctionTypeLocal(
        code: j['code'] as String,
        label: j['label'] as String,
        paramType: j['paramType'] as String,
      );
}

class PenaliteGroupLocal {
  final String typePenalite;
  final List<PenaliteLocal> sanctions;

  PenaliteGroupLocal({
    required this.typePenalite,
    List<PenaliteLocal>? sanctions,
  }) : sanctions = sanctions ?? [];

  static const _labels = {
    'RECETTE_NON_VERSEE': 'Recette non versée',
    'HEURE_FIN_SERVICE_PASSE': 'Heure de fin de service passée',
    'EXCES_VITESSE': 'Excès de vitesse',
  };

  String get label => _labels[typePenalite] ?? typePenalite;

  PenaliteGroupLocal copyWith({List<PenaliteLocal>? sanctions}) =>
      PenaliteGroupLocal(
          typePenalite: typePenalite, sanctions: sanctions ?? this.sanctions);

  static List<PenaliteGroupLocal> fromFlat(List<PenaliteLocal> flat) {
    final map = <String, List<PenaliteLocal>>{};
    for (final p in flat) {
      map.putIfAbsent(p.typePenalite, () => []).add(p);
    }
    return map.entries
        .map((e) =>
            PenaliteGroupLocal(typePenalite: e.key, sanctions: e.value))
        .toList();
  }

  List<PenaliteLocal> toFlat() => [...sanctions];
}

class PenaliteLocal {
  final int? id;
  final String typePenalite;
  final String typeSanction;
  final int? dureeSanctionSecondes;
  final double? montant;
  final int? dureeImmobilisationMinutes;

  const PenaliteLocal({
    this.id,
    required this.typePenalite,
    required this.typeSanction,
    this.dureeSanctionSecondes,
    this.montant,
    this.dureeImmobilisationMinutes,
  });

  factory PenaliteLocal.fromJson(Map<String, dynamic> j) => PenaliteLocal(
        id: j['id'] as int?,
        typePenalite: j['typePenalite'] as String? ?? '',
        typeSanction: j['typeSanction'] as String? ?? '',
        dureeSanctionSecondes: j['dureeSanctionSecondes'] as int?,
        montant: (j['montant'] as num?)?.toDouble(),
        dureeImmobilisationMinutes: j['dureeImmobilisationMinutes'] as int?,
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'typePenalite': typePenalite,
        'typeSanction': typeSanction,
        if (dureeSanctionSecondes != null)
          'dureeSanctionSecondes': dureeSanctionSecondes,
        if (montant != null) 'montant': montant,
        if (dureeImmobilisationMinutes != null)
          'dureeImmobilisationMinutes': dureeImmobilisationMinutes,
      };

  String get resume {
    switch (typeSanction) {
      case 'AMENDE':
        return '${montant?.toStringAsFixed(0) ?? '-'} XOF';
      case 'AVERTISSEMENT':
        return 'Avertissement';
      case 'IMMOBILISATION':
        return '$dureeImmobilisationMinutes min avant arrêt';
      case 'BUZZER':
        return '$dureeSanctionSecondes secondes';
      default:
        return '';
    }
  }
}

class ConditionTravailLocal {
  final int? id;
  final String nom;
  final int nbChauffeurs;
  final String typeProgramme;
  final String heureDebut;
  final String heureFin;
  final String modeAlternance;
  final int joursAlternance;
  final String jourSalaire;
  final String typeRecette;
  final double objectifRecette;
  final double? montantJourSalaire;
  final String? modeEncaissement;
  final String? frequenceVersement;
  final String? jourVersement;
  final String heureVersement;
  final List<String> joursTravail;
  final List<CotisationLocal> cotisations;
  final List<PenaliteLocal> penalites;

  const ConditionTravailLocal({
    required this.id,
    required this.nom,
    required this.nbChauffeurs,
    required this.typeProgramme,
    required this.heureDebut,
    required this.heureFin,
    required this.modeAlternance,
    required this.joursAlternance,
    required this.jourSalaire,
    required this.typeRecette,
    required this.objectifRecette,
    this.montantJourSalaire,
    this.modeEncaissement,
    this.frequenceVersement,
    this.jourVersement,
    required this.heureVersement,
    this.joursTravail = const [],
    required this.cotisations,
    required this.penalites,
  });

  factory ConditionTravailLocal.fromJson(Map<String, dynamic> json) =>
      ConditionTravailLocal(
        id: json['id'] as int?,
        nom: json['nom'] as String? ?? '',
        nbChauffeurs: json['nbChauffeurs'] as int? ?? 1,
        typeProgramme: json['typeProgramme'] as String? ?? 'JOURNALIER',
        heureDebut: json['heureDebutService'] as String? ??
            json['heureDebut'] as String? ?? '07:00',
        heureFin: json['heureFinService'] as String? ??
            json['heureFin'] as String? ?? '19:00',
        modeAlternance: json['modeAlternance'] as String? ?? 'AUTOMATIQUE',
        joursAlternance: json['joursAlternance'] as int? ?? 1,
        jourSalaire: json['jourSalaire'] as String? ?? 'DIMANCHE',
        typeRecette: json['typeRecette'] as String? ?? 'MONTANT_FIXE',
        objectifRecette:
            (json['objectifRecette'] as num?)?.toDouble() ?? 0,
        montantJourSalaire:
            (json['montantJourSalaire'] as num?)?.toDouble(),
        modeEncaissement: json['modeEncaissement'] as String?,
        frequenceVersement: json['frequenceVersement'] as String?,
        jourVersement: json['jourVersement'] as String?,
        heureVersement: json['heureVersement'] as String? ?? '18:30',
        joursTravail: (json['joursTravail'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        cotisations: (json['cotisations'] as List<dynamic>?)
                ?.map((e) =>
                    CotisationLocal.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        penalites: (json['penalites'] as List<dynamic>?)
                ?.map((e) =>
                    PenaliteLocal.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );

  double get totalCotisations =>
      cotisations.fold(0, (sum, c) => sum + c.montant);

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'nom': nom,
        'nbChauffeurs': nbChauffeurs,
        'typeProgramme': typeProgramme,
        'heureDebutService': heureDebut,
        'heureFinService': heureFin,
        'modeAlternance': modeAlternance,
        'joursAlternance': joursAlternance,
        'jourSalaire': jourSalaire,
        'typeRecette': typeRecette,
        'objectifRecette': objectifRecette,
        if (montantJourSalaire != null)
          'montantJourSalaire': montantJourSalaire,
        if (modeEncaissement != null) 'modeEncaissement': modeEncaissement,
        if (frequenceVersement != null)
          'frequenceVersement': frequenceVersement,
        if (jourVersement != null) 'jourVersement': jourVersement,
        'heureVersement': heureVersement,
        'joursTravail': joursTravail,
        'cotisations': cotisations.map((c) => c.toJson()).toList(),
        'penalites': penalites.map((p) => p.toJson()).toList(),
      };
}

/// Ligne de balance âgée : total dû par un chauffeur, ventilé par ancienneté.
class CreanceChauffeur {
  final int chauffeurId;
  final String nom;
  final String prenom;
  final int nbLignes;
  final double du0a7Jours;
  final double du8a30Jours;
  final double duPlus30Jours;
  final double total;

  const CreanceChauffeur({
    required this.chauffeurId,
    required this.nom,
    required this.prenom,
    required this.nbLignes,
    required this.du0a7Jours,
    required this.du8a30Jours,
    required this.duPlus30Jours,
    required this.total,
  });

  String get displayName => '$prenom $nom'.trim();

  /// Tranche la plus ancienne avec un dû : détermine le badge affiché.
  TrancheAge get trancheDominante {
    if (duPlus30Jours > 0) return TrancheAge.plus30;
    if (du8a30Jours > 0) return TrancheAge.de8a30;
    return TrancheAge.de0a7;
  }

  factory CreanceChauffeur.fromJson(Map<String, dynamic> j) => CreanceChauffeur(
        chauffeurId: (j['chauffeurId'] as num).toInt(),
        nom: j['nom'] ?? '',
        prenom: j['prenom'] ?? '',
        nbLignes: (j['nbLignes'] as num?)?.toInt() ?? 0,
        du0a7Jours: (j['du0a7Jours'] as num?)?.toDouble() ?? 0,
        du8a30Jours: (j['du8a30Jours'] as num?)?.toDouble() ?? 0,
        duPlus30Jours: (j['duPlus30Jours'] as num?)?.toDouble() ?? 0,
        total: (j['total'] as num?)?.toDouble() ?? 0,
      );
}

enum TrancheAge {
  de0a7('0–7 j'),
  de8a30('8–30 j'),
  plus30('+30 j');

  final String label;
  const TrancheAge(this.label);
}

/// Document ouvert d'un chauffeur : documentId + document permettent de
/// rouvrir le flux d'encaissement du module d'origine.
class LigneCreance {
  /// RECETTE | PENALITE | CONTRAVENTION (une cotisation n'est jamais une
  /// créance : c'est l'épargne du chauffeur)
  final String document;
  final int documentId;
  final int? vehiculeId;
  final int? chauffeurId;
  final String? chauffeurNom;
  final DateTime dateReference;
  final double montantDu;
  final double montantRegle;
  final double restant;

  const LigneCreance({
    required this.document,
    required this.documentId,
    this.vehiculeId,
    this.chauffeurId,
    this.chauffeurNom,
    required this.dateReference,
    required this.montantDu,
    required this.montantRegle,
    required this.restant,
  });

  factory LigneCreance.fromJson(Map<String, dynamic> j) => LigneCreance(
        document: j['document'] ?? '',
        documentId: (j['documentId'] as num).toInt(),
        vehiculeId: (j['vehiculeId'] as num?)?.toInt(),
        chauffeurId: (j['chauffeurId'] as num?)?.toInt(),
        chauffeurNom: j['chauffeurNom'] as String?,
        dateReference: DateTime.parse(j['dateReference']),
        montantDu: (j['montantDu'] as num?)?.toDouble() ?? 0,
        montantRegle: (j['montantRegle'] as num?)?.toDouble() ?? 0,
        restant: (j['restant'] as num?)?.toDouble() ?? 0,
      );
}

/// Ligne de balance âgée agrégée par véhicule : total dû rattaché à un véhicule
/// (tous chauffeurs confondus), ventilé par ancienneté.
class CreanceVehicule {
  final int vehiculeId;
  final String immatriculation;
  final String? marque;
  final String? modele;
  final int nbLignes;
  final double du0a7Jours;
  final double du8a30Jours;
  final double duPlus30Jours;
  final double total;

  const CreanceVehicule({
    required this.vehiculeId,
    required this.immatriculation,
    this.marque,
    this.modele,
    required this.nbLignes,
    required this.du0a7Jours,
    required this.du8a30Jours,
    required this.duPlus30Jours,
    required this.total,
  });

  /// Libellé d'affichage : immatriculation seule. La marque et le modèle sont
  /// volontairement écartés pour garder les lignes de créance lisibles ; on ne
  /// retombe sur eux que si l'immatriculation est absente.
  String get displayName {
    if (immatriculation.isNotEmpty) return immatriculation;
    final mm = '${marque ?? ''} ${modele ?? ''}'.trim();
    return mm.isEmpty ? 'Véhicule' : mm;
  }

  TrancheAge get trancheDominante {
    if (duPlus30Jours > 0) return TrancheAge.plus30;
    if (du8a30Jours > 0) return TrancheAge.de8a30;
    return TrancheAge.de0a7;
  }

  factory CreanceVehicule.fromJson(Map<String, dynamic> j) => CreanceVehicule(
        vehiculeId: (j['vehiculeId'] as num).toInt(),
        immatriculation: j['immatriculation'] ?? '',
        marque: j['marque'] as String?,
        modele: j['modele'] as String?,
        nbLignes: (j['nbLignes'] as num?)?.toInt() ?? 0,
        du0a7Jours: (j['du0a7Jours'] as num?)?.toDouble() ?? 0,
        du8a30Jours: (j['du8a30Jours'] as num?)?.toDouble() ?? 0,
        duPlus30Jours: (j['duPlus30Jours'] as num?)?.toDouble() ?? 0,
        total: (j['total'] as num?)?.toDouble() ?? 0,
      );
}

/// Restriction de la balance âgée, appliquée côté serveur : mois de naissance
/// des documents et mot-clé (immatriculation ou nom du chauffeur).
class FiltreCreances {
  /// Mois retenu (seuls année et mois comptent) ; null = tous les mois.
  final DateTime? mois;
  final String recherche;

  const FiltreCreances({this.mois, this.recherche = ''});

  static const aucun = FiltreCreances();

  bool get estActif => mois != null || recherche.trim().isNotEmpty;

  FiltreCreances avecMois(DateTime? mois) =>
      FiltreCreances(mois: mois, recherche: recherche);

  FiltreCreances avecRecherche(String recherche) =>
      FiltreCreances(mois: mois, recherche: recherche);

  /// Paramètres de requête : `mois=AAAA-MM` et `q`, omis quand vides.
  Map<String, String> toQuery() => {
        if (mois != null)
          'mois': '${mois!.year}-${mois!.month.toString().padLeft(2, '0')}',
        if (recherche.trim().isNotEmpty) 'q': recherche.trim(),
      };

  @override
  bool operator ==(Object other) =>
      other is FiltreCreances &&
      other.mois?.year == mois?.year &&
      other.mois?.month == mois?.month &&
      other.recherche.trim() == recherche.trim();

  @override
  int get hashCode => Object.hash(mois?.year, mois?.month, recherche.trim());
}

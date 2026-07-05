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
  /// RECETTE | COTISATION | PENALITE | CONTRAVENTION
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

  String get displayName {
    final mm = '${marque ?? ''} ${modele ?? ''}'.trim();
    if (immatriculation.isEmpty) return mm.isEmpty ? 'Véhicule' : mm;
    return mm.isEmpty ? immatriculation : '$immatriculation · $mm';
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

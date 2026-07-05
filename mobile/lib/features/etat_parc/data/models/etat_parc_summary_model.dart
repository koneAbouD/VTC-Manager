/// Photo du parc renvoyée par `GET /etat-parc/summary`.
///
/// Les taux sont calculés côté backend sur le parc actif (HORS_PARC exclu
/// du dénominateur).
class EtatParcSummaryModel {
  final int totalVehicules;
  final int parcActif;
  final int enService;
  final int disponibles;
  final int enMaintenance;
  final int immobilises;
  final int horsParc;
  final double tauxDisponibilite;
  final double tauxUtilisation;
  final List<VehiculeExceptionModel> exceptions;
  final EtatParcAlertesModel alertes;

  const EtatParcSummaryModel({
    required this.totalVehicules,
    required this.parcActif,
    required this.enService,
    required this.disponibles,
    required this.enMaintenance,
    required this.immobilises,
    required this.horsParc,
    required this.tauxDisponibilite,
    required this.tauxUtilisation,
    required this.exceptions,
    required this.alertes,
  });

  factory EtatParcSummaryModel.fromJson(Map<String, dynamic> json) =>
      EtatParcSummaryModel(
        totalVehicules: (json['totalVehicules'] as num?)?.toInt() ?? 0,
        parcActif: (json['parcActif'] as num?)?.toInt() ?? 0,
        enService: (json['enService'] as num?)?.toInt() ?? 0,
        disponibles: (json['disponibles'] as num?)?.toInt() ?? 0,
        enMaintenance: (json['enMaintenance'] as num?)?.toInt() ?? 0,
        immobilises: (json['immobilises'] as num?)?.toInt() ?? 0,
        horsParc: (json['horsParc'] as num?)?.toInt() ?? 0,
        tauxDisponibilite:
            (json['tauxDisponibilite'] as num?)?.toDouble() ?? 0,
        tauxUtilisation: (json['tauxUtilisation'] as num?)?.toDouble() ?? 0,
        exceptions: (json['exceptions'] as List<dynamic>? ?? [])
            .map((e) =>
                VehiculeExceptionModel.fromJson(e as Map<String, dynamic>))
            .toList(),
        alertes: EtatParcAlertesModel.fromJson(
            json['alertes'] as Map<String, dynamic>? ?? const {}),
      );
}

/// Véhicule demandant une action, avec motif et ancienneté dans le statut.
class VehiculeExceptionModel {
  final int? vehiculeId;
  final String immatriculation;
  final String libelleVehicule;
  final String? statut;
  final String? motif;
  final int? joursDansStatut;

  /// Fin prévue de l'immobilisation planifiée (indisponibilité véhicule).
  /// Null si le motif n'est pas une indisponibilité ou si elle est ouverte.
  final DateTime? finPrevue;

  const VehiculeExceptionModel({
    required this.vehiculeId,
    required this.immatriculation,
    required this.libelleVehicule,
    required this.statut,
    required this.motif,
    required this.joursDansStatut,
    this.finPrevue,
  });

  factory VehiculeExceptionModel.fromJson(Map<String, dynamic> json) =>
      VehiculeExceptionModel(
        vehiculeId: (json['vehiculeId'] as num?)?.toInt(),
        immatriculation: (json['immatriculation'] ?? '').toString(),
        libelleVehicule: (json['libelleVehicule'] ?? '').toString(),
        statut: json['statut'] as String?,
        motif: json['motif'] as String?,
        joursDansStatut: (json['joursDansStatut'] as num?)?.toInt(),
        finPrevue: json['finPrevue'] != null
            ? DateTime.tryParse(json['finPrevue'] as String)
            : null,
      );

  /// Libellé français du motif historisé.
  String get motifLabel => switch (motif) {
        'IMMOBILISATION_PENALITE' => 'Pénalité en cours',
        'IMMOBILISATION_INDISPONIBILITE' => 'Immobilisé (indisponibilité)',
        'PANNE_OU_ACCIDENT' => 'Panne ou accident',
        'MAINTENANCE_EN_COURS' => 'Maintenance en cours',
        'SANS_CHAUFFEUR' => 'Aucun chauffeur affecté',
        'CHAUFFEUR_AFFECTE' => 'Chauffeur affecté',
        'SORTIE_PARC' => 'Sorti du parc',
        'DECISION_MANUELLE' => 'Décision manuelle',
        'ENTREE_FLOTTE' => 'Entrée dans la flotte',
        _ => 'Motif inconnu',
      };
}

class EtatParcAlertesModel {
  final int documentsExpirantSous30Jours;
  final int maintenancesDuesSous7Jours;
  final int permisExpires;

  const EtatParcAlertesModel({
    required this.documentsExpirantSous30Jours,
    required this.maintenancesDuesSous7Jours,
    required this.permisExpires,
  });

  factory EtatParcAlertesModel.fromJson(Map<String, dynamic> json) =>
      EtatParcAlertesModel(
        documentsExpirantSous30Jours:
            (json['documentsExpirantSous30Jours'] as num?)?.toInt() ?? 0,
        maintenancesDuesSous7Jours:
            (json['maintenancesDuesSous7Jours'] as num?)?.toInt() ?? 0,
        permisExpires: (json['permisExpires'] as num?)?.toInt() ?? 0,
      );

  bool get hasAlertes =>
      documentsExpirantSous30Jours > 0 ||
      maintenancesDuesSous7Jours > 0 ||
      permisExpires > 0;
}

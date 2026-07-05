import 'encaissement_penalite.dart';

enum StatutLignePenalite {
  enAttente,
  partiellementEncaissee,
  encaissee,
  executee,
  notifiee,
  enCours,
  levee,
  annulee;

  static StatutLignePenalite fromString(String? value) {
    return switch (value) {
      'EN_ATTENTE'               => enAttente,
      'PARTIELLEMENT_ENCAISSEE'  => partiellementEncaissee,
      'ENCAISSEE'                => encaissee,
      'EXECUTEE'                 => executee,
      'NOTIFIEE'                 => notifiee,
      'EN_COURS'                 => enCours,
      'LEVEE'                    => levee,
      'ANNULEE'                  => annulee,
      _                          => enAttente,
    };
  }

  String get label => switch (this) {
    enAttente              => 'En attente',
    partiellementEncaissee => 'Part. encaissée',
    encaissee              => 'Encaissée',
    executee               => 'Exécutée',
    notifiee               => 'Notifiée',
    enCours                => 'En cours',
    levee                  => 'Levée',
    annulee                => 'Annulée',
  };

  bool get isTerminal =>
      this == encaissee || this == executee ||
      this == notifiee  || this == levee    || this == annulee;
}

enum TypeSanctionLigne {
  buzzer,
  amende,
  avertissement,
  immobilisation;

  static TypeSanctionLigne fromString(String? value) => switch (value) {
    'BUZZER'         => buzzer,
    'AMENDE'         => amende,
    'AVERTISSEMENT'  => avertissement,
    'IMMOBILISATION' => immobilisation,
    _                => amende,
  };

  String get label => switch (this) {
    buzzer         => 'Buzzer',
    amende         => 'Amende',
    avertissement  => 'Avertissement',
    immobilisation => 'Immobilisation',
  };
}

class LignePenalite {
  final int? id;
  final int vehiculeId;
  final String? vehiculeImmatriculation;
  final int chauffeurId;
  final String? chauffeurNomComplet;
  final int? penaliteTemplateId;
  final String typePenalite;
  final TypeSanctionLigne typeSanction;
  final double montant;
  final double montantEncaisse;
  final double? montantRestant;
  final int? dureeSanctionSecondes;
  final int? dureeImmobilisationMinutes;
  final DateTime? dateDebutImmobilisation;
  final DateTime? dateFinImmobilisation;
  final DateTime dateGeneration;
  final DateTime? dateFaute;
  final int? ligneRecetteId;
  final StatutLignePenalite statut;
  final String? commentaire;
  final String? motifAnnulation;
  final List<EncaissementPenalite> encaissements;

  const LignePenalite({
    this.id,
    required this.vehiculeId,
    this.vehiculeImmatriculation,
    required this.chauffeurId,
    this.chauffeurNomComplet,
    this.penaliteTemplateId,
    required this.typePenalite,
    required this.typeSanction,
    required this.montant,
    required this.montantEncaisse,
    this.montantRestant,
    this.dureeSanctionSecondes,
    this.dureeImmobilisationMinutes,
    this.dateDebutImmobilisation,
    this.dateFinImmobilisation,
    required this.dateGeneration,
    this.dateFaute,
    this.ligneRecetteId,
    required this.statut,
    this.commentaire,
    this.motifAnnulation,
    this.encaissements = const [],
  });

  bool get isEncaissable =>
      typeSanction == TypeSanctionLigne.amende && !statut.isTerminal;

  bool get isExecutable =>
      typeSanction == TypeSanctionLigne.buzzer &&
      statut == StatutLignePenalite.enAttente;

  bool get isNotifiable =>
      typeSanction == TypeSanctionLigne.avertissement &&
      statut == StatutLignePenalite.enAttente;

  bool get isDemarrable =>
      typeSanction == TypeSanctionLigne.immobilisation &&
      statut == StatutLignePenalite.enAttente;

  bool get isLevable =>
      typeSanction == TypeSanctionLigne.immobilisation &&
      statut == StatutLignePenalite.enCours;
}

import 'package:flutter/material.dart';

import '../enums/frequence_versement.dart';
import '../enums/jour_semaine.dart';
import '../enums/mode_encaissement.dart';
import '../enums/type_recette_configuration.dart';
import 'cotisation_recette.dart';

class ConfigurationRecette {
  final int? id;
  final int vehiculeId;
  final ModeEncaissement modeEncaissement;
  final TypeRecetteConfiguration typeRecette;
  final FrequenceVersement frequenceVersement;
  final JourSemaine? jourVersement;
  final TimeOfDay heureLimiteVersement;
  final double? montantObjectifParChauffeur;
  final double? montantJourSalaire;
  final List<CotisationRecette> cotisations;

  const ConfigurationRecette({
    this.id,
    required this.vehiculeId,
    required this.modeEncaissement,
    required this.typeRecette,
    required this.frequenceVersement,
    this.jourVersement,
    required this.heureLimiteVersement,
    this.montantObjectifParChauffeur,
    this.montantJourSalaire,
    this.cotisations = const [],
  });

  factory ConfigurationRecette.defaultForVehicule(int vehiculeId) {
    return ConfigurationRecette(
      vehiculeId: vehiculeId,
      modeEncaissement: ModeEncaissement.lesDeux,
      typeRecette: TypeRecetteConfiguration.montantReel,
      frequenceVersement: FrequenceVersement.journalier,
      heureLimiteVersement: const TimeOfDay(hour: 18, minute: 30),
    );
  }

  bool get isNew => id == null;

  bool get isMontantFixe =>
      typeRecette == TypeRecetteConfiguration.montantFixe;

  bool get hasCotisations => cotisations.isNotEmpty;

  double get totalCotisations =>
      cotisations.fold(0, (sum, item) => sum + item.montant);

  List<CotisationRecette> get cotisationsTriees {
    final copy = [...cotisations];
    copy.sort((a, b) => a.ordre.compareTo(b.ordre));
    return copy;
  }

  ConfigurationRecette copyWith({
    int? id,
    int? vehiculeId,
    ModeEncaissement? modeEncaissement,
    TypeRecetteConfiguration? typeRecette,
    FrequenceVersement? frequenceVersement,
    JourSemaine? jourVersement,
    bool clearJourVersement = false,
    TimeOfDay? heureLimiteVersement,
    double? montantObjectifParChauffeur,
    bool clearMontantObjectifParChauffeur = false,
    double? montantJourSalaire,
    bool clearMontantJourSalaire = false,
    List<CotisationRecette>? cotisations,
  }) {
    return ConfigurationRecette(
      id: id ?? this.id,
      vehiculeId: vehiculeId ?? this.vehiculeId,
      modeEncaissement: modeEncaissement ?? this.modeEncaissement,
      typeRecette: typeRecette ?? this.typeRecette,
      frequenceVersement: frequenceVersement ?? this.frequenceVersement,
      jourVersement: clearJourVersement
          ? null
          : (jourVersement ?? this.jourVersement),
      heureLimiteVersement: heureLimiteVersement ?? this.heureLimiteVersement,
      montantObjectifParChauffeur: clearMontantObjectifParChauffeur
          ? null
          : (montantObjectifParChauffeur ?? this.montantObjectifParChauffeur),
      montantJourSalaire: clearMontantJourSalaire
          ? null
          : (montantJourSalaire ?? this.montantJourSalaire),
      cotisations: cotisations ?? this.cotisations,
    );
  }
}

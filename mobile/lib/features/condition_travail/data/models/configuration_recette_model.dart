import 'package:flutter/material.dart';

import '../../domain/entities/configuration_recette.dart';
import '../../domain/entities/cotisation_recette.dart';
import '../../domain/enums/frequence_versement.dart';
import '../../domain/enums/jour_semaine.dart';
import '../../domain/enums/mode_encaissement.dart';
import '../../domain/enums/type_recette_configuration.dart';

class ConfigurationRecetteModel extends ConfigurationRecette {
  const ConfigurationRecetteModel({
    super.id,
    required super.vehiculeId,
    required super.modeEncaissement,
    required super.typeRecette,
    required super.frequenceVersement,
    super.jourVersement,
    required super.heureLimiteVersement,
    super.montantObjectifParChauffeur,
    super.montantJourSalaire,
    super.cotisations,
  });

  factory ConfigurationRecetteModel.fromJson(Map<String, dynamic> json) {
    final rawCotisations = json['cotisations'] as List?;

    return ConfigurationRecetteModel(
      id: json['id'] as int?,
      vehiculeId: json['vehiculeId'] as int? ?? 0,
      modeEncaissement:
          ModeEncaissement.fromJson(json['modeEncaissement']) ??
              ModeEncaissement.lesDeux,
      typeRecette:
          TypeRecetteConfiguration.fromJson(json['typeRecette']) ??
              TypeRecetteConfiguration.montantReel,
      frequenceVersement:
          FrequenceVersement.fromJson(json['frequenceVersement']) ??
              FrequenceVersement.journalier,
      jourVersement: JourSemaine.fromJson(json['jourVersement']),
      heureLimiteVersement: _parseTime(json['heureLimiteVersement']) ??
          const TimeOfDay(hour: 18, minute: 30),
      montantObjectifParChauffeur:
          _parseMoney(json['montantObjectifParChauffeur']),
      montantJourSalaire: _parseMoney(json['montantJourSalaire']),
      cotisations: [
        if (rawCotisations != null)
          for (final item in rawCotisations)
            _cotisationFromJson(item as Map<String, dynamic>),
      ],
    );
  }

  factory ConfigurationRecetteModel.fromEntity(
    ConfigurationRecette configuration,
  ) {
    return ConfigurationRecetteModel(
      id: configuration.id,
      vehiculeId: configuration.vehiculeId,
      modeEncaissement: configuration.modeEncaissement,
      typeRecette: configuration.typeRecette,
      frequenceVersement: configuration.frequenceVersement,
      jourVersement: configuration.jourVersement,
      heureLimiteVersement: configuration.heureLimiteVersement,
      montantObjectifParChauffeur: configuration.montantObjectifParChauffeur,
      montantJourSalaire: configuration.montantJourSalaire,
      cotisations: configuration.cotisations,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'modeEncaissement': modeEncaissement.toJson(),
      'typeRecette': typeRecette.toJson(),
      'frequenceVersement': frequenceVersement.toJson(),
      if (jourVersement != null) 'jourVersement': jourVersement!.toJson(),
      'heureLimiteVersement': _formatTime(heureLimiteVersement),
      if (montantObjectifParChauffeur != null)
        'montantObjectifParChauffeur': montantObjectifParChauffeur,
      if (montantJourSalaire != null) 'montantJourSalaire': montantJourSalaire,
      'cotisations': cotisations
          .map(
            (cotisation) => {
              'nom': cotisation.nom,
              'montant': cotisation.montant,
              'ordre': cotisation.ordre,
            },
          )
          .toList(),
    };
  }

  static CotisationRecette _cotisationFromJson(Map<String, dynamic> json) {
    return CotisationRecette(
      id: json['id'] as int?,
      nom: json['nom'] as String? ?? '',
      montant: _parseMoney(json['montant']) ?? 0,
      ordre: json['ordre'] as int? ?? 1,
    );
  }

  static double? _parseMoney(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static TimeOfDay? _parseTime(dynamic value) {
    if (value == null) return null;
    final parts = value.toString().split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  static String _formatTime(TimeOfDay value) {
    final hh = value.hour.toString().padLeft(2, '0');
    final mm = value.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}

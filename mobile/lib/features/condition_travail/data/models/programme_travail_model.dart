import 'package:flutter/material.dart';

import '../../../chauffeur/domain/entities/chauffeur.dart';
import '../../../chauffeur/domain/enums/chauffeur_status.dart';
import '../../../chauffeur/domain/enums/type_chauffeur.dart';
import '../../domain/entities/programme_chauffeur.dart';
import '../../domain/entities/programme_travail.dart';
import '../../domain/enums/jour_semaine.dart';
import '../../domain/enums/mode_alternance.dart';
import '../../domain/enums/type_programme_travail.dart';

class ProgrammeTravailModel extends ProgrammeTravail {
  const ProgrammeTravailModel({
    super.id,
    required super.vehiculeId,
    required super.nombreChauffeursAutorises,
    required super.typeProgramme,
    required super.heureDebutService,
    required super.heureFinService,
    required super.modeAlternance,
    super.joursAlternance,
    super.dateDebutAlternance,
    super.joursAlternanceSemaine,
    required super.jourSalaireActif,
    super.jourSalaire,
    super.chauffeurs,
  });

  factory ProgrammeTravailModel.fromJson(Map<String, dynamic> json) {
    final rawChauffeurs = json['chauffeurs'] as List?;

    return ProgrammeTravailModel(
      id: json['id'] as int?,
      vehiculeId: json['vehiculeId'] as int? ?? 0,
      nombreChauffeursAutorises: json['nombreChauffeursAutorises'] as int? ?? 1,
      typeProgramme: TypeProgrammeTravail.fromJson(json['typeProgramme']) ??
          TypeProgrammeTravail.journalier,
      heureDebutService: _parseTime(json['heureDebutService']) ??
          const TimeOfDay(hour: 8, minute: 0),
      heureFinService: _parseTime(json['heureFinService']) ??
          const TimeOfDay(hour: 20, minute: 0),
      modeAlternance: ModeAlternance.fromJson(json['modeAlternance']) ??
          ModeAlternance.manuelle,
      joursAlternance: json['joursAlternance'] as int?,
      dateDebutAlternance: json['dateDebutAlternance'] != null
          ? DateTime.tryParse(json['dateDebutAlternance'] as String)
          : null,
      joursAlternanceSemaine:
          _parseJoursSemaine(json['joursAlternanceSemaine']),
      jourSalaireActif: json['jourSalaireActif'] as bool? ?? false,
      jourSalaire: JourSemaine.fromJson(json['jourSalaire']),
      chauffeurs: [
        if (rawChauffeurs != null)
          for (final c in rawChauffeurs)
            _programmeChauffeurFromJson(c as Map<String, dynamic>),
      ],
    );
  }

  factory ProgrammeTravailModel.fromEntity(ProgrammeTravail programme) {
    return ProgrammeTravailModel(
      id: programme.id,
      vehiculeId: programme.vehiculeId,
      nombreChauffeursAutorises: programme.nombreChauffeursAutorises,
      typeProgramme: programme.typeProgramme,
      heureDebutService: programme.heureDebutService,
      heureFinService: programme.heureFinService,
      modeAlternance: programme.modeAlternance,
      joursAlternance: programme.joursAlternance,
      dateDebutAlternance: programme.dateDebutAlternance,
      joursAlternanceSemaine: programme.joursAlternanceSemaine,
      jourSalaireActif: programme.jourSalaireActif,
      jourSalaire: programme.jourSalaire,
      chauffeurs: programme.chauffeurs,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nombreChauffeursAutorises': nombreChauffeursAutorises,
      'typeProgramme': typeProgramme.toJson(),
      'heureDebutService': _formatTime(heureDebutService),
      'heureFinService': _formatTime(heureFinService),
      'modeAlternance': modeAlternance.toJson(),
      if (joursAlternance != null) 'joursAlternance': joursAlternance,
      if (dateDebutAlternance != null)
        'dateDebutAlternance':
            dateDebutAlternance!.toIso8601String().substring(0, 10),
      if (joursAlternanceSemaine.isNotEmpty)
        'joursAlternanceSemaine':
            joursAlternanceSemaine.map((j) => j.toJson()).toList(),
      'jourSalaireActif': jourSalaireActif,
      if (jourSalaire != null) 'jourSalaire': jourSalaire!.toJson(),
      'chauffeurs': chauffeurs
          .map((pc) => {
                'chauffeurId': pc.chauffeurId,
                'ordreAlternance': pc.ordreAlternance,
                if (pc.ordreJourSalaire != null)
                  'ordreJourSalaire': pc.ordreJourSalaire,
                if (pc.dateService != null)
                  'dateService':
                      pc.dateService!.toIso8601String().substring(0, 10),
              })
          .toList(),
    };
  }

  static ProgrammeChauffeur _programmeChauffeurFromJson(
    Map<String, dynamic> json,
  ) {
    return ProgrammeChauffeur(
      id: json['id'] as int?,
      chauffeur: Chauffeur(
        id: json['chauffeurId'] as int?,
        nom: json['nom'] as String? ?? '',
        prenom: json['prenom'] as String? ?? '',
        telephone: json['telephone'] as String?,
        photoUrl: json['photoUrl'] as String?,
        type: TypeChauffeur.fromJson(json['type']),
        statut: ChauffeurStatus.fromJson(json['statut']),
      ),
      ordreAlternance: json['ordreAlternance'] as int? ?? 1,
      ordreJourSalaire: json['ordreJourSalaire'] as int?,
      dateService: json['dateService'] != null
          ? DateTime.tryParse(json['dateService'] as String)
          : null,
    );
  }

  static Set<JourSemaine> _parseJoursSemaine(dynamic value) {
    if (value == null) return {};
    final list = value as List;
    return list
        .map((e) => JourSemaine.fromJson(e))
        .whereType<JourSemaine>()
        .toSet();
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

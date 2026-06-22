import 'package:flutter/material.dart';

import '../enums/jour_semaine.dart';
import '../enums/mode_alternance.dart';
import '../enums/type_programme_travail.dart';
import 'programme_chauffeur.dart';

class ProgrammeTravail {
  final int? id;
  final int vehiculeId;
  final int nombreChauffeursAutorises;
  final TypeProgrammeTravail typeProgramme;
  final TimeOfDay heureDebutService;
  final TimeOfDay heureFinService;
  final ModeAlternance modeAlternance;
  final int? joursAlternance;
  final DateTime? dateDebutAlternance;
  final Set<JourSemaine> joursAlternanceSemaine;
  final bool jourSalaireActif;
  final JourSemaine? jourSalaire;
  final List<ProgrammeChauffeur> chauffeurs;

  const ProgrammeTravail({
    this.id,
    required this.vehiculeId,
    required this.nombreChauffeursAutorises,
    required this.typeProgramme,
    required this.heureDebutService,
    required this.heureFinService,
    required this.modeAlternance,
    this.joursAlternance,
    this.dateDebutAlternance,
    this.joursAlternanceSemaine = const {},
    required this.jourSalaireActif,
    this.jourSalaire,
    this.chauffeurs = const [],
  });

  factory ProgrammeTravail.defaultForVehicule(int vehiculeId) {
    return ProgrammeTravail(
      vehiculeId: vehiculeId,
      nombreChauffeursAutorises: 1,
      typeProgramme: TypeProgrammeTravail.journalier,
      heureDebutService: const TimeOfDay(hour: 8, minute: 0),
      heureFinService: const TimeOfDay(hour: 20, minute: 0),
      modeAlternance: ModeAlternance.manuelle,
      joursAlternanceSemaine: const {},
      jourSalaireActif: false,
      jourSalaire: JourSemaine.dimanche,
    );
  }

  List<ProgrammeChauffeur> get chauffeursTriesAlternance {
    final copy = [...chauffeurs];
    copy.sort((a, b) => a.ordreAlternance.compareTo(b.ordreAlternance));
    return copy;
  }

  bool get peutInverser => chauffeurs.length >= 2;

  bool get isNew => id == null;

  ProgrammeTravail copyWith({
    int? id,
    int? vehiculeId,
    int? nombreChauffeursAutorises,
    TypeProgrammeTravail? typeProgramme,
    TimeOfDay? heureDebutService,
    TimeOfDay? heureFinService,
    ModeAlternance? modeAlternance,
    int? joursAlternance,
    DateTime? dateDebutAlternance,
    Set<JourSemaine>? joursAlternanceSemaine,
    bool? jourSalaireActif,
    JourSemaine? jourSalaire,
    List<ProgrammeChauffeur>? chauffeurs,
  }) {
    return ProgrammeTravail(
      id: id ?? this.id,
      vehiculeId: vehiculeId ?? this.vehiculeId,
      nombreChauffeursAutorises:
          nombreChauffeursAutorises ?? this.nombreChauffeursAutorises,
      typeProgramme: typeProgramme ?? this.typeProgramme,
      heureDebutService: heureDebutService ?? this.heureDebutService,
      heureFinService: heureFinService ?? this.heureFinService,
      modeAlternance: modeAlternance ?? this.modeAlternance,
      joursAlternance: joursAlternance ?? this.joursAlternance,
      dateDebutAlternance: dateDebutAlternance ?? this.dateDebutAlternance,
      joursAlternanceSemaine:
          joursAlternanceSemaine ?? this.joursAlternanceSemaine,
      jourSalaireActif: jourSalaireActif ?? this.jourSalaireActif,
      jourSalaire: jourSalaire ?? this.jourSalaire,
      chauffeurs: chauffeurs ?? this.chauffeurs,
    );
  }
}

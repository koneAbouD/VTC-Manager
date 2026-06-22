import '../../../chauffeur/domain/entities/chauffeur.dart';

class ProgrammeChauffeur {
  final int? id;
  final Chauffeur chauffeur;
  final int ordreAlternance;
  final int? ordreJourSalaire;
  final DateTime? dateService;

  const ProgrammeChauffeur({
    this.id,
    required this.chauffeur,
    required this.ordreAlternance,
    this.ordreJourSalaire,
    this.dateService,
  });

  int get chauffeurId => chauffeur.id ?? 0;

  String get nomComplet => chauffeur.fullName;

  ProgrammeChauffeur copyWith({
    int? id,
    Chauffeur? chauffeur,
    int? ordreAlternance,
    int? ordreJourSalaire,
    DateTime? dateService,
  }) {
    return ProgrammeChauffeur(
      id: id ?? this.id,
      chauffeur: chauffeur ?? this.chauffeur,
      ordreAlternance: ordreAlternance ?? this.ordreAlternance,
      ordreJourSalaire: ordreJourSalaire ?? this.ordreJourSalaire,
      dateService: dateService ?? this.dateService,
    );
  }
}

class Indisponibilite {
  final int? id;
  final int chauffeurId;
  final String? chauffeurNom;
  final int? chauffeurRemplacantId;
  final String? chauffeurRemplacantNom;
  final DateTime dateDebut;
  final DateTime? dateFin;
  final String? motif;
  final String? commentaire;
  final String? statut; // PLANIFIEE, EN_COURS, TERMINEE, ANNULEE

  const Indisponibilite({
    this.id,
    required this.chauffeurId,
    this.chauffeurNom,
    this.chauffeurRemplacantId,
    this.chauffeurRemplacantNom,
    required this.dateDebut,
    this.dateFin,
    this.motif,
    this.commentaire,
    this.statut,
  });

  bool get isEnCours => statut == 'EN_COURS';
  bool get isPlanifiee => statut == 'PLANIFIEE';
  bool get isTerminee => statut == 'TERMINEE';

  Indisponibilite copyWith({
    int? id,
    int? chauffeurId,
    String? chauffeurNom,
    int? chauffeurRemplacantId,
    String? chauffeurRemplacantNom,
    DateTime? dateDebut,
    DateTime? dateFin,
    String? motif,
    String? commentaire,
    String? statut,
  }) {
    return Indisponibilite(
      id: id ?? this.id,
      chauffeurId: chauffeurId ?? this.chauffeurId,
      chauffeurNom: chauffeurNom ?? this.chauffeurNom,
      chauffeurRemplacantId:
          chauffeurRemplacantId ?? this.chauffeurRemplacantId,
      chauffeurRemplacantNom:
          chauffeurRemplacantNom ?? this.chauffeurRemplacantNom,
      dateDebut: dateDebut ?? this.dateDebut,
      dateFin: dateFin ?? this.dateFin,
      motif: motif ?? this.motif,
      commentaire: commentaire ?? this.commentaire,
      statut: statut ?? this.statut,
    );
  }
}

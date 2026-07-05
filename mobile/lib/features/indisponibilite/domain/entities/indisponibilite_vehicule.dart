class IndisponibiliteVehicule {
  final int? id;
  final int vehiculeId;
  final String? vehiculeLibelle; // ex. "1234 AB 01 — Toyota Corolla"
  final DateTime dateDebut;
  final DateTime? dateFin;
  final String? motif;
  final String? commentaire;
  final String? statut; // PLANIFIEE, EN_COURS, TERMINEE, ANNULEE

  const IndisponibiliteVehicule({
    this.id,
    required this.vehiculeId,
    this.vehiculeLibelle,
    required this.dateDebut,
    this.dateFin,
    this.motif,
    this.commentaire,
    this.statut,
  });

  bool get isEnCours => statut == 'EN_COURS';
  bool get isPlanifiee => statut == 'PLANIFIEE';
  bool get isTerminee => statut == 'TERMINEE';

  IndisponibiliteVehicule copyWith({
    int? id,
    int? vehiculeId,
    String? vehiculeLibelle,
    DateTime? dateDebut,
    DateTime? dateFin,
    String? motif,
    String? commentaire,
    String? statut,
  }) {
    return IndisponibiliteVehicule(
      id: id ?? this.id,
      vehiculeId: vehiculeId ?? this.vehiculeId,
      vehiculeLibelle: vehiculeLibelle ?? this.vehiculeLibelle,
      dateDebut: dateDebut ?? this.dateDebut,
      dateFin: dateFin ?? this.dateFin,
      motif: motif ?? this.motif,
      commentaire: commentaire ?? this.commentaire,
      statut: statut ?? this.statut,
    );
  }
}

class CotisationRecette {
  final int? id;
  final String nom;
  final double montant;
  final int ordre;

  const CotisationRecette({
    this.id,
    required this.nom,
    required this.montant,
    required this.ordre,
  });

  CotisationRecette copyWith({
    int? id,
    String? nom,
    double? montant,
    int? ordre,
  }) {
    return CotisationRecette(
      id: id ?? this.id,
      nom: nom ?? this.nom,
      montant: montant ?? this.montant,
      ordre: ordre ?? this.ordre,
    );
  }
}

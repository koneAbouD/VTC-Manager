class Depense {
  final int? id;
  final DateTime date;
  final double montant;
  final String? description;
  final int? categorieId;
  final String? categorieNom;
  final int? chauffeurId;
  final String? chauffeurNom;
  final int? vehiculeId;
  final String? vehiculeNom;

  const Depense({
    this.id,
    required this.date,
    required this.montant,
    this.description,
    this.categorieId,
    this.categorieNom,
    this.chauffeurId,
    this.chauffeurNom,
    this.vehiculeId,
    this.vehiculeNom,
  });

  Depense copyWith({
    int? id,
    DateTime? date,
    double? montant,
    String? description,
    int? categorieId,
    String? categorieNom,
    int? chauffeurId,
    String? chauffeurNom,
    int? vehiculeId,
    String? vehiculeNom,
  }) {
    return Depense(
      id: id ?? this.id,
      date: date ?? this.date,
      montant: montant ?? this.montant,
      description: description ?? this.description,
      categorieId: categorieId ?? this.categorieId,
      categorieNom: categorieNom ?? this.categorieNom,
      chauffeurId: chauffeurId ?? this.chauffeurId,
      chauffeurNom: chauffeurNom ?? this.chauffeurNom,
      vehiculeId: vehiculeId ?? this.vehiculeId,
      vehiculeNom: vehiculeNom ?? this.vehiculeNom,
    );
  }
}

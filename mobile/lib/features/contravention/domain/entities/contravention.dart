class Contravention {
  final int? id;
  final DateTime dateInfraction;
  final String? typeInfraction;
  final String? lieu;
  final String? description;
  final double montant;
  final double? cotisation;
  final double? montantPaye;
  final String? statut;
  final DateTime? datePaiement;
  final int? chauffeurId;
  final String? chauffeurNom;
  final int? vehiculeId;
  final String? vehiculeNom;

  const Contravention({
    this.id,
    required this.dateInfraction,
    this.typeInfraction,
    this.lieu,
    this.description,
    required this.montant,
    this.cotisation,
    this.montantPaye,
    this.statut,
    this.datePaiement,
    this.chauffeurId,
    this.chauffeurNom,
    this.vehiculeId,
    this.vehiculeNom,
  });

  bool get isPaid => statut == 'PAYEE';
  bool get isPartial => statut == 'PARTIELLEMENT_PAYEE';

  Contravention copyWith({
    int? id,
    DateTime? dateInfraction,
    String? typeInfraction,
    String? lieu,
    String? description,
    double? montant,
    double? cotisation,
    double? montantPaye,
    String? statut,
    DateTime? datePaiement,
    int? chauffeurId,
    String? chauffeurNom,
    int? vehiculeId,
    String? vehiculeNom,
  }) {
    return Contravention(
      id: id ?? this.id,
      dateInfraction: dateInfraction ?? this.dateInfraction,
      typeInfraction: typeInfraction ?? this.typeInfraction,
      lieu: lieu ?? this.lieu,
      description: description ?? this.description,
      montant: montant ?? this.montant,
      cotisation: cotisation ?? this.cotisation,
      montantPaye: montantPaye ?? this.montantPaye,
      statut: statut ?? this.statut,
      datePaiement: datePaiement ?? this.datePaiement,
      chauffeurId: chauffeurId ?? this.chauffeurId,
      chauffeurNom: chauffeurNom ?? this.chauffeurNom,
      vehiculeId: vehiculeId ?? this.vehiculeId,
      vehiculeNom: vehiculeNom ?? this.vehiculeNom,
    );
  }
}

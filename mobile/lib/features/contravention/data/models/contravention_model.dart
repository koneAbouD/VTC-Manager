import '../../domain/entities/contravention.dart';

class ContraventionModel extends Contravention {
  const ContraventionModel({
    super.id,
    required super.dateInfraction,
    super.typeInfraction,
    super.lieu,
    super.description,
    required super.montant,
    super.cotisation,
    super.montantPaye,
    super.statut,
    super.datePaiement,
    super.chauffeurId,
    super.chauffeurNom,
    super.vehiculeId,
    super.vehiculeNom,
  });

  factory ContraventionModel.fromJson(Map<String, dynamic> json) {
    final chauffeurJson = json['chauffeur'] as Map<String, dynamic>?;
    final vehiculeJson = json['vehicule'] as Map<String, dynamic>?;

    final prenom = chauffeurJson?['prenom'] as String? ?? '';
    final nom = chauffeurJson?['nom'] as String? ?? '';
    final chauffeurNom = '$prenom $nom'.trim();

    final marque = vehiculeJson?['marque'] as String? ?? '';
    final modele = vehiculeJson?['modele'] as String? ?? '';
    final vehiculeNom = '$marque $modele'.trim();

    return ContraventionModel(
      id: json['id'] as int?,
      dateInfraction: DateTime.parse(json['dateInfraction'] as String),
      typeInfraction: json['typeInfraction'] as String?,
      lieu: json['lieu'] as String?,
      description: json['description'] as String?,
      montant: (json['montant'] as num).toDouble(),
      cotisation: json['cotisation'] != null
          ? (json['cotisation'] as num).toDouble()
          : null,
      montantPaye: json['montantPaye'] != null
          ? (json['montantPaye'] as num).toDouble()
          : null,
      statut: json['statut'] as String?,
      datePaiement: json['datePaiement'] != null
          ? DateTime.parse(json['datePaiement'] as String)
          : null,
      chauffeurId: chauffeurJson?['id'] as int?,
      chauffeurNom: chauffeurNom.isEmpty ? null : chauffeurNom,
      vehiculeId: vehiculeJson?['id'] as int?,
      vehiculeNom: vehiculeNom.isEmpty ? null : vehiculeNom,
    );
  }

  factory ContraventionModel.fromEntity(Contravention c) =>
      ContraventionModel(
        id: c.id,
        dateInfraction: c.dateInfraction,
        typeInfraction: c.typeInfraction,
        lieu: c.lieu,
        description: c.description,
        montant: c.montant,
        cotisation: c.cotisation,
        montantPaye: c.montantPaye,
        statut: c.statut,
        datePaiement: c.datePaiement,
        chauffeurId: c.chauffeurId,
        chauffeurNom: c.chauffeurNom,
        vehiculeId: c.vehiculeId,
        vehiculeNom: c.vehiculeNom,
      );

  Map<String, dynamic> toJson() => {
        'dateInfraction':
            dateInfraction.toIso8601String().substring(0, 10),
        if (typeInfraction != null) 'typeInfraction': typeInfraction,
        if (lieu != null) 'lieu': lieu,
        if (description != null) 'description': description,
        'montant': montant,
        if (cotisation != null) 'cotisation': cotisation,
        if (montantPaye != null) 'montantPaye': montantPaye,
        if (statut != null) 'statut': statut,
        if (datePaiement != null)
          'datePaiement': datePaiement!.toIso8601String().substring(0, 10),
        if (chauffeurId != null) 'chauffeurId': chauffeurId,
        if (vehiculeId != null) 'vehiculeId': vehiculeId,
      };
}

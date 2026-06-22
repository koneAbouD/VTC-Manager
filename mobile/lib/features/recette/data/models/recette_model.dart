import '../../domain/entities/recette.dart';

class RecetteModel extends Recette {
  const RecetteModel({
    super.id,
    required super.date,
    required super.montant,
    super.description,
    super.categorieId,
    super.categorieNom,
    super.chauffeurId,
    super.chauffeurNom,
    super.vehiculeId,
    super.vehiculeNom,
  });

  factory RecetteModel.fromJson(Map<String, dynamic> json) {
    final categorieJson = json['categorie'] as Map<String, dynamic>?;
    final chauffeurJson = json['chauffeur'] as Map<String, dynamic>?;
    final vehiculeJson = json['vehicule'] as Map<String, dynamic>?;

    final prenom = chauffeurJson?['prenom'] as String? ?? '';
    final nom = chauffeurJson?['nom'] as String? ?? '';
    final chauffeurNom = '$prenom $nom'.trim();

    final marque = vehiculeJson?['marque'] as String? ?? '';
    final modele = vehiculeJson?['modele'] as String? ?? '';
    final vehiculeNom = '$marque $modele'.trim();

    return RecetteModel(
      id: json['id'] as int?,
      date: DateTime.parse(json['date'] as String),
      montant: (json['montant'] as num).toDouble(),
      description: json['description'] as String?,
      categorieId: categorieJson?['id'] as int?,
      categorieNom: categorieJson?['nom'] as String?,
      chauffeurId: chauffeurJson?['id'] as int?,
      chauffeurNom: chauffeurNom.isEmpty ? null : chauffeurNom,
      vehiculeId: vehiculeJson?['id'] as int?,
      vehiculeNom: vehiculeNom.isEmpty ? null : vehiculeNom,
    );
  }

  factory RecetteModel.fromEntity(Recette r) => RecetteModel(
        id: r.id,
        date: r.date,
        montant: r.montant,
        description: r.description,
        categorieId: r.categorieId,
        categorieNom: r.categorieNom,
        chauffeurId: r.chauffeurId,
        chauffeurNom: r.chauffeurNom,
        vehiculeId: r.vehiculeId,
        vehiculeNom: r.vehiculeNom,
      );

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String().substring(0, 10),
        'montant': montant,
        if (description != null) 'description': description,
        if (categorieId != null) 'categorieId': categorieId,
        if (chauffeurId != null) 'chauffeurId': chauffeurId,
        if (vehiculeId != null) 'vehiculeId': vehiculeId,
      };
}

class Categorie {
  final int? id;
  final String nom;
  final String? description;
  final String type; // RECETTE | DEPENSE

  const Categorie({
    this.id,
    required this.nom,
    this.description,
    required this.type,
  });

  factory Categorie.fromJson(Map<String, dynamic> json) => Categorie(
        id: json['id'] as int?,
        nom: json['nom'] as String,
        description: json['description'] as String?,
        type: json['type'] as String,
      );
}

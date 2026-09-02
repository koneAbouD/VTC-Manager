/// Un chauffeur portant des créances sur plusieurs véhicules le même jour.
///
/// La génération quotidienne ne bloque pas ce cas — une recette non créée
/// serait de l'argent que personne ne réclame — mais elle le signale. Le cas se
/// produit naturellement quand un titulaire remplace un collègue absent sans
/// être retiré de son propre programme.
class ConflitChauffeur {
  final DateTime date;
  final int chauffeurId;
  final String chauffeurNom;
  final List<String> immatriculations;

  const ConflitChauffeur({
    required this.date,
    required this.chauffeurId,
    required this.chauffeurNom,
    required this.immatriculations,
  });

  factory ConflitChauffeur.fromJson(Map<String, dynamic> json) {
    return ConflitChauffeur(
      date: DateTime.parse(json['date'] as String),
      chauffeurId: json['chauffeurId'] as int,
      chauffeurNom: json['chauffeurNom'] as String? ?? 'Chauffeur',
      immatriculations: (json['immatriculations'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

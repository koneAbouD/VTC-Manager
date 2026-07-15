/// Profil du chauffeur connecté.
class Profil {
  final int id;
  final String nom;
  final String prenom;
  final String? telephone;
  final String? vehiculeImmatriculation;
  final String? vehiculeMarque;
  final String? vehiculeModele;

  const Profil({
    required this.id,
    required this.nom,
    required this.prenom,
    this.telephone,
    this.vehiculeImmatriculation,
    this.vehiculeMarque,
    this.vehiculeModele,
  });

  String get nomComplet => '$prenom $nom'.trim();

  bool get aVehicule => vehiculeImmatriculation != null;

  /// Libellé véhicule : « immat • marque modèle ».
  String get vehiculeLibelle {
    if (!aVehicule) return 'Aucun véhicule';
    final details = [?vehiculeMarque, ?vehiculeModele].join(' ');
    return details.isEmpty
        ? vehiculeImmatriculation!
        : '$vehiculeImmatriculation • $details';
  }
}

import '../../domain/entities/profil.dart';

class ProfilModel extends Profil {
  const ProfilModel({
    required super.id,
    required super.nom,
    required super.prenom,
    super.telephone,
    super.vehiculeImmatriculation,
    super.vehiculeMarque,
    super.vehiculeModele,
  });

  factory ProfilModel.fromJson(Map<String, dynamic> j) {
    final veh = j['vehicule'] as Map?;
    return ProfilModel(
      id: j['id'] as int,
      nom: (j['nom'] ?? '') as String,
      prenom: (j['prenom'] ?? '') as String,
      telephone: j['telephone'] as String?,
      vehiculeImmatriculation: veh?['immatriculation'] as String?,
      vehiculeMarque: (veh?['marque'] as Map?)?['nom'] as String?,
      vehiculeModele: (veh?['modele'] as Map?)?['nom'] as String?,
    );
  }
}

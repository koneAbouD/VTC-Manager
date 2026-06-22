import '../../../condition_travail/data/models/programme_travail_model.dart';
import '../../domain/entities/chauffeur.dart';
import '../../domain/enums/chauffeur_status.dart';
import '../../domain/enums/genre.dart';
import '../../domain/enums/type_chauffeur.dart';
import 'geolocalisation_model.dart';

/// Miroir de [ChauffeurResponse] côté backend.
class ChauffeurModel extends Chauffeur {
  const ChauffeurModel({
    super.id,
    required super.nom,
    required super.prenom,
    super.genre,
    super.type,
    super.dateNaissance,
    super.photoUrl,
    super.photoBase64,
    super.permisConduire,
    super.telephone,
    super.email,
    super.adresse,
    super.statut,
    super.dateEmbauche,
    super.geolocalisation,
    super.vehiculeId,
    super.vehiculeNom,
    super.vehiculeModele,
    super.vehiculeMatricule,
    super.programmeTravail,
  });

  factory ChauffeurModel.fromJson(Map<String, dynamic> json) {
    // Programme de travail (présent uniquement dans GET /chauffeurs/{id})
    final programmeJson = json['programmeTravail'] as Map<String, dynamic>?;
    final programme =
        programmeJson != null ? ProgrammeTravailModel.fromJson(programmeJson) : null;

    // Véhicule (projection légère)
    final vehiculeJson = json['vehicule'] as Map<String, dynamic>?;
    final vehiculeId = vehiculeJson?['id'] as int?;
    final marqueRaw = vehiculeJson?['marque'];
    final modeleRaw = vehiculeJson?['modele'];
    final marque = marqueRaw is Map<String, dynamic>
        ? (marqueRaw['nom'] as String? ?? '')
        : (marqueRaw as String? ?? '');
    final modele = modeleRaw is Map<String, dynamic>
        ? (modeleRaw['nom'] as String? ?? '')
        : (modeleRaw as String? ?? '');
    final vehiculeNom = '$marque $modele'.trim();
    final vehiculeMatricule = vehiculeJson?['immatriculation'] as String?;

    // Géolocalisation
    final geoJson = json['geolocalisation'] as Map<String, dynamic>?;
    final geo = geoJson != null ? GeolocalisationModel.fromJson(geoJson) : null;

    return ChauffeurModel(
      id: json['id'] as int?,
      nom: json['nom'] as String,
      prenom: json['prenom'] as String,
      genre: Genre.fromJson(json['genre']),
      type: TypeChauffeur.fromJson(json['type']),
      dateNaissance: json['dateNaissance'] != null
          ? DateTime.tryParse(json['dateNaissance'] as String)
          : null,
      photoUrl: json['photoUrl'] as String?,
      photoBase64: json['photoBase64'] as String?,
      permisConduire: const [],
      telephone: json['telephone'] as String?,
      email: json['email'] as String?,
      adresse: json['adresse'] as String?,
      statut: ChauffeurStatus.fromJson(json['statut']),
      dateEmbauche: json['dateEmbauche'] != null
          ? DateTime.tryParse(json['dateEmbauche'] as String)
          : null,
      geolocalisation: geo,
      vehiculeId: vehiculeId,
      vehiculeNom: vehiculeNom.isEmpty ? null : vehiculeNom,
      vehiculeModele: modele.isEmpty ? null : modele,
      vehiculeMatricule: vehiculeMatricule,
      programmeTravail: programme,
    );
  }

  factory ChauffeurModel.fromEntity(Chauffeur c) => ChauffeurModel(
        id: c.id,
        nom: c.nom,
        prenom: c.prenom,
        genre: c.genre,
        type: c.type,
        dateNaissance: c.dateNaissance,
        photoUrl: c.photoUrl,
        photoBase64: c.photoBase64,
        permisConduire: c.permisConduire,
        telephone: c.telephone,
        email: c.email,
        adresse: c.adresse,
        statut: c.statut,
        dateEmbauche: c.dateEmbauche,
        geolocalisation: c.geolocalisation,
        vehiculeId: c.vehiculeId,
        vehiculeNom: c.vehiculeNom,
        vehiculeModele: c.vehiculeModele,
        vehiculeMatricule: c.vehiculeMatricule,
        programmeTravail: c.programmeTravail,
      );
}

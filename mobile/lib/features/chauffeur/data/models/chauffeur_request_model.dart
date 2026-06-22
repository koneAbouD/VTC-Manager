import '../../domain/entities/chauffeur.dart';
import '../../domain/enums/chauffeur_status.dart';
import '../../domain/enums/genre.dart';
import '../../domain/enums/type_chauffeur.dart';
import '../../domain/enums/type_permis.dart';

/// Miroir plat du record `ChauffeurRequest` côté backend.
///
/// Le backend n'accepte qu'**un seul** permis à la création/modification ;
/// [fromChauffeur] privilégie le premier permis de la liste.
class ChauffeurRequestModel {
  final String nom;
  final String prenom;
  final Genre? genre;
  final TypeChauffeur? type;
  final DateTime? dateNaissance;
  final String? telephone;
  final String? email;
  final String? adresse;
  final ChauffeurStatus? statut;
  final DateTime? dateEmbauche;

  // Données du permis (plat, comme ChauffeurRequest côté backend)
  final String numeroPermis;
  final Set<TypePermis> typesPermis;
  final DateTime? dateEmissionPermis;
  final DateTime? dateExpirationPermis;

  /// Si `true`, demande au backend de supprimer la photo existante.
  final bool deletePhoto;

  const ChauffeurRequestModel({
    required this.nom,
    required this.prenom,
    this.genre,
    this.type,
    this.dateNaissance,
    this.telephone,
    this.email,
    this.adresse,
    this.statut,
    this.dateEmbauche,
    required this.numeroPermis,
    required this.typesPermis,
    this.dateEmissionPermis,
    this.dateExpirationPermis,
    this.deletePhoto = false,
  });

  /// Construit le DTO à partir d'un [Chauffeur] domaine.
  /// Les params [numeroPermis], [typesPermisStr], [dateEmissionPermis],
  /// [dateExpirationPermis] permettent de passer les données permis
  /// directement depuis la vue (ex: depuis un _PendingDocument).
  factory ChauffeurRequestModel.fromChauffeur(
    Chauffeur chauffeur, {
    String? numeroPermis,
    List<String>? typesPermisStr,
    DateTime? dateEmissionPermis,
    DateTime? dateExpirationPermis,
  }) {
    return ChauffeurRequestModel(
      nom: chauffeur.nom,
      prenom: chauffeur.prenom,
      genre: chauffeur.genre,
      type: chauffeur.type,
      dateNaissance: chauffeur.dateNaissance,
      telephone: chauffeur.telephone,
      email: chauffeur.email,
      adresse: chauffeur.adresse,
      statut: chauffeur.statut,
      dateEmbauche: chauffeur.dateEmbauche,
      numeroPermis: numeroPermis ?? '',
      typesPermis: typesPermisStr != null
          ? TypePermis.setFromJson(typesPermisStr)
          : const <TypePermis>{},
      dateEmissionPermis: dateEmissionPermis,
      dateExpirationPermis: dateExpirationPermis,
    );
  }

  ChauffeurRequestModel copyWith({
    bool? deletePhoto,
    String? numeroPermis,
    Set<TypePermis>? typesPermis,
    DateTime? dateEmissionPermis,
    DateTime? dateExpirationPermis,
  }) =>
      ChauffeurRequestModel(
        nom: nom,
        prenom: prenom,
        genre: genre,
        type: type,
        dateNaissance: dateNaissance,
        telephone: telephone,
        email: email,
        adresse: adresse,
        statut: statut,
        dateEmbauche: dateEmbauche,
        numeroPermis: numeroPermis ?? this.numeroPermis,
        typesPermis: typesPermis ?? this.typesPermis,
        dateEmissionPermis: dateEmissionPermis ?? this.dateEmissionPermis,
        dateExpirationPermis: dateExpirationPermis ?? this.dateExpirationPermis,
        deletePhoto: deletePhoto ?? this.deletePhoto,
      );

  Map<String, dynamic> toJson() => {
        'nom': nom,
        'prenom': prenom,
        if (genre != null) 'genre': genre!.toJson(),
        if (type != null) 'type': type!.toJson(),
        if (dateNaissance != null) 'dateNaissance': _toIsoDate(dateNaissance!),
        if (telephone != null) 'telephone': telephone,
        if (email != null) 'email': email,
        if (adresse != null) 'adresse': adresse,
        if (statut != null) 'statut': statut!.toJson(),
        if (dateEmbauche != null) 'dateEmbauche': _toIsoDate(dateEmbauche!),
        'numeroPermis': numeroPermis,
        'typesPermis': typesPermis.map((t) => t.toJson()).toList(),
        if (dateEmissionPermis != null)
          'dateEmissionPermis': _toIsoDate(dateEmissionPermis!),
        if (dateExpirationPermis != null)
          'dateExpirationPermis': _toIsoDate(dateExpirationPermis!),
        if (deletePhoto) 'deletePhoto': true,
      };

  static String _toIsoDate(DateTime d) => d.toIso8601String().substring(0, 10);
}

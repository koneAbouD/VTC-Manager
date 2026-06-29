import '../../../condition_travail/domain/entities/programme_travail.dart';
import '../enums/chauffeur_status.dart';
import '../enums/genre.dart';
import '../enums/type_chauffeur.dart';
import 'geolocalisation.dart';
import 'permis_conduire.dart';

/// Entité domaine d'un chauffeur — miroir de
/// [com.tmk.vtcmanager.application.domain.chauffeur.Chauffeur].
class Chauffeur {
  final int? id;
  final String nom;
  final String prenom;
  final Genre? genre;
  final TypeChauffeur? type;
  final DateTime? dateNaissance;
  final String? photoUrl;

  /// Photo encodée en base64 — présent uniquement dans `GET /chauffeurs/{id}`.
  final String? photoBase64;

  final List<PermisConduire> permisConduire;
  final String? telephone;
  final String? email;
  final String? adresse;
  final ChauffeurStatus? statut;

  /// Date de prise d'effet de la suspension (présente si statut == suspendu).
  final DateTime? dateSuspension;
  final DateTime? dateEmbauche;
  final Geolocalisation? geolocalisation;

  /// Résumé du véhicule assigné (projection légère de `VehiculeResponse`).
  final int? vehiculeId;
  final String? vehiculeNom;
  final String? vehiculeModele;
  final String? vehiculeMatricule;

  /// Programme de travail embarqué — présent uniquement dans `GET /chauffeurs/{id}`.
  final ProgrammeTravail? programmeTravail;

  const Chauffeur({
    this.id,
    required this.nom,
    required this.prenom,
    this.genre,
    this.type,
    this.dateNaissance,
    this.photoUrl,
    this.photoBase64,
    this.permisConduire = const <PermisConduire>[],
    this.telephone,
    this.email,
    this.adresse,
    this.statut,
    this.dateSuspension,
    this.dateEmbauche,
    this.geolocalisation,
    this.vehiculeId,
    this.vehiculeNom,
    this.vehiculeModele,
    this.vehiculeMatricule,
    this.programmeTravail,
  });

  // ── Calculs dérivés (miroir des helpers Java) ──────────────────────────

  String get displayName => '$prenom $nom';

  String get fullName => '$prenom $nom';

  bool get isActif => statut == ChauffeurStatus.actif;

  int? get age {
    if (dateNaissance == null) return null;
    final now = DateTime.now();
    int a = now.year - dateNaissance!.year;
    if (now.month < dateNaissance!.month ||
        (now.month == dateNaissance!.month && now.day < dateNaissance!.day)) {
      a--;
    }
    return a;
  }

  /// `true` si **au moins un** permis est expiré.
  bool get isPermitExpired => permisConduire.any((p) => p.isExpire);

  /// Premier permis (utile pour les écrans "résumé").
  PermisConduire? get permisPrincipal =>
      permisConduire.isEmpty ? null : permisConduire.first;

  Chauffeur copyWith({
    int? id,
    String? nom,
    String? prenom,
    Genre? genre,
    TypeChauffeur? type,
    DateTime? dateNaissance,
    String? photoUrl,
    String? photoBase64,
    List<PermisConduire>? permisConduire,
    String? telephone,
    String? email,
    String? adresse,
    ChauffeurStatus? statut,
    DateTime? dateSuspension,
    DateTime? dateEmbauche,
    Geolocalisation? geolocalisation,
    int? vehiculeId,
    String? vehiculeNom,
    String? vehiculeModele,
    String? vehiculeMatricule,
    ProgrammeTravail? programmeTravail,
  }) {
    return Chauffeur(
      id: id ?? this.id,
      nom: nom ?? this.nom,
      prenom: prenom ?? this.prenom,
      genre: genre ?? this.genre,
      type: type ?? this.type,
      dateNaissance: dateNaissance ?? this.dateNaissance,
      photoUrl: photoUrl ?? this.photoUrl,
      photoBase64: photoBase64 ?? this.photoBase64,
      permisConduire: permisConduire ?? this.permisConduire,
      telephone: telephone ?? this.telephone,
      email: email ?? this.email,
      adresse: adresse ?? this.adresse,
      statut: statut ?? this.statut,
      dateSuspension: dateSuspension ?? this.dateSuspension,
      dateEmbauche: dateEmbauche ?? this.dateEmbauche,
      geolocalisation: geolocalisation ?? this.geolocalisation,
      vehiculeId: vehiculeId ?? this.vehiculeId,
      vehiculeNom: vehiculeNom ?? this.vehiculeNom,
      vehiculeModele: vehiculeModele ?? this.vehiculeModele,
      vehiculeMatricule: vehiculeMatricule ?? this.vehiculeMatricule,
      programmeTravail: programmeTravail ?? this.programmeTravail,
    );
  }
}

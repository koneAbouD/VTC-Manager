import '../../domain/entities/vehicule.dart';

class VehiculeModel extends Vehicule {
  const VehiculeModel({
    super.id,
    required super.immatriculation,
    super.libelle,
    required super.marque,
    required super.modele,
    super.marqueId,
    super.modeleId,
    super.typeVehiculeId,
    super.typeVehiculeNom,
    super.typeActiviteId,
    super.typeActiviteNom,
    super.numeroChassis,
    super.numeroTelephoneBalise,
    super.identifiantBalise,
    super.couleur,
    super.kilometrage,
    super.statut,
    super.dateAchat,
    super.dateProchaineMaintenance,
    super.dateMiseEnCirculation,
    super.dateEntreeFlotte,
    super.groupeId,
    super.groupe,
    super.photos,
  });

  static String? _str(dynamic v) {
    if (v == null) return null;
    if (v is String) return v;
    if (v is Map) {
      return (v['libelle'] ?? v['nom'] ?? v['code'] ?? v['name'])?.toString();
    }
    return v.toString();
  }

  static int? _id(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is Map) return v['id'] as int?;
    return null;
  }

  factory VehiculeModel.fromJson(Map<String, dynamic> json) => VehiculeModel(
        id: json['id'] as int?,
        immatriculation: _str(json['immatriculation']) ?? '',
        libelle: json['libelle'] as String?,
        marque: _str(json['marque']) ?? '',
        modele: _str(json['modele']) ?? '',
        marqueId: _id(json['marque']),
        modeleId: _id(json['modele']),
        typeVehiculeId: _id(json['type']) ?? json['typeVehiculeId'] as int?,
        typeVehiculeNom: _str(json['type']),
        typeActiviteId: _id(json['activite']) ?? json['typeActiviteId'] as int?,
        typeActiviteNom: _str(json['activite']),
        numeroChassis: json['numeroChassis'] as String?,
        numeroTelephoneBalise: json['numeroTelephoneBalise'] as String?,
        identifiantBalise: json['identifiantBalise'] as String?,
        couleur: _str(json['couleur']),
        kilometrage: json['kilometrage'] as int?,
        statut: _str(json['statut']),
        dateAchat: json['dateAchat'] != null
            ? DateTime.parse(json['dateAchat'] as String)
            : null,
        dateProchaineMaintenance: json['dateProchaineMaintenance'] != null
            ? DateTime.parse(json['dateProchaineMaintenance'] as String)
            : null,
        dateMiseEnCirculation: json['dateMiseEnCirculation'] != null
            ? DateTime.parse(json['dateMiseEnCirculation'] as String)
            : null,
        dateEntreeFlotte: json['dateEntreeFlotte'] != null
            ? DateTime.parse(json['dateEntreeFlotte'] as String)
            : null,
        groupeId: _id(json['groupe']),
        groupe: _str(json['groupe']),
        photos: json['photos'] != null
            ? (json['photos'] as List)
                .map((p) => VehiculePhoto.fromJson(p as Map<String, dynamic>))
                .toList()
            : null,
      );

  factory VehiculeModel.fromEntity(Vehicule v) => VehiculeModel(
        id: v.id,
        immatriculation: v.immatriculation,
        libelle: v.libelle,
        marque: v.marque,
        modele: v.modele,
        marqueId: v.marqueId,
        modeleId: v.modeleId,
        typeVehiculeId: v.typeVehiculeId,
        typeVehiculeNom: v.typeVehiculeNom,
        typeActiviteId: v.typeActiviteId,
        typeActiviteNom: v.typeActiviteNom,
        numeroChassis: v.numeroChassis,
        numeroTelephoneBalise: v.numeroTelephoneBalise,
        identifiantBalise: v.identifiantBalise,
        couleur: v.couleur,
        kilometrage: v.kilometrage,
        statut: v.statut,
        dateAchat: v.dateAchat,
        dateProchaineMaintenance: v.dateProchaineMaintenance,
        dateMiseEnCirculation: v.dateMiseEnCirculation,
        dateEntreeFlotte: v.dateEntreeFlotte,
        groupeId: v.groupeId,
        groupe: v.groupe,
        photos: v.photos,
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'immatriculation': immatriculation,
        if (libelle != null && libelle!.isNotEmpty) 'libelle': libelle,
        if (marqueId != null) 'marqueId': marqueId,
        if (modeleId != null) 'modeleId': modeleId,
        if (typeVehiculeId != null) 'typeVehiculeId': typeVehiculeId,
        if (typeActiviteId != null) 'typeActiviteId': typeActiviteId,
        if (numeroChassis != null && numeroChassis!.isNotEmpty)
          'numeroChassis': numeroChassis,
        if (numeroTelephoneBalise != null && numeroTelephoneBalise!.isNotEmpty)
          'numeroTelephoneBalise': numeroTelephoneBalise,
        if (identifiantBalise != null && identifiantBalise!.isNotEmpty)
          'identifiantBalise': identifiantBalise,
        if (couleur != null) 'couleur': couleur,
        if (kilometrage != null) 'kilometrage': kilometrage,
        if (statut != null) 'statut': statut,
        if (dateAchat != null)
          'dateAchat': dateAchat!.toIso8601String().substring(0, 10),
        if (dateProchaineMaintenance != null)
          'dateProchaineMaintenance':
              dateProchaineMaintenance!.toIso8601String().substring(0, 10),
        if (dateMiseEnCirculation != null)
          'dateMiseEnCirculation':
              dateMiseEnCirculation!.toIso8601String().substring(0, 10),
        if (dateEntreeFlotte != null)
          'dateEntreeFlotte':
              dateEntreeFlotte!.toIso8601String().substring(0, 10),
        if (groupeId != null) 'groupeId': groupeId,
      };
}

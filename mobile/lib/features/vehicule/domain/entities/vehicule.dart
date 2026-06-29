class VehiculePhoto {
  final int id;
  final String url;
  final int? ordre;

  const VehiculePhoto({required this.id, required this.url, this.ordre});

  factory VehiculePhoto.fromJson(Map<String, dynamic> j) => VehiculePhoto(
        id: j['id'] as int,
        url: j['url'] as String,
        ordre: j['ordre'] as int?,
      );
}

class Vehicule {
  final int? id;
  final String immatriculation;
  final String? libelle;
  final String marque;
  final String modele;
  final int? marqueId;
  final int? modeleId;
  final int? typeVehiculeId;
  final String? typeVehiculeNom;
  final int? typeActiviteId;
  final String? typeActiviteNom;
  final String? numeroChassis;
  final String? numeroTelephoneVehicule;
  final String? numeroTelephoneBalise;
  final String? identifiantBalise;
  final String? couleur;
  final int? kilometrage;
  final String? statut; // EN_SERVICE, DISPONIBLE, EN_MAINTENANCE, IMMOBILISE, HORS_PARC
  final DateTime? dateAchat;
  final DateTime? dateProchaineMaintenance;
  final DateTime? dateMiseEnCirculation;
  final DateTime? dateEntreeFlotte;
  final int? groupeId;
  final String? groupe;
  final List<VehiculePhoto>? photos;

  const Vehicule({
    this.id,
    required this.immatriculation,
    this.libelle,
    required this.marque,
    required this.modele,
    this.marqueId,
    this.modeleId,
    this.typeVehiculeId,
    this.typeVehiculeNom,
    this.typeActiviteId,
    this.typeActiviteNom,
    this.numeroChassis,
    this.numeroTelephoneVehicule,
    this.numeroTelephoneBalise,
    this.identifiantBalise,
    this.couleur,
    this.kilometrage,
    this.statut,
    this.dateAchat,
    this.dateProchaineMaintenance,
    this.dateMiseEnCirculation,
    this.dateEntreeFlotte,
    this.groupeId,
    this.groupe,
    this.photos,
  });

  Vehicule copyWith({
    int? id,
    String? immatriculation,
    String? libelle,
    String? marque,
    String? modele,
    int? marqueId,
    int? modeleId,
    int? typeVehiculeId,
    int? typeActiviteId,
    String? numeroChassis,
    String? numeroTelephoneVehicule,
    String? numeroTelephoneBalise,
    String? identifiantBalise,
    String? couleur,
    int? kilometrage,
    String? statut,
    DateTime? dateAchat,
    DateTime? dateProchaineMaintenance,
    DateTime? dateMiseEnCirculation,
    DateTime? dateEntreeFlotte,
    int? groupeId,
    String? groupe,
  }) {
    return Vehicule(
      id: id ?? this.id,
      immatriculation: immatriculation ?? this.immatriculation,
      libelle: libelle ?? this.libelle,
      marque: marque ?? this.marque,
      modele: modele ?? this.modele,
      marqueId: marqueId ?? this.marqueId,
      modeleId: modeleId ?? this.modeleId,
      typeVehiculeId: typeVehiculeId ?? this.typeVehiculeId,
      typeActiviteId: typeActiviteId ?? this.typeActiviteId,
      numeroChassis: numeroChassis ?? this.numeroChassis,
      numeroTelephoneVehicule: numeroTelephoneVehicule ?? this.numeroTelephoneVehicule,
      numeroTelephoneBalise: numeroTelephoneBalise ?? this.numeroTelephoneBalise,
      identifiantBalise: identifiantBalise ?? this.identifiantBalise,
      couleur: couleur ?? this.couleur,
      kilometrage: kilometrage ?? this.kilometrage,
      statut: statut ?? this.statut,
      dateAchat: dateAchat ?? this.dateAchat,
      dateProchaineMaintenance:
          dateProchaineMaintenance ?? this.dateProchaineMaintenance,
      dateMiseEnCirculation:
          dateMiseEnCirculation ?? this.dateMiseEnCirculation,
      dateEntreeFlotte: dateEntreeFlotte ?? this.dateEntreeFlotte,
      groupeId: groupeId ?? this.groupeId,
      groupe: groupe ?? this.groupe,
    );
  }

  String get displayName => '$marque $modele';

  bool get isDisponible => statut == 'DISPONIBLE';
  bool get isEnService => statut == 'EN_SERVICE';
  bool get isEnMaintenance => statut == 'EN_MAINTENANCE';
  bool get isImmobilise => statut == 'IMMOBILISE';
  bool get isHorsParc => statut == 'HORS_PARC';
}

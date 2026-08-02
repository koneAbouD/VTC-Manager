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
  final int? baliseId;
  final String? baliseIdentifiant;
  final String? baliseNumeroTelephone;
  final String? couleur;
  final int? kilometrage;
  final String?
      statut; // EN_SERVICE, DISPONIBLE, EN_MAINTENANCE, IMMOBILISE, HORS_PARC
  final DateTime? dateAchat;

  /// Prix d'achat (immobilisation) en XOF. Alimente l'amortissement et la VNC
  /// côté module Finances.
  final double? prixAchat;

  /// Durée d'amortissement linéaire en mois, propre au véhicule. `null` quand il
  /// suit la durée globale des paramètres.
  final int? dureeAmortissementMois;

  /// Durée réellement appliquée : l'override ci-dessus, sinon le paramètre
  /// global, sinon 60. Calculée par le backend, `null` hors fiche détail.
  final int? dureeAmortissementEffective;

  /// Valeur nette comptable du jour, calculée par le backend sur le même plan
  /// d'amortissement que l'actif du bilan — au prorata des jours écoulés depuis
  /// l'entrée en flotte, pas des mois. `null` si le véhicule n'est pas
  /// amortissable (prix d'achat absent) ou hors fiche détail.
  final double? valeurNetteComptable;
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
    this.baliseId,
    this.baliseIdentifiant,
    this.baliseNumeroTelephone,
    this.couleur,
    this.kilometrage,
    this.statut,
    this.dateAchat,
    this.prixAchat,
    this.dureeAmortissementMois,
    this.dureeAmortissementEffective,
    this.valeurNetteComptable,
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
    int? baliseId,
    String? baliseIdentifiant,
    String? baliseNumeroTelephone,
    String? couleur,
    int? kilometrage,
    String? statut,
    DateTime? dateAchat,
    double? prixAchat,
    int? dureeAmortissementMois,
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
      baliseId: baliseId ?? this.baliseId,
      baliseIdentifiant: baliseIdentifiant ?? this.baliseIdentifiant,
      baliseNumeroTelephone:
          baliseNumeroTelephone ?? this.baliseNumeroTelephone,
      couleur: couleur ?? this.couleur,
      kilometrage: kilometrage ?? this.kilometrage,
      statut: statut ?? this.statut,
      dateAchat: dateAchat ?? this.dateAchat,
      prixAchat: prixAchat ?? this.prixAchat,
      dureeAmortissementMois:
          dureeAmortissementMois ?? this.dureeAmortissementMois,
      // Calculées par le backend : jamais recopiées depuis l'appelant, mais
      // conservées pour qu'une copie ne vide pas la VNC déjà affichée.
      dureeAmortissementEffective: dureeAmortissementEffective,
      valeurNetteComptable: valeurNetteComptable,
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

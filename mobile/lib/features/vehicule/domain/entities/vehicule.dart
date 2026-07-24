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

  /// Durée d'amortissement linéaire en mois (60 par défaut côté backend).
  final int? dureeAmortissementMois;
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

  /// Point de départ de l'amortissement : date d'achat, à défaut entrée flotte
  /// puis mise en circulation (même règle que le backend).
  DateTime? get _departAmortissement =>
      dateAchat ?? dateEntreeFlotte ?? dateMiseEnCirculation;

  /// Durée d'amortissement effective : override du véhicule, à défaut la durée
  /// globale fournie, à défaut 60 mois. Aligné sur le COALESCE du backend.
  int dureeAmortissementEffective(int? dureeGlobale) =>
      dureeAmortissementMois ?? dureeGlobale ?? 60;

  /// Valeur nette comptable estimée = prix × (1 − mois écoulés / durée), bornée
  /// à 0. Amortissement linéaire, aligné sur le calcul du bilan côté backend.
  /// [dureeGlobale] = paramètre global appliqué si le véhicule n'a pas d'override.
  /// `null` si le prix d'achat ou le point de départ est inconnu (affichage
  /// indicatif ; la source comptable reste le bilan du module Finances).
  double? valeurNetteComptable({int? dureeGlobale}) {
    final prix = prixAchat;
    final depart = _departAmortissement;
    final duree = dureeAmortissementEffective(dureeGlobale);
    if (prix == null || depart == null || duree <= 0) return null;
    final now = DateTime.now();
    final moisEcoules =
        (now.year - depart.year) * 12 + (now.month - depart.month);
    if (moisEcoules <= 0) return prix;
    final vnc = prix * (1 - moisEcoules / duree);
    return vnc < 0 ? 0 : vnc;
  }

  bool get isDisponible => statut == 'DISPONIBLE';
  bool get isEnService => statut == 'EN_SERVICE';
  bool get isEnMaintenance => statut == 'EN_MAINTENANCE';
  bool get isImmobilise => statut == 'IMMOBILISE';
  bool get isHorsParc => statut == 'HORS_PARC';
}

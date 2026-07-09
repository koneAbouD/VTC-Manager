import '../../domain/entities/contravention.dart';

class ContraventionModel extends Contravention {
  const ContraventionModel({
    super.id,
    required super.dateInfraction,
    super.typeInfraction,
    super.lieu,
    super.description,
    required super.montant,
    super.cotisation,
    super.montantPaye,
    super.statut,
    super.datePaiement,
    super.chauffeurId,
    super.chauffeurNom,
    super.vehiculeId,
    super.vehiculeNom,
    super.numeroContravention,
    super.heureInfraction,
    super.vitesseRelevee,
    super.codeInfraction,
    super.documentSourcePath,
    super.statutRattachement,
  });

  /// Extrait un libellé qu'une valeur soit une chaîne ou un objet {nom/libelle}.
  static String _libelle(dynamic value) {
    if (value is String) return value;
    if (value is Map) {
      return (value['nom'] ?? value['libelle'] ?? '').toString();
    }
    return '';
  }

  factory ContraventionModel.fromJson(Map<String, dynamic> json) {
    final chauffeurJson = json['chauffeur'] as Map<String, dynamic>?;
    final vehiculeJson = json['vehicule'] as Map<String, dynamic>?;

    final prenom = chauffeurJson?['prenom'] as String? ?? '';
    final nom = chauffeurJson?['nom'] as String? ?? '';
    final chauffeurNom = '$prenom $nom'.trim();

    // marque/modele peuvent être des objets {id, nom} (réponse véhicule) ou,
    // par tolérance, de simples chaînes.
    final marque = _libelle(vehiculeJson?['marque']);
    final modele = _libelle(vehiculeJson?['modele']);
    final immat = vehiculeJson?['immatriculation'] as String? ?? '';
    final vehiculeNom = immat.isNotEmpty ? immat : '$marque $modele'.trim();

    return ContraventionModel(
      id: json['id'] as int?,
      dateInfraction: DateTime.parse(json['dateInfraction'] as String),
      typeInfraction: json['typeInfraction'] as String?,
      lieu: json['lieu'] as String?,
      description: json['description'] as String?,
      montant: (json['montant'] as num).toDouble(),
      cotisation: json['cotisation'] != null
          ? (json['cotisation'] as num).toDouble()
          : null,
      montantPaye: json['montantPaye'] != null
          ? (json['montantPaye'] as num).toDouble()
          : null,
      statut: json['statut'] as String?,
      datePaiement: json['datePaiement'] != null
          ? DateTime.parse(json['datePaiement'] as String)
          : null,
      chauffeurId: chauffeurJson?['id'] as int?,
      chauffeurNom: chauffeurNom.isEmpty ? null : chauffeurNom,
      vehiculeId: vehiculeJson?['id'] as int?,
      vehiculeNom: vehiculeNom.isEmpty ? null : vehiculeNom,
      numeroContravention: json['numeroContravention'] as String?,
      heureInfraction: json['heureInfraction'] as String?,
      vitesseRelevee: json['vitesseRelevee'] as int?,
      codeInfraction: json['codeInfraction'] as String?,
      documentSourcePath: json['documentSourcePath'] as String?,
      statutRattachement: json['statutRattachement'] as String?,
    );
  }

  factory ContraventionModel.fromEntity(Contravention c) =>
      ContraventionModel(
        id: c.id,
        dateInfraction: c.dateInfraction,
        typeInfraction: c.typeInfraction,
        lieu: c.lieu,
        description: c.description,
        montant: c.montant,
        cotisation: c.cotisation,
        montantPaye: c.montantPaye,
        statut: c.statut,
        datePaiement: c.datePaiement,
        chauffeurId: c.chauffeurId,
        chauffeurNom: c.chauffeurNom,
        vehiculeId: c.vehiculeId,
        vehiculeNom: c.vehiculeNom,
        numeroContravention: c.numeroContravention,
        heureInfraction: c.heureInfraction,
        vitesseRelevee: c.vitesseRelevee,
        codeInfraction: c.codeInfraction,
        documentSourcePath: c.documentSourcePath,
        statutRattachement: c.statutRattachement,
      );

  Map<String, dynamic> toJson() => {
        'dateInfraction': dateInfraction.toIso8601String().substring(0, 10),
        if (typeInfraction != null) 'typeInfraction': typeInfraction,
        if (lieu != null) 'lieu': lieu,
        if (description != null) 'description': description,
        'montant': montant,
        if (cotisation != null) 'cotisation': cotisation,
        if (montantPaye != null) 'montantPaye': montantPaye,
        if (statut != null) 'statut': statut,
        if (datePaiement != null)
          'datePaiement': datePaiement!.toIso8601String().substring(0, 10),
        if (chauffeurId != null) 'chauffeurId': chauffeurId,
        if (vehiculeId != null) 'vehiculeId': vehiculeId,
        // Champs contravention d'État (saisie manuelle).
        if (numeroContravention != null)
          'numeroContravention': numeroContravention,
        if (heureInfraction != null) 'heureInfraction': heureInfraction,
        if (vitesseRelevee != null) 'vitesseRelevee': vitesseRelevee,
        if (codeInfraction != null) 'codeInfraction': codeInfraction,
      };

  /// Charge utile pour un item de confirmation d'import (`POST /contraventions/confirmer`).
  Map<String, dynamic> toImportItemJson() => {
        if (numeroContravention != null)
          'numeroContravention': numeroContravention,
        if (vehiculeId != null) 'vehiculeId': vehiculeId,
        if (chauffeurId != null) 'chauffeurId': chauffeurId,
        if (codeInfraction != null) 'codeInfraction': codeInfraction,
        if (typeInfraction != null) 'typeInfraction': typeInfraction,
        if (lieu != null) 'lieu': lieu,
        'dateInfraction': dateInfraction.toIso8601String().substring(0, 10),
        if (heureInfraction != null) 'heureInfraction': heureInfraction,
        if (vitesseRelevee != null) 'vitesseRelevee': vitesseRelevee,
        'montant': montant,
        if (documentSourcePath != null)
          'documentSourcePath': documentSourcePath,
      };
}

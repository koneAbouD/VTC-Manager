/// Nature du fournisseur, telle que définie côté backend.
enum TypeFournisseur {
  garage,
  pieces,
  carburant,
  assurance,
  administration,
  bailleur,
  autre;

  static TypeFournisseur fromJson(String? v) => switch (v) {
        'GARAGE' => garage,
        'PIECES' => pieces,
        'CARBURANT' => carburant,
        'ASSURANCE' => assurance,
        'ADMINISTRATION' => administration,
        'BAILLEUR' => bailleur,
        _ => autre,
      };

  String get code => switch (this) {
        garage => 'GARAGE',
        pieces => 'PIECES',
        carburant => 'CARBURANT',
        assurance => 'ASSURANCE',
        administration => 'ADMINISTRATION',
        bailleur => 'BAILLEUR',
        autre => 'AUTRE',
      };

  String get label => switch (this) {
        garage => 'Garage',
        pieces => 'Pièces',
        carburant => 'Carburant',
        assurance => 'Assurance',
        administration => 'Administration',
        bailleur => 'Bailleur',
        autre => 'Autre',
      };
}

/// Tiers auprès de qui l'entreprise achète, éventuellement à crédit.
class Fournisseur {
  final int? id;
  final String nom;
  final TypeFournisseur type;
  final String? telephone;
  final String? email;
  final String? adresse;
  final String? numeroCompteContribuable;
  final String? commentaire;
  final bool actif;

  const Fournisseur({
    this.id,
    required this.nom,
    required this.type,
    this.telephone,
    this.email,
    this.adresse,
    this.numeroCompteContribuable,
    this.commentaire,
    this.actif = true,
  });

  factory Fournisseur.fromJson(Map<String, dynamic> j) => Fournisseur(
        id: (j['id'] as num?)?.toInt(),
        nom: j['nom'] as String? ?? '',
        type: TypeFournisseur.fromJson(j['type'] as String?),
        telephone: j['telephone'] as String?,
        email: j['email'] as String?,
        adresse: j['adresse'] as String?,
        numeroCompteContribuable: j['numeroCompteContribuable'] as String?,
        commentaire: j['commentaire'] as String?,
        actif: j['actif'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'nom': nom,
        'type': type.code,
        if (telephone != null) 'telephone': telephone,
        if (email != null) 'email': email,
        if (adresse != null) 'adresse': adresse,
        if (numeroCompteContribuable != null)
          'numeroCompteContribuable': numeroCompteContribuable,
        if (commentaire != null) 'commentaire': commentaire,
      };
}

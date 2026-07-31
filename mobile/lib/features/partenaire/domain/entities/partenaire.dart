/// Tiers avec qui l'entreprise traite : prestataire, fournisseur,
/// administration, bailleur, assureur…
class Partenaire {
  final int? id;
  final String nom;

  /// Type issu du référentiel des types de partenaire.
  final int typeId;
  final String typeNom;

  final String? telephone;
  final String? email;
  final String? adresse;
  final String? numeroCompteContribuable;
  final String? commentaire;
  final bool actif;

  const Partenaire({
    this.id,
    required this.nom,
    required this.typeId,
    this.typeNom = '',
    this.telephone,
    this.email,
    this.adresse,
    this.numeroCompteContribuable,
    this.commentaire,
    this.actif = true,
  });

  factory Partenaire.fromJson(Map<String, dynamic> j) => Partenaire(
        id: (j['id'] as num?)?.toInt(),
        nom: j['nom'] as String? ?? '',
        typeId: (j['typeId'] as num?)?.toInt() ?? 0,
        typeNom: j['typeNom'] as String? ?? '',
        telephone: j['telephone'] as String?,
        email: j['email'] as String?,
        adresse: j['adresse'] as String?,
        numeroCompteContribuable: j['numeroCompteContribuable'] as String?,
        commentaire: j['commentaire'] as String?,
        actif: j['actif'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'nom': nom,
        'typeId': typeId,
        if (telephone != null) 'telephone': telephone,
        if (email != null) 'email': email,
        if (adresse != null) 'adresse': adresse,
        if (numeroCompteContribuable != null)
          'numeroCompteContribuable': numeroCompteContribuable,
        if (commentaire != null) 'commentaire': commentaire,
      };
}

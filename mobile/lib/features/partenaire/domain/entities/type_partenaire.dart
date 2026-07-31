/// Nature d'un partenaire (prestataire, fournisseur, administration…).
///
/// C'était un enum figé côté application ; c'est désormais une donnée de
/// référence servie par le backend, modifiable depuis le paramétrage.
class TypePartenaire {
  final int id;
  final String nom;
  final String? description;
  final bool actif;

  const TypePartenaire({
    required this.id,
    required this.nom,
    this.description,
    this.actif = true,
  });

  factory TypePartenaire.fromJson(Map<String, dynamic> j) => TypePartenaire(
        id: (j['id'] as num).toInt(),
        nom: j['nom'] as String? ?? '',
        description: j['description'] as String?,
        actif: j['actif'] as bool? ?? true,
      );

  @override
  bool operator ==(Object other) => other is TypePartenaire && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

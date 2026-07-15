/// Chauffeur sélectionnable comme remplaçant.
class Remplacant {
  final int id;
  final String nomComplet;
  final String? telephone;

  const Remplacant({
    required this.id,
    required this.nomComplet,
    this.telephone,
  });
}

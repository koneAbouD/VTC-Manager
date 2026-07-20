/// Totaux de la carte solde de l'accueil pour une période, calculés côté
/// backend via `GET /operations-financieres/solde` (opérations annulées
/// exclues). Remplace le calcul qui était fait sur la liste locale des
/// opérations.
class SoldePeriode {
  final double revenus;
  final double depenses;
  final double solde;

  const SoldePeriode({
    required this.revenus,
    required this.depenses,
    required this.solde,
  });

  static const zero = SoldePeriode(revenus: 0, depenses: 0, solde: 0);

  factory SoldePeriode.fromJson(Map<String, dynamic> json) => SoldePeriode(
        revenus: (json['revenus'] as num? ?? 0).toDouble(),
        depenses: (json['depenses'] as num? ?? 0).toDouble(),
        solde: (json['solde'] as num? ?? 0).toDouble(),
      );
}

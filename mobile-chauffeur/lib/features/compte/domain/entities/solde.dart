/// Solde de compte courant d'un tiers (chauffeur ou véhicule).
class CompteCourant {
  final String? libelle;
  final double? fondsCotisation;
  final double? totalCreances;
  final double? net;

  const CompteCourant({
    this.libelle,
    this.fondsCotisation,
    this.totalCreances,
    this.net,
  });

  bool get estCrediteur => (net ?? 0) > 0;
}

/// Soldes chauffeur + véhicule renvoyés par `/me/solde`.
class Solde {
  final CompteCourant? chauffeur;
  final CompteCourant? vehicule;

  const Solde({this.chauffeur, this.vehicule});
}

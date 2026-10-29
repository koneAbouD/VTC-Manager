/// Cumul des maintenances d'un type sur la sélection affichée.
class TotalMaintenanceParType {
  final int categorieTypeId;
  final String code;
  final String libelle;

  /// Interventions de ce type, tous statuts confondus.
  final int nombre;

  /// Coût des seules interventions terminées.
  final double coutRealise;

  const TotalMaintenanceParType({
    required this.categorieTypeId,
    required this.code,
    required this.libelle,
    required this.nombre,
    required this.coutRealise,
  });
}

/// Compteurs de la page Maintenances, calculés par le serveur sur toute la
/// sélection : la liste paginée n'en a chargé que les premières pages.
class SyntheseMaintenances {
  /// Types ayant au moins une intervention, du plus fréquent au moins
  /// fréquent. Ignore les types cochés : toutes les tuiles restent visibles.
  final List<TotalMaintenanceParType> parType;

  /// Nombre par statut (`PLANIFIEE`, `TERMINEE`…), tous statuts présents.
  /// Suit les types cochés, ignore le statut choisi.
  final Map<String, int> parStatut;

  /// Planifiées dont la date prévue est passée, sur la même base que
  /// [parStatut].
  final int enRetard;

  const SyntheseMaintenances({
    required this.parType,
    required this.parStatut,
    required this.enRetard,
  });

  int get total => parStatut.values.fold(0, (s, n) => s + n);

  int nombre(String statut) => parStatut[statut] ?? 0;

  factory SyntheseMaintenances.fromJson(Map<String, dynamic> json) {
    final types = (json['parType'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        // Une catégorie sans identifiant ne pourrait pas servir de filtre.
        .where((t) => t['categorieTypeId'] != null)
        .map((t) => TotalMaintenanceParType(
              categorieTypeId: (t['categorieTypeId'] as num).toInt(),
              code: (t['code'] ?? '').toString(),
              libelle: (t['libelle'] ?? t['code'] ?? '').toString(),
              nombre: (t['nombre'] as num?)?.toInt() ?? 0,
              coutRealise: (t['coutRealise'] as num?)?.toDouble() ?? 0,
            ))
        .toList();
    final statuts = <String, int>{
      for (final s in (json['parStatut'] as List? ?? const [])
          .whereType<Map<String, dynamic>>())
        (s['statut'] ?? '').toString(): (s['nombre'] as num?)?.toInt() ?? 0,
    };
    return SyntheseMaintenances(
      parType: types,
      parStatut: statuts,
      enRetard: (json['enRetard'] as num?)?.toInt() ?? 0,
    );
  }
}

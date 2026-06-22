/// Genre du chauffeur — miroir de [com.tmk.vtcmanager.application.domain.chauffeur.Genre].
enum Genre {
  homme('HOMME', 'Homme'),
  femme('FEMME', 'Femme');

  final String backend;
  final String label;
  const Genre(this.backend, this.label);

  static Genre? fromJson(dynamic value) {
    if (value == null) return null;
    final s = value.toString();
    for (final g in Genre.values) {
      if (g.backend == s) return g;
    }
    return null;
  }

  String toJson() => backend;
}

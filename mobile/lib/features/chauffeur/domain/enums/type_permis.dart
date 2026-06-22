/// Catégorie de permis de conduire — miroir de [TypePermis].
enum TypePermis {
  a('A'),
  b('B'),
  c('C'),
  d('D'),
  e('E');

  final String backend;
  const TypePermis(this.backend);

  /// Le libellé d'affichage est identique au code backend (A, B, …).
  String get label => backend;

  static TypePermis? fromJson(dynamic value) {
    if (value == null) return null;
    final s = value.toString();
    for (final t in TypePermis.values) {
      if (t.backend == s) return t;
    }
    return null;
  }

  static Set<TypePermis> setFromJson(dynamic value) {
    if (value is! Iterable) return <TypePermis>{};
    return value
        .map(TypePermis.fromJson)
        .whereType<TypePermis>()
        .toSet();
  }

  String toJson() => backend;
}

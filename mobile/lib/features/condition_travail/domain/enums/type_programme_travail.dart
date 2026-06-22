enum TypeProgrammeTravail {
  horaire('HORAIRE', 'Horaire'),
  journalier('JOURNALIER', 'Journalier'),
  hebdomadaire('HEBDOMADAIRE', 'Hebdomadaire');

  final String backend;
  final String label;

  const TypeProgrammeTravail(this.backend, this.label);

  static TypeProgrammeTravail? fromJson(dynamic value) {
    if (value == null) return null;
    final s = value.toString();
    for (final type in TypeProgrammeTravail.values) {
      if (type.backend == s) return type;
    }
    return null;
  }

  String toJson() => backend;
}

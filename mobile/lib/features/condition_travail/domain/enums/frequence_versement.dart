enum FrequenceVersement {
  journalier('JOURNALIER', 'Journalier'),
  hebdomadaire('HEBDOMADAIRE', 'Hebdomadaire'),
  mensuel('MENSUEL', 'Mensuel');

  final String backend;
  final String label;

  const FrequenceVersement(this.backend, this.label);

  static FrequenceVersement? fromJson(dynamic value) {
    if (value == null) return null;
    final raw = value.toString();
    for (final item in values) {
      if (item.backend == raw) return item;
    }
    return null;
  }

  String toJson() => backend;
}

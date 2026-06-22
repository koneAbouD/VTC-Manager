enum ModeAlternance {
  manuelle('MANUELLE', 'Configuration manuelle'),
  automatique('AUTOMATIQUE', 'Alternance automatique');

  final String backend;
  final String label;

  const ModeAlternance(this.backend, this.label);

  static ModeAlternance? fromJson(dynamic value) {
    if (value == null) return null;
    final s = value.toString();
    for (final mode in ModeAlternance.values) {
      if (mode.backend == s) return mode;
    }
    return null;
  }

  String toJson() => backend;
}

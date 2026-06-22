/// Type de chauffeur — miroir de [TypeChauffeur].
enum TypeChauffeur {
  principal('PRINCIPAL', 'Principal'),
  interimaire('INTERIMAIRE', 'Interimaire');

  final String backend;
  final String label;
  const TypeChauffeur(this.backend, this.label);

  static TypeChauffeur? fromJson(dynamic value) {
    if (value == null) return null;
    final s = value.toString();
    for (final t in TypeChauffeur.values) {
      if (t.backend == s) return t;
    }
    return null;
  }

  String toJson() => backend;
}

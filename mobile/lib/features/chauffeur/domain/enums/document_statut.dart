/// Statut d'un document — miroir de [DocumentStatut].
enum DocumentStatut {
  enAttente('EN_ATTENTE', 'En attente'),
  valide('VALIDE', 'Validé'),
  expire('EXPIRE', 'Expiré'),
  rejete('REJETE', 'Rejeté'),
  archive('ARCHIVE', 'Archivé');

  final String backend;
  final String label;
  const DocumentStatut(this.backend, this.label);

  static DocumentStatut? fromJson(dynamic value) {
    if (value == null) return null;
    final s = value.toString();
    for (final d in DocumentStatut.values) {
      if (d.backend == s) return d;
    }
    return null;
  }

  String toJson() => backend;
}

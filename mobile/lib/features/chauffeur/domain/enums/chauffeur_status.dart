/// Statut d'un chauffeur — miroir de [ChauffeurStatus].
enum ChauffeurStatus {
  actif('ACTIF', 'Actif'),
  enService('EN_SERVICE', 'En service'),
  inactif('INACTIF', 'Inactif'),
  enConge('EN_CONGE', 'En congé'),
  suspendu('SUSPENDU', 'Suspendu');

  final String backend;
  final String label;
  const ChauffeurStatus(this.backend, this.label);

  static ChauffeurStatus? fromJson(dynamic value) {
    if (value == null) return null;
    final s = value.toString();
    for (final st in ChauffeurStatus.values) {
      if (st.backend == s) return st;
    }
    return null;
  }

  String toJson() => backend;
}

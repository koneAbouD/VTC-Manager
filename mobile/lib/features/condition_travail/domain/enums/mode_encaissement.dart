enum ModeEncaissement {
  especes('ESPECES', 'En espèces'),
  mobileMoney('MOBILE_MONEY', 'Mobile Money'),
  lesDeux('LES_DEUX', 'Les deux');

  final String backend;
  final String label;

  const ModeEncaissement(this.backend, this.label);

  static ModeEncaissement? fromJson(dynamic value) {
    if (value == null) return null;
    final raw = value.toString();
    for (final item in values) {
      if (item.backend == raw) return item;
    }
    return null;
  }

  String toJson() => backend;
}

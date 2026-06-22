enum TypeRecetteConfiguration {
  montantFixe('MONTANT_FIXE', 'Montant fixe'),
  montantReel('MONTANT_REEL', 'Montant reel');

  final String backend;
  final String label;

  const TypeRecetteConfiguration(this.backend, this.label);

  static TypeRecetteConfiguration? fromJson(dynamic value) {
    if (value == null) return null;
    final raw = value.toString();
    for (final item in values) {
      if (item.backend == raw) return item;
    }
    return null;
  }

  String toJson() => backend;
}

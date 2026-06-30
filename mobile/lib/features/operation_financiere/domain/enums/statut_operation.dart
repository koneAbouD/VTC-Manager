enum StatutOperation { ENCAISSE, PAYE, ANNULEE }

extension StatutOperationExt on StatutOperation {
  String get libelle => switch (this) {
        StatutOperation.ENCAISSE => 'Encaissée',
        StatutOperation.PAYE     => 'Payée',
        StatutOperation.ANNULEE  => 'Annulée',
      };

  /// État terminal validé (encaissée ou payée).
  bool get estTerminee =>
      this == StatutOperation.ENCAISSE || this == StatutOperation.PAYE;

  static StatutOperation fromString(String v) {
    // Compat données legacy : les anciens statuts génériques deviennent ENCAISSE.
    if (v == 'VALIDEE' || v == 'BROUILLON') return StatutOperation.ENCAISSE;
    return StatutOperation.values.byName(v);
  }
}

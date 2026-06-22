enum StatutOperation { BROUILLON, VALIDEE, ANNULEE }

extension StatutOperationExt on StatutOperation {
  String get libelle => switch (this) {
        StatutOperation.BROUILLON => 'Brouillon',
        StatutOperation.VALIDEE   => 'Validée',
        StatutOperation.ANNULEE   => 'Annulée',
      };
  static StatutOperation fromString(String v) => StatutOperation.values.byName(v);
}

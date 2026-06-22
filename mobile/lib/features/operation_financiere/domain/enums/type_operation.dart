enum TypeOperation { REVENU, DEPENSE }

extension TypeOperationExt on TypeOperation {
  String get libelle => this == TypeOperation.REVENU ? 'Revenu' : 'Dépense';
  static TypeOperation fromString(String v) => TypeOperation.values.byName(v);
}

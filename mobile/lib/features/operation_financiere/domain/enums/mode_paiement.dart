enum ModePaiement { ESPECES, MOBILE_MONEY }

extension ModePaiementExt on ModePaiement {
  String get libelle => switch (this) {
        ModePaiement.ESPECES      => 'Espèces',
        ModePaiement.MOBILE_MONEY => 'Mobile Money',
      };
  static ModePaiement fromString(String v) => ModePaiement.values.byName(v);
}

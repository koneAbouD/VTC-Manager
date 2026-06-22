enum ModePaiementCotisation {
  especes,
  mobileMoney;

  static ModePaiementCotisation fromJson(String v) => switch (v) {
        'ESPECES'      => especes,
        'MOBILE_MONEY' => mobileMoney,
        _              => especes,
      };

  String toJson() => switch (this) {
        especes      => 'ESPECES',
        mobileMoney  => 'MOBILE_MONEY',
      };

  String get label => switch (this) {
        especes     => 'Espèces',
        mobileMoney => 'Mobile Money',
      };
}

class EncaissementCotisation {
  final int? id;
  final int ligneCotisationId;
  final int? operationFinanciereId;
  final double montant;
  final ModePaiementCotisation modeEncaissement;
  final DateTime dateEncaissement;
  final String? reference;
  final String? commentaire;

  const EncaissementCotisation({
    this.id,
    required this.ligneCotisationId,
    this.operationFinanciereId,
    required this.montant,
    required this.modeEncaissement,
    required this.dateEncaissement,
    this.reference,
    this.commentaire,
  });
}

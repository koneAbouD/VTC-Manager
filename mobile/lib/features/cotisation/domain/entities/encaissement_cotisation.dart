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

  /// Renseignés si le versement a été extourné : il reste dans la liste — il a
  /// eu lieu — mais ne compte plus dans ce que la ligne a encaissé.
  final DateTime? annuleLe;
  final String? motifAnnulation;

  bool get estAnnule => annuleLe != null;

  const EncaissementCotisation({
    this.id,
    required this.ligneCotisationId,
    this.operationFinanciereId,
    required this.montant,
    required this.modeEncaissement,
    required this.dateEncaissement,
    this.reference,
    this.commentaire,
    this.annuleLe,
    this.motifAnnulation,
  });
}

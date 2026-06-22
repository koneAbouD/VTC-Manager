enum ModeEncaissement {
  especes,
  mobileMoney;

  static ModeEncaissement fromJson(String value) => switch (value) {
        'ESPECES' => especes,
        'MOBILE_MONEY' => mobileMoney,
        _ => especes,
      };

  String toJson() => switch (this) {
        especes => 'ESPECES',
        mobileMoney => 'MOBILE_MONEY',
      };

  String get label => switch (this) {
        especes => 'Espèces',
        mobileMoney => 'Mobile Money',
      };
}

class Encaissement {
  final int? id;
  final int ligneRecetteId;
  final int? operationFinanciereId;
  final double montant;
  final ModeEncaissement modeEncaissement;
  final DateTime dateEncaissement;
  final String? reference;
  final String? commentaire;

  const Encaissement({
    this.id,
    required this.ligneRecetteId,
    this.operationFinanciereId,
    required this.montant,
    required this.modeEncaissement,
    required this.dateEncaissement,
    this.reference,
    this.commentaire,
  });
}

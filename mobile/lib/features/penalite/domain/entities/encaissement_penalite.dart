class EncaissementPenalite {
  final int? id;
  final int lignePenaliteId;
  final int? operationFinanciereId;
  final double montant;
  final String modeEncaissement;
  final DateTime dateEncaissement;
  final String? reference;
  final String? commentaire;

  const EncaissementPenalite({
    this.id,
    required this.lignePenaliteId,
    this.operationFinanciereId,
    required this.montant,
    required this.modeEncaissement,
    required this.dateEncaissement,
    this.reference,
    this.commentaire,
  });
}

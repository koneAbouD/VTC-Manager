class EncaissementPenalite {
  final int? id;
  final int lignePenaliteId;
  final int? operationFinanciereId;
  final double montant;
  final String modeEncaissement;
  final DateTime dateEncaissement;
  final String? reference;
  final String? commentaire;

  /// Renseignés si le versement a été extourné : il reste dans la liste — il a
  /// eu lieu — mais ne compte plus dans ce que la pénalité a encaissé.
  final DateTime? annuleLe;
  final String? motifAnnulation;

  bool get estAnnule => annuleLe != null;

  const EncaissementPenalite({
    this.id,
    required this.lignePenaliteId,
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

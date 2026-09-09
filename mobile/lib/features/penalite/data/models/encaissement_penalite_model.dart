import '../../domain/entities/encaissement_penalite.dart';

class EncaissementPenaliteModel extends EncaissementPenalite {
  const EncaissementPenaliteModel({
    super.id,
    required super.lignePenaliteId,
    super.operationFinanciereId,
    required super.montant,
    required super.modeEncaissement,
    required super.dateEncaissement,
    super.reference,
    super.commentaire,
    super.annuleLe,
    super.motifAnnulation,
    super.dateModifiable,
    super.motifDateNonModifiable,
  });

  factory EncaissementPenaliteModel.fromJson(Map<String, dynamic> j) =>
      EncaissementPenaliteModel(
        id: j['id'] as int?,
        lignePenaliteId: j['lignePenaliteId'] as int? ?? 0,
        operationFinanciereId: j['operationFinanciereId'] as int?,
        montant: (j['montant'] as num?)?.toDouble() ?? 0,
        modeEncaissement: j['modeEncaissement'] as String? ?? 'ESPECES',
        dateEncaissement: j['dateEncaissement'] != null
            ? DateTime.parse(j['dateEncaissement'] as String)
            : DateTime.now(),
        reference: j['reference'] as String?,
        commentaire: j['commentaire'] as String?,
        annuleLe: j['annuleLe'] != null
            ? DateTime.tryParse(j['annuleLe'] as String)
            : null,
        motifAnnulation: j['motifAnnulation'] as String?,
        // Un serveur d'avant la correction de date ne renvoie rien : la fiche
        // n'offre alors pas le geste, plutôt que de le proposer en vain.
        dateModifiable: j['dateModifiable'] as bool? ?? false,
        motifDateNonModifiable: j['motifDateNonModifiable'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'montant': montant,
        'modeEncaissement': modeEncaissement,
        'dateEncaissement': dateEncaissement.toIso8601String().substring(0, 10),
        if (reference != null) 'reference': reference,
        if (commentaire != null) 'commentaire': commentaire,
      };
}

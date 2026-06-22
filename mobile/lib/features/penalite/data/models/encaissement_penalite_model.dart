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
      );

  Map<String, dynamic> toJson() => {
        'montant': montant,
        'modeEncaissement': modeEncaissement,
        'dateEncaissement': dateEncaissement.toIso8601String().substring(0, 10),
        if (reference != null) 'reference': reference,
        if (commentaire != null) 'commentaire': commentaire,
      };
}

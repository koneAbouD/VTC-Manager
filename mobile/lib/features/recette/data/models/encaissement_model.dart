import '../../domain/entities/encaissement.dart';

class EncaissementModel extends Encaissement {
  const EncaissementModel({
    super.id,
    required super.ligneRecetteId,
    super.operationFinanciereId,
    required super.montant,
    required super.modeEncaissement,
    required super.dateEncaissement,
    super.reference,
    super.commentaire,
  });

  factory EncaissementModel.fromJson(Map<String, dynamic> json) {
    return EncaissementModel(
      id: json['id'] as int?,
      ligneRecetteId: json['ligneRecetteId'] as int,
      operationFinanciereId: json['operationFinanciereId'] as int?,
      montant: (json['montant'] as num).toDouble(),
      modeEncaissement: ModeEncaissement.fromJson(json['modeEncaissement'] as String),
      dateEncaissement: DateTime.parse(json['dateEncaissement'] as String),
      reference: json['reference'] as String?,
      commentaire: json['commentaire'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'montant': montant,
        'modeEncaissement': modeEncaissement.toJson(),
        'dateEncaissement': dateEncaissement.toIso8601String().substring(0, 10),
        if (reference != null) 'reference': reference,
        if (commentaire != null) 'commentaire': commentaire,
      };
}

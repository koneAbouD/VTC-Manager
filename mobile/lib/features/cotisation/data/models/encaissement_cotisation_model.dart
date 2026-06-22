import '../../domain/entities/encaissement_cotisation.dart';

class EncaissementCotisationModel extends EncaissementCotisation {
  const EncaissementCotisationModel({
    super.id,
    required super.ligneCotisationId,
    super.operationFinanciereId,
    required super.montant,
    required super.modeEncaissement,
    required super.dateEncaissement,
    super.reference,
    super.commentaire,
  });

  factory EncaissementCotisationModel.fromJson(Map<String, dynamic> json) =>
      EncaissementCotisationModel(
        id: json['id'] as int?,
        ligneCotisationId: json['ligneCotisationId'] as int,
        operationFinanciereId: json['operationFinanciereId'] as int?,
        montant: (json['montant'] as num).toDouble(),
        modeEncaissement: ModePaiementCotisation.fromJson(json['modeEncaissement'] as String),
        dateEncaissement: DateTime.parse(json['dateEncaissement'] as String),
        reference: json['reference'] as String?,
        commentaire: json['commentaire'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'montant': montant,
        'modeEncaissement': modeEncaissement.toJson(),
        'dateEncaissement': dateEncaissement.toIso8601String().substring(0, 10),
        if (reference != null) 'reference': reference,
        if (commentaire != null) 'commentaire': commentaire,
      };
}

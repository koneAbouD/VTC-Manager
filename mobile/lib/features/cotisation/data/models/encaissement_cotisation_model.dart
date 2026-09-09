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
    super.annuleLe,
    super.motifAnnulation,
    super.dateModifiable,
    super.motifDateNonModifiable,
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
        annuleLe: json['annuleLe'] != null
            ? DateTime.tryParse(json['annuleLe'] as String)
            : null,
        motifAnnulation: json['motifAnnulation'] as String?,
        // Un serveur d'avant la correction de date ne renvoie rien : la fiche
        // n'offre alors pas le geste, plutôt que de le proposer en vain.
        dateModifiable: json['dateModifiable'] as bool? ?? false,
        motifDateNonModifiable: json['motifDateNonModifiable'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'montant': montant,
        'modeEncaissement': modeEncaissement.toJson(),
        'dateEncaissement': dateEncaissement.toIso8601String().substring(0, 10),
        if (reference != null) 'reference': reference,
        if (commentaire != null) 'commentaire': commentaire,
      };
}

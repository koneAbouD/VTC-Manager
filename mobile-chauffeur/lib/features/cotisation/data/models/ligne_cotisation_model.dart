import '../../domain/entities/ligne_cotisation.dart';

class LigneCotisationModel extends LigneCotisation {
  const LigneCotisationModel({
    required super.id,
    super.date,
    super.nom,
    super.montantDu,
    super.montantRestant,
    super.statut,
  });

  factory LigneCotisationModel.fromJson(Map<String, dynamic> j) =>
      LigneCotisationModel(
        id: j['id'] as int,
        date: j['dateCotisation'] as String?,
        nom: j['nomCotisation'] as String?,
        montantDu: (j['montantDu'] as num?)?.toDouble(),
        montantRestant: (j['montantRestant'] as num?)?.toDouble(),
        statut: j['statut'] as String?,
      );
}

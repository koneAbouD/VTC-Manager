import '../../domain/entities/ligne_recette.dart';

class LigneRecetteModel extends LigneRecette {
  const LigneRecetteModel({
    required super.id,
    super.date,
    super.montantAttendu,
    super.montantRestant,
    super.statut,
  });

  factory LigneRecetteModel.fromJson(Map<String, dynamic> j) => LigneRecetteModel(
        id: j['id'] as int,
        date: j['dateRecette'] as String?,
        montantAttendu: (j['montantAttendu'] as num?)?.toDouble(),
        montantRestant: (j['montantRestant'] as num?)?.toDouble(),
        statut: j['statut'] as String?,
      );
}

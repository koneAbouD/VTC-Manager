import '../../domain/entities/ligne_penalite.dart';

class LignePenaliteModel extends LignePenalite {
  const LignePenaliteModel({
    required super.id,
    super.date,
    super.type,
    super.typeSanction,
    super.montant,
    super.montantRestant,
    super.statut,
  });

  factory LignePenaliteModel.fromJson(Map<String, dynamic> j) => LignePenaliteModel(
        id: j['id'] as int,
        date: (j['dateFaute'] ?? j['dateGeneration']) as String?,
        type: j['typePenalite'] as String?,
        typeSanction: j['typeSanction'] as String?,
        montant: (j['montant'] as num?)?.toDouble(),
        montantRestant: (j['montantRestant'] as num?)?.toDouble(),
        statut: j['statut'] as String?,
      );
}

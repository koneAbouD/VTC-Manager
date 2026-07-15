import '../../domain/entities/contravention.dart';

class ContraventionModel extends Contravention {
  const ContraventionModel({
    required super.id,
    super.date,
    super.type,
    super.lieu,
    super.montant,
    super.montantPaye,
    super.statut,
  });

  factory ContraventionModel.fromJson(Map<String, dynamic> j) => ContraventionModel(
        id: j['id'] as int,
        date: j['dateInfraction'] as String?,
        type: j['typeInfraction'] as String?,
        lieu: j['lieu'] as String?,
        montant: (j['montant'] as num?)?.toDouble(),
        montantPaye: (j['montantPaye'] as num?)?.toDouble(),
        statut: j['statut'] as String?,
      );
}

import '../../domain/entities/paiement.dart';

class PaiementModel extends Paiement {
  const PaiementModel({
    required super.reference,
    super.typeCible,
    super.cibleId,
    super.montant,
    super.canal,
    super.statut,
    super.paymentUrl,
    super.regle,
    super.messageErreur,
  });

  factory PaiementModel.fromJson(Map<String, dynamic> j) => PaiementModel(
        reference: j['reference'] as String,
        typeCible: j['typeCible'] as String?,
        cibleId: j['cibleId'] as int?,
        montant: (j['montant'] as num?)?.toDouble(),
        canal: j['canal'] as String?,
        statut: j['statut'] as String?,
        paymentUrl: j['paymentUrl'] as String?,
        regle: (j['regle'] as bool?) ?? false,
        messageErreur: j['messageErreur'] as String?,
      );
}

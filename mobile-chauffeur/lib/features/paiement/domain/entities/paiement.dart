/// Paiement Mobile Money d'une recette ou cotisation.
class Paiement {
  final String reference;
  final String? typeCible;
  final int? cibleId;
  final double? montant;
  final String? canal;
  final String? statut; // INITIE, EN_ATTENTE, REUSSI, ECHOUE, EXPIRE
  final String? paymentUrl;
  final bool regle;
  final String? messageErreur;

  const Paiement({
    required this.reference,
    this.typeCible,
    this.cibleId,
    this.montant,
    this.canal,
    this.statut,
    this.paymentUrl,
    this.regle = false,
    this.messageErreur,
  });

  bool get estReussi => (statut ?? '').toUpperCase() == 'REUSSI';

  bool get estEnAttente {
    final s = (statut ?? '').toUpperCase();
    return s == 'INITIE' || s == 'EN_ATTENTE';
  }

  bool get estEchoue {
    final s = (statut ?? '').toUpperCase();
    return s == 'ECHOUE' || s == 'EXPIRE';
  }
}

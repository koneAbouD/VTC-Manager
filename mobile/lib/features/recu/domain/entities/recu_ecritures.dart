import '../../../../core/utils/recu_paiement.dart';

/// Le reçu d'écritures d'un même chauffeur, tel que le serveur l'établit pour
/// le PDF : le message WhatsApp se rédige ainsi sur les mêmes chiffres.
class RecuEcritures {
  final RecuPaiement recu;

  /// Numéro de la fiche chauffeur, nul s'il n'est pas renseigné.
  final String? telephone;

  const RecuEcritures({required this.recu, this.telephone});
}

/// Après un encaissement — une ligne, un versement, un lot —, proposer au
/// guichetier d'envoyer le reçu au chauffeur, sans quitter l'écran.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/envoi_recus_sheet.dart';
import 'envoi_recu.dart';
import 'providers/recu_provider.dart';

/// Ouvre la feuille d'envoi du reçu des [operationIds] qu'un encaissement
/// vient de passer au journal.
///
/// Le reçu est établi par le serveur, sur les écritures elles-mêmes : ce que
/// le message annonce est donc ce que le PDF atteste, reste dû compris. S'il
/// ne peut pas l'être, un bandeau le dit et l'encaissement, lui, reste acquis.
/// « Plus tard » referme la feuille : le reçu se renvoie à tout moment depuis
/// le détail de l'écriture.
Future<void> proposerEnvoiRecu(
  BuildContext context,
  WidgetRef ref,
  List<int> operationIds,
) async {
  final ids = operationIds.toSet().toList();
  if (ids.isEmpty) return;

  final messenger = ScaffoldMessenger.maybeOf(context);
  final lu = await ref.read(recuRepositoryProvider).getRecu(ids);
  if (!context.mounted) return;

  final recu = lu.fold((echec) {
    messenger?.showSnackBar(SnackBar(
      content: Text('Encaissement enregistré, mais le reçu n\'a pas pu être '
          'préparé : ${echec.message}'),
      backgroundColor: AppColors.error,
    ));
    return null;
  }, (r) => r);
  if (recu == null) return;

  final n = recu.recu.lignes.length;
  await showEnvoiRecusSheet(
    context,
    destinataires: [
      DestinataireRecu(
        nom: recu.recu.chauffeur ?? 'Chauffeur',
        telephone: recu.telephone,
        resume: '$n créance${n > 1 ? 's' : ''} · '
            '${CurrencyFormatter.format(recu.recu.total)}',
        recu: recu.recu,
        operationIds: ids,
      ),
    ],
    envoyer: (destinataire) => envoyerRecuDestinataire(ref, destinataire),
  );
}

/// Envoie le reçu PDF d'un destinataire de la feuille : `null` si WhatsApp
/// s'est ouvert, sinon le motif à afficher sous sa ligne.
Future<String?> envoyerRecuDestinataire(
    WidgetRef ref, DestinataireRecu destinataire) async {
  final issue = await envoyerRecuPdf(
    recus: ref.read(recuRepositoryProvider),
    operationIds: destinataire.operationIds,
    recu: destinataire.recu,
    telephone: destinataire.telephone,
  );
  return switch (issue) {
    PdfIndisponible(:final motif) => motif,
    PdfEnregistre(conversationOuverte: false) =>
      "Reçu enregistré, mais WhatsApp n'a pas pu être ouvert sur cet appareil.",
    _ => null,
  };
}

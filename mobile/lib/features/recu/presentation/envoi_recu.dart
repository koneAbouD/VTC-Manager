/// Envoi du reçu au chauffeur, par WhatsApp : le PDF rendu par le serveur et le
/// message qui l'accompagne. Le chemin jusqu'à la conversation est celui de
/// tout document envoyé à un chauffeur — voir [envoyerPdfParWhatsApp].
library;

import '../../../core/utils/bytes_downloader.dart';
import '../../../core/utils/envoi_pdf_whatsapp.dart';
import '../../../core/utils/recu_paiement.dart';
import '../../../core/utils/whatsapp.dart';
import '../domain/repositories/recu_repository.dart';

export '../../../core/utils/envoi_pdf_whatsapp.dart'
    show IssueEnvoiPdf, PdfPartage, PdfEnregistre, PdfIndisponible;

/// Prépare le reçu PDF des [operationIds] et le met entre les mains du
/// guichetier, dans WhatsApp.
///
/// Rien n'est enregistré côté serveur — ni date d'envoi, ni accusé : c'est le
/// guichetier qui appuie sur envoyer, et rien ne revient le confirmer.
Future<IssueEnvoiPdf> envoyerRecuPdf({
  required RecuRepository recus,
  required List<int> operationIds,
  required RecuPaiement recu,
  String? telephone,
  OuvrirConversation ouvrirConversation = ouvrirWhatsApp,
  EnregistrerFichier enregistrerFichier = downloadBytesFile,
}) async {
  if (operationIds.isEmpty) {
    return const PdfIndisponible('aucune écriture à quittancer.');
  }

  final pdf = await recus.getRecuPdf(operationIds);
  return pdf.fold<Future<IssueEnvoiPdf>>(
    (echec) async => PdfIndisponible(echec.message),
    (octets) => envoyerPdfParWhatsApp(
      octets: octets,
      nomFichier: nomFichierRecu(recu),
      message: composerRecu(recu, avecPieceJointe: true),
      document: 'Reçu',
      telephone: telephone,
      ouvrirConversation: ouvrirConversation,
      enregistrerFichier: enregistrerFichier,
    ),
  );
}

/// Nom du fichier : « recu_1234-AB-01_11-09-2026.pdf » — l'immatriculation du
/// véhicule, puis le jour du paiement. Sans véhicule unique — un lot qui en
/// couvre plusieurs — le nom du chauffeur tient lieu de plaque.
String nomFichierRecu(RecuPaiement recu) => nomFichierPdf('recu',
    vehicule: recu.vehicule, personne: recu.chauffeur, jour: recu.date);

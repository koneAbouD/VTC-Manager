/// Envoi du reçu au chauffeur : le PDF rendu par le serveur, joint au message,
/// dans sa conversation WhatsApp.
///
/// Trois issues possibles, que l'écran traduit : le reçu est parti ; il est
/// enregistré sur l'appareil faute de partage (iOS, web) et le message s'ouvre
/// seul ; ou le serveur ne l'a pas produit, et rien n'est parti.
library;

import 'package:intl/intl.dart';

import '../../../core/utils/bytes_downloader.dart';
import '../../../core/utils/partage_fichier.dart';
import '../../../core/utils/recu_paiement.dart';
import '../../../core/utils/whatsapp.dart';
import '../domain/repositories/recu_repository.dart';

sealed class IssueEnvoiRecu {
  const IssueEnvoiRecu();
}

/// Le PDF est parti vers WhatsApp — ou vers la feuille de partage, faute de
/// WhatsApp sur l'appareil.
class RecuPartage extends IssueEnvoiRecu {
  final bool dansWhatsApp;
  const RecuPartage({required this.dansWhatsApp});
}

/// Plateforme sans partage de fichier : le PDF est enregistré sur l'appareil,
/// WhatsApp s'ouvre sur le message, et le guichetier y joint le fichier.
class RecuEnregistre extends IssueEnvoiRecu {
  final String? emplacement;
  const RecuEnregistre(this.emplacement);
}

/// Le PDF n'a pas été produit : rien n'est parti. [motif] est rédigé pour
/// l'écran — par le serveur quand c'est lui qui refuse.
class RecuPdfIndisponible extends IssueEnvoiRecu {
  final String motif;
  const RecuPdfIndisponible(this.motif);
}

/// Prépare le reçu PDF des [operationIds] et le fait partir, message joint.
///
/// Rien n'est enregistré ici — ni date d'envoi, ni accusé : c'est le guichetier
/// qui appuie sur envoyer dans WhatsApp, et rien ne revient le confirmer.
Future<IssueEnvoiRecu> envoyerRecuPdf({
  required RecuRepository recus,
  required List<int> operationIds,
  required RecuPaiement recu,
  String? telephone,
}) async {
  if (operationIds.isEmpty) {
    return const RecuPdfIndisponible('aucune écriture à quittancer.');
  }

  final pdf = await recus.getRecuPdf(operationIds);
  return pdf.fold<Future<IssueEnvoiRecu>>(
    (echec) async => RecuPdfIndisponible(echec.message),
    (octets) async {
      final nom = nomFichierRecu(recu);
      final message = composerRecu(recu, avecPieceJointe: true);
      final issue = await partagerFichier(
        octets: octets,
        nomFichier: nom,
        telephone: telephone,
        texte: message,
      );
      switch (issue) {
        case IssuePartage.whatsapp:
          return const RecuPartage(dansWhatsApp: true);
        case IssuePartage.feuilleDePartage:
          return const RecuPartage(dansWhatsApp: false);
        case IssuePartage.indisponible:
          final emplacement =
              await downloadBytesFile(octets, nom, 'application/pdf');
          try {
            await ouvrirWhatsApp(telephone: telephone, message: message);
          } catch (_) {
            // Le PDF est enregistré : c'est l'essentiel, le message peut attendre.
          }
          return RecuEnregistre(emplacement);
      }
    },
  );
}

/// Nom du fichier tel que le chauffeur le voit dans WhatsApp :
/// « recu_aya_traore_2026-09-11.pdf ». Sans accent ni espace : certains
/// téléphones les affichent mal dans une pièce jointe.
String nomFichierRecu(RecuPaiement recu) {
  final qui = _slug(recu.chauffeur) ?? 'chauffeur';
  return 'recu_${qui}_${DateFormat('yyyy-MM-dd').format(recu.date)}.pdf';
}

const _sansAccent = {
  'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ç': 'c', 'é': 'e', 'è': 'e',
  'ê': 'e', 'ë': 'e', 'î': 'i', 'ï': 'i', 'í': 'i', 'ô': 'o', 'ö': 'o',
  'ó': 'o', 'ù': 'u', 'û': 'u', 'ü': 'u', 'ú': 'u', 'ÿ': 'y', 'ñ': 'n',
};

String? _slug(String? texte) {
  if (texte == null || texte.trim().isEmpty) return null;
  final minuscules = texte.trim().toLowerCase().split('').map((c) => _sansAccent[c] ?? c).join();
  final slug = minuscules
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  return slug.isEmpty ? null : slug;
}

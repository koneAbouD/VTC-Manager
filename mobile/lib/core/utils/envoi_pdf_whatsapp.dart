/// Envoi d'un document PDF à un chauffeur, par WhatsApp : le reçu d'un
/// versement, le décompte d'un arrêté.
///
/// Avec un numéro, l'écran va droit à la conversation du chauffeur : le PDF est
/// enregistré sur l'appareil, WhatsApp s'ouvre sur la conversation, message
/// prêt, et le guichetier y joint le fichier. C'est le seul chemin qui mène
/// sûrement au bon chauffeur — le lien wa.me — mais il ne transporte que du
/// texte : WhatsApp ignore tout destinataire joint à un partage de fichier.
///
/// Sans numéro, le contact est à choisir de toute façon : le PDF part alors
/// déjà joint, et WhatsApp demande le destinataire.
///
/// Rien n'est enregistré côté serveur — ni date d'envoi, ni accusé : c'est le
/// guichetier qui appuie sur envoyer, et rien ne revient le confirmer.
library;

import 'dart:typed_data';

import 'package:intl/intl.dart';

import 'bytes_downloader.dart';
import 'partage_fichier.dart';
import 'phone_formatter.dart';
import 'whatsapp.dart';

sealed class IssueEnvoiPdf {
  const IssueEnvoiPdf();
}

/// Le PDF est parti joint vers WhatsApp — ou vers la feuille de partage, faute
/// de WhatsApp — et le contact est à choisir.
class PdfPartage extends IssueEnvoiPdf {
  final bool dansWhatsApp;
  const PdfPartage({required this.dansWhatsApp});
}

/// Le PDF est enregistré sur l'appareil, et WhatsApp ouvert sur la conversation
/// avec le message : le guichetier y joint le fichier.
class PdfEnregistre extends IssueEnvoiPdf {
  final String? emplacement;

  /// Faux si WhatsApp n'a pas pu s'ouvrir : le fichier, lui, est bien enregistré.
  final bool conversationOuverte;

  const PdfEnregistre(this.emplacement, {this.conversationOuverte = true});
}

/// Le PDF n'a pas été produit : rien n'est parti. [motif] est rédigé pour
/// l'écran — par le serveur quand c'est lui qui refuse.
class PdfIndisponible extends IssueEnvoiPdf {
  final String motif;
  const PdfIndisponible(this.motif);
}

typedef OuvrirConversation = Future<bool> Function(
    {String? telephone, required String message});

typedef EnregistrerFichier = Future<String?> Function(
    Uint8List octets, String nomFichier, String mime);

/// Met le PDF [octets] entre les mains du guichetier, dans WhatsApp, avec
/// [message].
///
/// [document] nomme le fichier dans l'annonce qui dit où le trouver :
/// « Reçu », « Décompte ».
Future<IssueEnvoiPdf> envoyerPdfParWhatsApp({
  required Uint8List octets,
  required String nomFichier,
  required String message,
  required String document,
  String? telephone,
  OuvrirConversation ouvrirConversation = ouvrirWhatsApp,
  EnregistrerFichier enregistrerFichier = downloadBytesFile,
}) async {
  // Sans numéro, le contact est à choisir de toute façon : autant que le
  // document arrive déjà joint.
  if (PhoneFormatter.international(telephone) == null) {
    switch (await partagerFichier(octets: octets, nomFichier: nomFichier, texte: message)) {
      case IssuePartage.whatsapp:
        return const PdfPartage(dansWhatsApp: true);
      case IssuePartage.feuilleDePartage:
        return const PdfPartage(dansWhatsApp: false);
      case IssuePartage.indisponible:
        break; // iOS, web : même chemin qu'avec un numéro.
    }
  }

  final emplacement = await enregistrerFichier(octets, nomFichier, 'application/pdf');
  // Annoncé avant de passer la main : le toast reste lisible par-dessus
  // WhatsApp, et dit où trouver le fichier à joindre.
  await annoncerSurAppareil(_dansTelechargements(emplacement)
      ? '$document enregistré dans Téléchargements : joignez-le avec 📎 dans la conversation.'
      : '$document PDF enregistré : joignez-le avec 📎 dans la conversation.');

  var ouverte = false;
  try {
    ouverte = await ouvrirConversation(telephone: telephone, message: message);
  } catch (_) {
    // Le PDF est enregistré : l'écran dira que WhatsApp ne s'est pas ouvert.
  }
  return PdfEnregistre(emplacement, conversationOuverte: ouverte);
}

bool _dansTelechargements(String? emplacement) =>
    emplacement != null &&
    (emplacement.startsWith('Téléchargements') || emplacement.contains('/Download'));

/// Nom du fichier : « recu_1234-AB-01_11-09-2026.pdf » — le [prefixe],
/// l'immatriculation du [vehicule], puis le [jour] au format français.
///
/// Les « / » de la date deviennent des « - » : un nom de fichier ne peut pas en
/// contenir. Sans véhicule unique, le nom de la [personne] tient lieu de
/// plaque ; sans l'un ni l'autre, la date seule.
String nomFichierPdf(String prefixe,
    {String? vehicule, String? personne, required DateTime jour}) {
  final date = DateFormat('dd-MM-yyyy').format(jour);
  final qui = _immatriculation(vehicule) ?? _slug(personne);
  return qui == null ? '${prefixe}_$date.pdf' : '${prefixe}_${qui}_$date.pdf';
}

/// « 1234 AB 01 » → « 1234-AB-01 » : les caractères de la plaque, reliés par
/// des tirets, pour que « _ » reste le séparateur des parties du nom.
String? _immatriculation(String? plaque) {
  if (plaque == null || plaque.trim().isEmpty) return null;
  final propre = plaque
      .trim()
      .toUpperCase()
      .replaceAll(RegExp(r'[^A-Z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return propre.isEmpty ? null : propre;
}

const _sansAccent = {
  'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ç': 'c', 'é': 'e', 'è': 'e',
  'ê': 'e', 'ë': 'e', 'î': 'i', 'ï': 'i', 'í': 'i', 'ô': 'o', 'ö': 'o',
  'ó': 'o', 'ù': 'u', 'û': 'u', 'ü': 'u', 'ú': 'u', 'ÿ': 'y', 'ñ': 'n',
};

String? _slug(String? texte) {
  if (texte == null || texte.trim().isEmpty) return null;
  final minuscules =
      texte.trim().toLowerCase().split('').map((c) => _sansAccent[c] ?? c).join();
  final slug = minuscules
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  return slug.isEmpty ? null : slug;
}

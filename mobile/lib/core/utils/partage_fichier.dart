/// Partage d'un fichier — le reçu PDF — dans la conversation WhatsApp d'un
/// destinataire, message joint.
///
/// Le lien `wa.me` ne transporte que du texte : une pièce jointe passe par le
/// système. Sur Android, l'application adresse le fichier directement à
/// WhatsApp, ouvert sur la conversation du numéro ; sans WhatsApp, la feuille
/// de partage prend le relais. Ailleurs (iOS, web), le partage n'est pas
/// disponible et l'appelant se replie.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'phone_formatter.dart';

const MethodChannel _canal = MethodChannel('vtc/partage');

enum IssuePartage {
  /// WhatsApp s'est ouvert, fichier et message prêts à partir.
  whatsapp,

  /// WhatsApp absent : la feuille de partage du système a pris le relais.
  feuilleDePartage,

  /// Plateforme sans partage de fichier, ou partage refusé par le système.
  indisponible,
}

Future<IssuePartage> partagerFichier({
  required Uint8List octets,
  required String nomFichier,
  String mime = 'application/pdf',
  String? telephone,
  String? texte,
}) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return IssuePartage.indisponible;
  }
  try {
    final issue = await _canal.invokeMethod<String>('partagerFichier', {
      'nomFichier': nomFichier,
      'octets': octets,
      'mime': mime,
      'telephone': PhoneFormatter.international(telephone),
      'texte': texte,
    });
    return issue == 'WHATSAPP'
        ? IssuePartage.whatsapp
        : IssuePartage.feuilleDePartage;
  } on PlatformException {
    return IssuePartage.indisponible;
  } on MissingPluginException {
    return IssuePartage.indisponible;
  }
}

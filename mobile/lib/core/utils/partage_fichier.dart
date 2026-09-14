/// Pont vers le partage natif du reçu PDF : l'envoi à WhatsApp, fichier joint,
/// et l'annonce système qui reste lisible quand l'application passe la main.
///
/// Android seulement. Ailleurs (iOS, web), rien ne part et l'appelant se replie.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const MethodChannel _canal = MethodChannel('vtc/partage');

enum IssuePartage {
  /// WhatsApp s'est ouvert, fichier et message prêts ; le contact reste à choisir.
  whatsapp,

  /// WhatsApp absent : la feuille de partage du système a pris le relais.
  feuilleDePartage,

  /// Plateforme sans partage de fichier, ou partage refusé par le système.
  indisponible,
}

bool get _android => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// Adresse le fichier à WhatsApp, message en légende. WhatsApp demande le
/// destinataire : il ignore tout destinataire joint à un partage de fichier.
Future<IssuePartage> partagerFichier({
  required Uint8List octets,
  required String nomFichier,
  String mime = 'application/pdf',
  String? texte,
}) async {
  if (!_android) return IssuePartage.indisponible;
  try {
    final issue = await _canal.invokeMethod<String>('partagerFichier', {
      'nomFichier': nomFichier,
      'octets': octets,
      'mime': mime,
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

/// Message bref affiché par le système (toast Android). Il reste lisible
/// par-dessus l'application qui s'ouvre juste après — là où une SnackBar serait
/// restée dans la nôtre, invisible. Sans effet ailleurs.
Future<void> annoncerSurAppareil(String texte) async {
  if (!_android) return;
  try {
    await _canal.invokeMethod<void>('annoncer', {'texte': texte});
  } on PlatformException {
    // Une annonce manquée n'empêche pas l'envoi.
  } on MissingPluginException {
    // Idem : ancienne installation sans le canal.
  }
}

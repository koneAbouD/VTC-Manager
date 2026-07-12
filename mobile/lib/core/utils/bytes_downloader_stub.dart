import 'dart:io';
import 'dart:typed_data';

import 'android_downloads.dart';

/// Sauvegarde un fichier binaire (PDF…). Sur Android, dans le dossier public
/// « Téléchargements » ; sinon (iOS/desktop, ou repli) dans le dossier temporaire.
/// Retourne le chemin/emplacement du fichier créé.
Future<String?> downloadBytesFile(
    Uint8List bytes, String filename, String mime) async {
  final download = await saveToAndroidDownloads(bytes, filename, mime);
  if (download != null) return download;

  final file = File('${Directory.systemTemp.path}/$filename');
  await file.writeAsBytes(bytes);
  return file.path;
}

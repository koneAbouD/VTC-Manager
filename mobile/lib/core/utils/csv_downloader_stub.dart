import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'android_downloads.dart';

/// Sauvegarde le CSV. Sur Android, dans le dossier public « Téléchargements » ;
/// sinon (iOS/desktop, ou repli) dans le dossier temporaire du système.
/// Retourne le chemin/emplacement du fichier créé.
Future<String?> downloadCsvFile(String content, String filename) async {
  final bytes = Uint8List.fromList(utf8.encode('﻿$content')); // BOM UTF-8 pour Excel

  final download = await saveToAndroidDownloads(bytes, filename, 'text/csv');
  if (download != null) return download;

  final file = File('${Directory.systemTemp.path}/$filename');
  await file.writeAsBytes(bytes);
  return file.path;
}

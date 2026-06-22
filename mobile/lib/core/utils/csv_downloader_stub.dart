import 'dart:convert';
import 'dart:io';

/// Sauvegarde le CSV dans le dossier temporaire du système.
/// Retourne le chemin absolu du fichier créé.
Future<String?> downloadCsvFile(String content, String filename) async {
  final bytes = utf8.encode('﻿$content'); // BOM UTF-8 pour Excel
  final file = File('${Directory.systemTemp.path}/$filename');
  await file.writeAsBytes(bytes);
  return file.path;
}

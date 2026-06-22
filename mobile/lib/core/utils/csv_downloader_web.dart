import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Déclenche un téléchargement CSV dans le navigateur.
/// Retourne null (le navigateur gère le fichier).
Future<String?> downloadCsvFile(String content, String filename) async {
  final bytes = utf8.encode('﻿$content'); // BOM UTF-8 pour Excel
  final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
  return null;
}

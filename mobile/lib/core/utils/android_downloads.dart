import 'dart:io';

import 'package:flutter/services.dart';

const MethodChannel _channel = MethodChannel('vtc/downloads');

/// Sur Android, enregistre le fichier dans le dossier public « Téléchargements »
/// du téléphone (via MediaStore). Retourne l'emplacement affichable, ou null si
/// la plateforme n'est pas Android ou si l'enregistrement échoue (repli appelant).
Future<String?> saveToAndroidDownloads(
    Uint8List bytes, String filename, String mime) async {
  if (!Platform.isAndroid) return null;
  try {
    return await _channel.invokeMethod<String>('saveToDownloads', {
      'filename': filename,
      'bytes': bytes,
      'mime': mime,
    });
  } catch (_) {
    return null;
  }
}

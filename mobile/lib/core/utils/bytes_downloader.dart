/// Hub d'import conditionnel pour le téléchargement de fichiers binaires (PDF…).
/// - Web  : dart:html → téléchargement direct dans le navigateur
/// - Mobile/Desktop : dart:io → sauvegarde dans le dossier temporaire
library;

export 'bytes_downloader_stub.dart'
    if (dart.library.html) 'bytes_downloader_web.dart';

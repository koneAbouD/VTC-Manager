/// Hub d'import conditionnel.
/// - Web  : dart:html → téléchargement direct dans le navigateur
/// - Mobile/Desktop : dart:io → sauvegarde dans le dossier temporaire
export 'csv_downloader_stub.dart'
    if (dart.library.html) 'csv_downloader_web.dart';

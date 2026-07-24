import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/app_colors.dart';

/// Document sélectionné (fichier ou photo) prêt à être téléversé.
class PickedDocument {
  const PickedDocument({required this.bytes, required this.fileName});

  final Uint8List bytes;
  final String fileName;
}

/// Source de document proposée dans la bottom-sheet.
enum _DocumentSource { fichier, camera }

/// Bottom-sheet réutilisable pour importer un document : soit choisir un fichier
/// dans les dossiers (PDF ou image), soit prendre une photo avec la caméra.
///
/// Usage :
/// ```dart
/// final doc = await pickDocumentFromSource(context);
/// if (doc != null) { /* doc.bytes, doc.fileName */ }
/// ```
class DocumentSourceBottomSheet extends StatelessWidget {
  const DocumentSourceBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE3E6EE),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 4),
          _SourceTile(
            icon: Icons.folder_open_outlined,
            title: 'Choisir un fichier',
            subtitle: 'PDF ou image depuis vos dossiers',
            onTap: () => Navigator.pop(context, _DocumentSource.fichier),
          ),
          _SourceTile(
            icon: Icons.photo_camera_outlined,
            title: 'Prendre une photo',
            subtitle: 'Photographier le document avec la caméra',
            onTap: () => Navigator.pop(context, _DocumentSource.camera),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 42,
        height: 42,
        decoration: const BoxDecoration(
          color: AppColors.primaryTint,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: AppColors.primaryDark, size: 22),
      ),
      title: Text(title,
          style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.dark)),
      subtitle: Text(subtitle,
          style: const TextStyle(fontSize: 12, color: AppColors.hint)),
      onTap: onTap,
    );
  }
}

/// Affiche la bottom-sheet de sélection de source puis retourne le document
/// choisi (fichier ou photo). Retourne `null` si l'utilisateur annule.
Future<PickedDocument?> pickDocumentFromSource(BuildContext context) async {
  final source = await showModalBottomSheet<_DocumentSource>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const DocumentSourceBottomSheet(),
  );
  if (source == null) return null;

  switch (source) {
    case _DocumentSource.fichier:
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return null;
      final file = result.files.first;
      if (file.bytes == null) return null;
      // Une image importée peut être recadrée ; un PDF non.
      if (file.path != null && _estImage(file.name)) {
        final rogne = await _rognerImage(file.path!, file.name);
        if (rogne != null) return rogne;
      }
      return PickedDocument(bytes: file.bytes!, fileName: file.name);

    case _DocumentSource.camera:
      final photo = await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: 1600,
        imageQuality: 80,
      );
      if (photo == null) return null;
      // Après la prise, on propose de rogner/recadrer la photo.
      final rogne = await _rognerImage(photo.path, photo.name);
      if (rogne != null) return rogne;
      // Recadrage annulé (ou indisponible) : on conserve la photo d'origine.
      final bytes = await photo.readAsBytes();
      return PickedDocument(bytes: bytes, fileName: photo.name);
  }
}

bool _estImage(String filename) {
  final ext = filename.toLowerCase().split('.').last;
  return ext == 'jpg' || ext == 'jpeg' || ext == 'png';
}

/// Ouvre l'écran de rognage/recadrage sur l'image du chemin [sourcePath].
/// Retourne le document recadré, ou `null` si l'utilisateur annule ou si le
/// rognage n'est pas disponible (web) — l'appelant garde alors l'original.
Future<PickedDocument?> _rognerImage(String sourcePath, String fileName) async {
  // Le rognage natif (uCrop / TOCropViewController) ne cible que mobile ;
  // sur le web, ImageCropper exige une intégration JS distincte.
  if (kIsWeb) return null;

  final estPng = fileName.toLowerCase().endsWith('.png');
  final cropped = await ImageCropper().cropImage(
    sourcePath: sourcePath,
    compressFormat: estPng ? ImageCompressFormat.png : ImageCompressFormat.jpg,
    compressQuality: 90,
    uiSettings: [
      AndroidUiSettings(
        // En-tête (toolbar) de la même couleur que la barre de contrôles du bas
        // « Rogner / Pivoter / Zoom » : fond ebony clay (#20242F) et accent vert
        // sur les contrôles actifs. Les barres système sont gérées par le thème
        // natif Theme.VtcUcrop, qui annule l'edge-to-edge.
        toolbarTitle: 'Recadrer le document',
        toolbarColor: const Color(0xFF20242F),
        toolbarWidgetColor: Colors.white,
        backgroundColor: AppColors.dark,
        activeControlsWidgetColor: AppColors.primary,
        lockAspectRatio: false,
        hideBottomControls: false,
      ),
      IOSUiSettings(
        title: 'Recadrer le document',
        aspectRatioLockEnabled: false,
        resetAspectRatioEnabled: true,
      ),
    ],
  );
  if (cropped == null) return null;
  final bytes = await cropped.readAsBytes();
  return PickedDocument(bytes: bytes, fileName: fileName);
}

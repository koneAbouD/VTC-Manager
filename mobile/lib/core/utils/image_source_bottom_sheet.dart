import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Bottom-sheet réutilisable pour choisir la source d'une image (caméra ou galerie).
///
/// Usage :
/// ```dart
/// final source = await showModalBottomSheet<ImageSource>(
///   context: context,
///   backgroundColor: Colors.white,
///   shape: const RoundedRectangleBorder(
///     borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
///   ),
///   builder: (_) => const ImageSourceBottomSheet(),
/// );
/// ```
class ImageSourceBottomSheet extends StatelessWidget {
  const ImageSourceBottomSheet({super.key});

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
          ListTile(
            leading:
                const Icon(Icons.photo_camera_outlined, color: Colors.black87),
            title: const Text('Caméra',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading:
                const Icon(Icons.photo_library_outlined, color: Colors.black87),
            title: const Text('Gallery',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Affiche la bottom-sheet de sélection de source et retourne le fichier choisi.
/// Retourne `null` si l'utilisateur annule.
Future<XFile?> pickImageFromSource(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const ImageSourceBottomSheet(),
  );
  if (source == null) return null;

  return ImagePicker().pickImage(
    source: source,
    maxWidth: 1600,
    imageQuality: 80,
  );
}

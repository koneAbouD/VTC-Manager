import 'package:flutter/material.dart';

/// Ouvre une image en plein écran, zoomable (pincer / double-tap) et
/// déplaçable. Fond noir, bouton de fermeture. Réutilisable partout où l'on
/// affiche une vignette cliquable.
Future<void> showImageViewer(BuildContext context, String url, {String? titre}) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _ImageViewerPage(url: url, titre: titre),
    ),
  );
}

class _ImageViewerPage extends StatelessWidget {
  final String url;
  final String? titre;

  const _ImageViewerPage({required this.url, this.titre});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: titre != null
            ? Text(titre!,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))
            : null,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 5,
          child: Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (_, child, progress) => progress == null
                ? child
                : const Center(
                    child: CircularProgressIndicator(color: Colors.white)),
            errorBuilder: (_, __, ___) => const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.broken_image_outlined,
                      color: Colors.white54, size: 48),
                  SizedBox(height: 8),
                  Text('Image indisponible',
                      style: TextStyle(color: Colors.white54)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

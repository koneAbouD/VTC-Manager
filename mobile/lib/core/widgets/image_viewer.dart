import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Ouvre une image en aperçu premium : arrière-plan flouté laissant deviner
/// l'écran courant, image centrée dans une carte contrainte aux marges de
/// l'application (elle ne déborde jamais du cadre), zoomable (pincer /
/// double-tap) et déplaçable à l'intérieur de la carte. Réutilisable partout où
/// l'on affiche une vignette cliquable.
Future<void> showImageViewer(BuildContext context, String url, {String? titre}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, __, ___) => _ImageViewerOverlay(url: url, titre: titre),
    transitionBuilder: (_, animation, __, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _ImageViewerOverlay extends StatelessWidget {
  final String url;
  final String? titre;

  const _ImageViewerOverlay({required this.url, this.titre});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Flou de l'arrière-plan (l'écran courant reste visible, adouci).
        Positioned.fill(
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: const ColoredBox(color: Colors.transparent),
            ),
          ),
        ),
        // Image centrée, bornée aux marges de sécurité de l'écran.
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: constraints.maxWidth,
                      maxHeight: constraints.maxHeight,
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 30,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        // Le zoom reste clipé à la carte : rien ne déborde.
                        child: InteractiveViewer(
                          minScale: 1,
                          maxScale: 5,
                          clipBehavior: Clip.hardEdge,
                          child: Image.network(
                            url,
                            fit: BoxFit.contain,
                            loadingBuilder: (_, child, progress) =>
                                progress == null
                                    ? child
                                    : const SizedBox(
                                        width: 120,
                                        height: 120,
                                        child: Center(
                                          child: CircularProgressIndicator(
                                              color: Colors.white),
                                        ),
                                      ),
                            errorBuilder: (_, __, ___) => const SizedBox(
                              width: 200,
                              height: 160,
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.broken_image_outlined,
                                        color: Colors.white70, size: 46),
                                    SizedBox(height: 8),
                                    Text('Image indisponible',
                                        style: TextStyle(color: Colors.white70)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        // Titre éventuel + bouton de fermeture flottant.
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
            child: Row(
              children: [
                if (titre != null && titre!.isNotEmpty)
                  Expanded(
                    child: Text(
                      titre!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        shadows: [
                          Shadow(color: Colors.black54, blurRadius: 8),
                        ],
                      ),
                    ),
                  )
                else
                  const Spacer(),
                _boutonFermer(context),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _boutonFermer(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.16),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => Navigator.of(context).pop(),
        child: const SizedBox(
          width: 40,
          height: 40,
          child: Icon(Icons.close_rounded, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

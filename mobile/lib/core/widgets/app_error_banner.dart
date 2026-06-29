import 'package:flutter/material.dart';

/// Bandeau d'erreur persistant et lisible, à afficher au plus près de l'action
/// qui a échoué (ex. en haut d'un formulaire après un refus serveur).
///
/// Contrairement à un SnackBar transitoire, il reste visible tant que l'erreur
/// n'est pas résolue, ce qui rend le message backend (ex. « Mode de paiement
/// 'ESPECES' non autorisé pour ce véhicule. Mode configuré : MOBILE_MONEY. »)
/// immédiatement compréhensible et actionnable.
class AppErrorBanner extends StatelessWidget {
  final String message;

  /// Optionnel : affiche une croix de fermeture si fourni.
  final VoidCallback? onClose;

  const AppErrorBanner({
    super.key,
    required this.message,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    const red = Color(0xFFC62828);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: red.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: red, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF7F1D1D),
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
          if (onClose != null) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onClose,
              behavior: HitTestBehavior.opaque,
              child: const Icon(Icons.close_rounded, color: red, size: 18),
            ),
          ],
        ],
      ),
    );
  }
}

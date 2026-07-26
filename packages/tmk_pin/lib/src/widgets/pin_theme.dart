import 'package:flutter/material.dart';

/// Jetons visuels du clavier et des cases de saisie.
///
/// Chaque application fournit les siens depuis sa propre charte : le package
/// n'impose aucune couleur, il n'en connaît que les rôles.
class PinTheme {
  /// Bordure de la case active, et accent général.
  final Color accent;

  /// Couleur des chiffres du pavé.
  final Color digit;

  /// Bordure des cases non saisies.
  final Color border;

  /// Remplissage du point d'une case saisie.
  final Color filled;

  /// Bordure et texte en cas de code refusé.
  final Color error;

  const PinTheme({
    required this.accent,
    required this.digit,
    required this.border,
    required this.filled,
    required this.error,
  });

  /// Reprend les couleurs du thème Material ambiant — repli commode.
  factory PinTheme.of(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PinTheme(
      accent: scheme.primary,
      digit: scheme.onSurface,
      border: scheme.outlineVariant,
      filled: scheme.primary,
      error: scheme.error,
    );
  }
}

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'long_press_info_bubble.dart';

/// Pastille de filtre par statut des listes (recettes, cotisations, pénalités,
/// maintenances, contraventions), posée dans une rangée horizontale de hauteur
/// fixe.
///
/// Sélectionnée, elle se **teinte** de la couleur d'accent choisie dans
/// Réglages › Apparence — fond clair, bordure et texte à l'accent — plutôt que
/// de s'en remplir : c'est un contrôle de l'interface, pas un statut, il suit
/// donc le thème. La couleur du statut ([color]) ne colore plus que la bulle
/// d'info de l'appui long, qui parle du montant de ce statut.
class StatutFiltreChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Couleur du statut filtré, reprise par la bulle d'info.
  final Color color;

  /// Montant à afficher dans l'info-bulle à l'appui long (montant du statut).
  final String? infoText;

  /// Écart avec la pastille suivante, quand la rangée ne le porte pas
  /// elle-même (séparateur de liste).
  final EdgeInsetsGeometry margin;

  const StatutFiltreChip({
    super.key,
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
    this.infoText,
    this.margin = const EdgeInsets.only(right: 8),
  });

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.primary;
    final chip = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      margin: margin,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? accent.withValues(alpha: 0.12) : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? accent.withValues(alpha: 0.5) : AppColors.border,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? accent : AppColors.label,
        ),
      ),
    );

    final cible = Semantics(
      button: true,
      selected: selected,
      child: chip,
    );

    if (infoText == null) {
      return GestureDetector(onTap: onTap, child: cible);
    }
    return LongPressInfoBubble(
      onTap: onTap,
      infoText: infoText!,
      color: color,
      child: cible,
    );
  }
}

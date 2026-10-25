import 'package:flutter/material.dart';
import 'package:tmk_pin/tmk_pin.dart';

import '../../../../core/theme/app_colors.dart';

/// Couleurs des écrans de code, tirées de la charte de l'application.
PinTheme get pinTheme => PinTheme(
  accent: AppColors.primary,
  digit: AppColors.dark,
  border: AppColors.border,
  filled: AppColors.primary,
  error: AppColors.error,
  // Fond des cases vides et des touches, fond d'une case saisie.
  fill: AppColors.fieldFill,
  tint: AppColors.primaryTint,
);

/// Logo de l'application : en tête des écrans de code, à l'écran de démarrage
/// et en miniature au pied des réglages.
class PinBrand extends StatelessWidget {
  /// Hauteur du logo (96 en tête d'écran, une trentaine en pied de page).
  final double height;

  const PinBrand({super.key, this.height = 96});

  /// Arrondi des angles, proportionnel à la taille : 10 px pour le logo de 34
  /// px du pied des réglages, la même courbe à toutes les tailles.
  static const _ratioArrondi = 10 / 34;

  @override
  Widget build(BuildContext context) {
    // Le logo est une image à fond blanc, sans transparence : en clair il se
    // fond dans la page, en sombre il devient un rectangle blanc. Ses angles
    // sont donc toujours adoucis, comme ceux des cartes.
    return ClipRRect(
      borderRadius: BorderRadius.circular(height * _ratioArrondi),
      child: Image.asset(
        'assets/images/logo_tmk.png',
        height: height,
        fit: BoxFit.contain,
        // Repli si l'asset manque.
        errorBuilder: (_, __, ___) => Icon(
          Icons.local_taxi_rounded,
          size: height * 0.75,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

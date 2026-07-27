import 'package:flutter/material.dart';
import 'package:tmk_pin/tmk_pin.dart';

import '../../../../core/theme/app_colors.dart';

/// Couleurs des écrans de code, tirées de la charte de l'application.
const pinTheme = PinTheme(
  accent: AppColors.primary,
  digit: AppColors.dark,
  border: AppColors.border,
  filled: AppColors.primary,
  error: AppColors.error,
  // Fond des cases vides et des touches, fond d'une case saisie.
  fill: AppColors.fieldFill,
  tint: AppColors.primaryTint,
);

/// Logo de l'application : en tête des écrans de code, et en miniature au pied
/// des réglages.
class PinBrand extends StatelessWidget {
  /// Hauteur du logo (96 en tête d'écran, une trentaine en pied de page).
  final double height;

  const PinBrand({super.key, this.height = 96});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logo_tmk.png',
      height: height,
      fit: BoxFit.contain,
      // Même repli que l'écran de démarrage si l'asset manque.
      errorBuilder: (_, __, ___) => Icon(
        Icons.local_taxi_rounded,
        size: height * 0.75,
        color: AppColors.primary,
      ),
    );
  }
}

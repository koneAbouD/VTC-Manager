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

/// Marque affichée en tête des écrans de code.
class PinBrand extends StatelessWidget {
  const PinBrand({super.key});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logo_tmk.png',
      height: 96,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => const Text(
        'TMK',
        style: TextStyle(
          fontSize: 44,
          fontWeight: FontWeight.w800,
          color: AppColors.primary,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

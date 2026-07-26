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
);

/// Logo affiché en tête des écrans de code.
class PinBrand extends StatelessWidget {
  const PinBrand({super.key});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logo_tmk.png',
      height: 96,
      fit: BoxFit.contain,
      // Même repli que l'écran de démarrage si l'asset manque.
      errorBuilder: (_, __, ___) => const Icon(
        Icons.local_taxi_rounded,
        size: 72,
        color: AppColors.primary,
      ),
    );
  }
}

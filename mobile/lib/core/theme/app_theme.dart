import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Thème global de l'application, dérivé de [AppColors].
///
/// Centralise les valeurs par défaut (fond des pages, en-tête, boutons,
/// champs) : toute page utilisant les widgets Material standard hérite
/// automatiquement de la charte sans couleur codée en dur.
abstract final class AppTheme {
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
    );

    OutlineInputBorder border(Color c, [double w = 1.2]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c, width: w),
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.scaffold,
      cardColor: AppColors.surface,

      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.header,
        foregroundColor: AppColors.dark,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),

      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primaryTint,
        surfaceTintColor: Colors.transparent,
        elevation: 2,
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.fieldFill,
        labelStyle: const TextStyle(color: AppColors.hint),
        floatingLabelStyle: const TextStyle(
            color: AppColors.primary, fontWeight: FontWeight.w600),
        enabledBorder: border(AppColors.border),
        border: border(AppColors.border),
        focusedBorder: border(AppColors.primary, 1.6),
        errorBorder: border(AppColors.error),
        focusedErrorBorder: border(AppColors.error, 1.6),
      ),
    );
  }
}

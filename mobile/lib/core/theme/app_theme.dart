import 'package:flutter/material.dart';

import 'app_palette.dart';

/// Thème global de l'application, dérivé de la [AppPalette].
///
/// Centralise les valeurs par défaut (fond des pages, en-tête, boutons,
/// champs) : toute page utilisant les widgets Material standard hérite
/// automatiquement de la charte sans couleur codée en dur.
abstract final class AppTheme {
  static ThemeData clair(AppAccent accent) =>
      _construire(AppPalette.de(accent, Brightness.light));

  static ThemeData sombre(AppAccent accent) =>
      _construire(AppPalette.de(accent, Brightness.dark));

  static ThemeData _construire(AppPalette p) {
    final scheme = ColorScheme.fromSeed(
      seedColor: p.primary,
      brightness: p.brightness,
    ).copyWith(
      primary: p.primary,
      onPrimary: Colors.white,
      surface: p.surface,
      onSurface: p.dark,
      error: p.error,
      outline: p.border,
    );

    OutlineInputBorder border(Color c, [double w = 1.2]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c, width: w),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.scaffold,
      cardColor: p.surface,
      canvasColor: p.surface,
      dividerColor: p.border,
      // Texte courant : les Text sans style explicite suivent la charte.
      textTheme: ThemeData(brightness: p.brightness).textTheme.apply(
            bodyColor: p.dark,
            displayColor: p.dark,
          ),

      appBarTheme: AppBarTheme(
        backgroundColor: p.scaffold,
        foregroundColor: p.dark,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.surface,
        indicatorColor: p.primaryTint,
        surfaceTintColor: Colors.transparent,
        elevation: 2,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: p.surface,
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        surfaceTintColor: Colors.transparent,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: p.surface,
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: DividerThemeData(color: p.border),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.fieldFill,
        labelStyle: TextStyle(color: p.hint),
        floatingLabelStyle:
            TextStyle(color: p.primary, fontWeight: FontWeight.w600),
        enabledBorder: border(p.border),
        border: border(p.border),
        focusedBorder: border(p.primary, 1.6),
        errorBorder: border(p.error),
        focusedErrorBorder: border(p.error, 1.6),
      ),
    );
  }
}

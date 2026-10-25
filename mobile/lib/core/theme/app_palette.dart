import 'package:flutter/material.dart';

/// Couleurs d'accent proposées à l'utilisateur (réglage « Apparence »).
///
/// Chaque accent porte deux déclinaisons : une pour le thème clair, une pour le
/// thème sombre. Sur fond sombre, la couleur de marque doit rester assez
/// lumineuse pour se lire en texte ou en icône, sans que le blanc posé dessus
/// (boutons) ne perde son contraste : on reste donc sur des tons moyens.
enum AppAccent {
  vert('Vert', Color(0xFF43A047), Color(0xFF2E7D32), Color(0xFFE8F5E9),
      Color(0xFF43A047), Color(0xFF81C784)),
  bleu('Bleu', Color(0xFF1E88E5), Color(0xFF1565C0), Color(0xFFE3F2FD),
      Color(0xFF1E88E5), Color(0xFF64B5F6)),
  indigo('Indigo', Color(0xFF3949AB), Color(0xFF283593), Color(0xFFE8EAF6),
      Color(0xFF5C6BC0), Color(0xFF9FA8DA)),
  violet('Violet', Color(0xFF8E24AA), Color(0xFF6A1B9A), Color(0xFFF3E5F5),
      Color(0xFFAB47BC), Color(0xFFCE93D8)),
  rose('Rose', Color(0xFFD81B60), Color(0xFFAD1457), Color(0xFFFCE4EC),
      Color(0xFFEC407A), Color(0xFFF48FB1)),
  orange('Orange', Color(0xFFEF6C00), Color(0xFFBF360C), Color(0xFFFFF3E0),
      Color(0xFFEF6C00), Color(0xFFFFB74D)),
  turquoise('Turquoise', Color(0xFF00897B), Color(0xFF00695C),
      Color(0xFFE0F2F1), Color(0xFF1E9E92), Color(0xFF80CBC4)),
  ardoise('Ardoise', Color(0xFF546E7A), Color(0xFF37474F), Color(0xFFECEFF4),
      Color(0xFF78909C), Color(0xFFB0BEC5));

  /// Libellé affiché dans le sélecteur.
  final String libelle;

  /// Thème clair : couleur de marque, sa version soutenue, sa teinte pâle.
  final Color primary;
  final Color primaryDark;
  final Color primaryTint;

  /// Thème sombre : couleur de marque et sa version éclaircie. La teinte pâle
  /// du thème sombre est calculée (voir [AppPalette.de]).
  final Color primaryNuit;
  final Color primaryDarkNuit;

  const AppAccent(
    this.libelle,
    this.primary,
    this.primaryDark,
    this.primaryTint,
    this.primaryNuit,
    this.primaryDarkNuit,
  );

  /// Retrouve un accent par son nom stocké ; l'accent par défaut en cas
  /// d'absence ou de valeur inconnue (ancienne version, donnée altérée).
  static AppAccent depuis(String? nom) => AppAccent.values.firstWhere(
        (a) => a.name == nom,
        orElse: () => AppAccent.vert,
      );
}

/// Jeu complet des jetons de couleur de l'application pour un accent et une
/// luminosité donnés.
///
/// [AppColors] y lit ses valeurs : un seul objet à remplacer pour changer
/// l'apparence de toute l'application.
class AppPalette {
  final Brightness brightness;
  final AppAccent accent;

  final Color primary;
  final Color primaryDark;
  final Color primaryTint;

  final Color scaffold;
  final Color surface;
  final Color headerButton;

  final List<Color> cardBorderGradient;

  final Color dark; // texte principal
  final Color hint;
  final Color label;
  final Color border;
  final Color fieldFill;

  final Color success;
  final Color error;
  final Color warning;
  final Color info;

  /// Sémantique « positif » (encaissé, payé, terminé) : un vert qui ne suit pas
  /// l'accent — un statut reste vert quelle que soit la couleur de marque.
  final Color positive;
  final Color positiveTint;

  /// Fonds pâles des pastilles d'avertissement, d'erreur et d'information.
  final Color warningTint;
  final Color errorTint;
  final Color infoTint;

  const AppPalette._({
    required this.brightness,
    required this.accent,
    required this.primary,
    required this.primaryDark,
    required this.primaryTint,
    required this.scaffold,
    required this.surface,
    required this.headerButton,
    required this.cardBorderGradient,
    required this.dark,
    required this.hint,
    required this.label,
    required this.border,
    required this.fieldFill,
    required this.success,
    required this.error,
    required this.warning,
    required this.info,
    required this.positive,
    required this.positiveTint,
    required this.warningTint,
    required this.errorTint,
    required this.infoTint,
  });

  bool get estSombre => brightness == Brightness.dark;

  /// Palette de l'[accent] pour la [brightness] demandée.
  factory AppPalette.de(AppAccent accent, Brightness brightness) {
    if (brightness == Brightness.light) {
      return AppPalette._(
        brightness: brightness,
        accent: accent,
        primary: accent.primary,
        primaryDark: accent.primaryDark,
        primaryTint: accent.primaryTint,
        scaffold: const Color(0xFFF8F9FB),
        surface: const Color(0xFFFFFFFF),
        headerButton: const Color(0xFFF0F2F8),
        cardBorderGradient: const [
          Color(0xFFBDBDBD),
          Color(0xFFEEEEEE),
          Color(0xFF9E9E9E),
        ],
        dark: const Color(0xFF1A1A2E),
        hint: const Color(0xFF8A94A6),
        label: const Color(0xFF6B7280),
        border: const Color(0xFFE4E9EE),
        // Gris neutre des champs premium : aucune teinte de marque, le champ
        // ne doit pas se lire comme un élément coloré.
        fieldFill: const Color(0xFFF2F3F5),
        success: const Color(0xFF1B5E20),
        error: const Color(0xFFB71C1C),
        warning: const Color(0xFFE65100),
        info: const Color(0xFF1A237E),
        positive: const Color(0xFF2E7D32),
        positiveTint: const Color(0xFFE8F5E9),
        warningTint: const Color(0xFFFFF3E0),
        errorTint: const Color(0xFFFDECEA),
        infoTint: const Color(0xFFEFF4FF),
      );
    }

    const surface = Color(0xFF1C1F26);
    return AppPalette._(
      brightness: brightness,
      accent: accent,
      primary: accent.primaryNuit,
      primaryDark: accent.primaryDarkNuit,
      // Teinte pâle du thème clair → voile d'accent posé sur la surface.
      primaryTint: Color.lerp(surface, accent.primaryNuit, 0.22)!,
      scaffold: const Color(0xFF121418),
      surface: surface,
      headerButton: const Color(0xFF272B34),
      cardBorderGradient: const [
        Color(0xFF454B58),
        Color(0xFF2B2F38),
        Color(0xFF565D6B),
      ],
      dark: const Color(0xFFECEFF4),
      hint: const Color(0xFF8B94A5),
      label: const Color(0xFFA9B1BF),
      border: const Color(0xFF2F343E),
      fieldFill: const Color(0xFF232731),
      // Sémantiques : assez claires pour se lire en texte sur fond sombre, assez
      // franches pour porter du blanc quand elles servent de fond (toasts).
      success: const Color(0xFF43A047),
      error: const Color(0xFFE53935),
      warning: const Color(0xFFF57C00),
      info: const Color(0xFF5C6BC0),
      positive: const Color(0xFF4CAF50),
      positiveTint: Color.lerp(surface, const Color(0xFF4CAF50), 0.18)!,
      warningTint: Color.lerp(surface, const Color(0xFFF57C00), 0.18)!,
      errorTint: Color.lerp(surface, const Color(0xFFE53935), 0.18)!,
      infoTint: Color.lerp(surface, const Color(0xFF5C6BC0), 0.20)!,
    );
  }
}

import 'package:flutter/material.dart';

import 'app_palette.dart';

/// Charte graphique centralisée de l'application.
///
/// **Source unique de vérité** des couleurs : modifier une valeur ici se
/// répercute partout (thème global + composants partagés + pages qui
/// référencent ces jetons).
///
/// Les jetons ne sont plus des constantes : ils suivent la [AppPalette]
/// courante, que l'utilisateur change depuis Réglages › Apparence (couleur
/// d'accent, mode clair / sombre). Conséquence pour l'écriture : un widget qui
/// en lit un ne peut pas être `const`, et une valeur par défaut de paramètre
/// ne peut pas en porter — on la résout dans `build` à la place.
///
/// La palette est remplacée par [appliquer], appelée par le `builder` de
/// l'application avant que l'arbre ne se construise ; l'application est alors
/// reconstruite d'un bloc pour que les widgets déjà affichés la relisent.
abstract final class AppColors {
  static AppPalette _palette = AppPalette.de(AppAccent.vert, Brightness.light);

  /// Palette en vigueur.
  static AppPalette get palette => _palette;

  /// Installe la palette de l'[accent] pour la [brightness] donnée. Renvoie
  /// `true` si elle diffère de la précédente (de quoi décider d'une
  /// reconstruction).
  static bool appliquer(AppAccent accent, Brightness brightness) {
    if (_palette.accent == accent && _palette.brightness == brightness) {
      return false;
    }
    _palette = AppPalette.de(accent, brightness);
    return true;
  }

  /// Thème sombre actif : à consulter pour les rares cas où une couleur n'a pas
  /// d'équivalent dans la charte (ex. une pastille blanche devenue sombre).
  static bool get estSombre => _palette.estSombre;

  // ── Marque / accent ───────────────────────────────────────────────────
  static Color get primary => _palette.primary;
  static Color get primaryDark => _palette.primaryDark;
  static Color get primaryTint => _palette.primaryTint;

  /// Texte ou icône posé **sur** la couleur de marque (bouton plein).
  static const onPrimary = Colors.white;

  // ── Fonds ─────────────────────────────────────────────────────────────
  /// Fond des pages (scaffold) et des en-têtes.
  static Color get scaffold => _palette.scaffold;
  static Color get header => _palette.scaffold;
  static Color get surface => _palette.surface; // cartes / conteneurs

  // ── En-tête ───────────────────────────────────────────────────────────
  /// Fond des boutons ronds d'en-tête (retour, actions).
  static Color get headerButton => _palette.headerButton;

  // ── Cartes en relief ──────────────────────────────────────────────────
  /// Filet dégradé des cartes mises en avant (solde de l'accueil, bandeau de
  /// profil des réglages) : posé en fond d'un conteneur de 1.5 px de padding,
  /// il dessine un contour clair-sombre qui décolle la carte de la page.
  static LinearGradient get cardBorderGradient => LinearGradient(
        colors: _palette.cardBorderGradient,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  /// Fond de ces mêmes cartes : une touche de la couleur de marque à peine
  /// posée, qui les rattache à l'accent sans concurrencer le contenu.
  static Color get cardTint => _palette.primary.withValues(alpha: 0.08);

  /// Arrondi extérieur des cartes en relief, et arrondi intérieur
  /// correspondant (extérieur moins l'épaisseur du filet).
  static const cardRadius = 18.0;
  static const cardInnerRadius = 16.5;

  // ── Texte / champs ────────────────────────────────────────────────────
  static Color get dark => _palette.dark;
  static Color get hint => _palette.hint;
  static Color get label => _palette.label;
  static Color get border => _palette.border;
  static Color get fieldFill => _palette.fieldFill;

  // ── Couleurs sémantiques (statuts / toasts) ───────────────────────────
  static Color get success => _palette.success;
  static Color get error => _palette.error;
  static Color get warning => _palette.warning;
  static Color get info => _palette.info;

  /// Sémantique « positif » et fonds pâles associés (voir [AppPalette]).
  static Color get positive => _palette.positive;
  static Color get positiveTint => _palette.positiveTint;
  static Color get warningTint => _palette.warningTint;
  static Color get errorTint => _palette.errorTint;
  static Color get infoTint => _palette.infoTint;

  // ── Neutres adaptatifs ────────────────────────────────────────────────
  // Équivalents des gris et du blanc posés en dur dans les pages : en clair ils
  // valent EXACTEMENT la couleur d'origine (rien ne bouge), en sombre une
  // valeur lisible sur fond sombre.

  /// Fond « blanc » d'un conteneur (carte, feuille, champ).
  static Color get blanc => estSombre ? _palette.surface : Colors.white;

  /// Texte ou icône « noir » (équivalent de `Colors.black87`).
  static Color get noir87 => estSombre ? _palette.dark : Colors.black87;

  static Color get grey50 =>
      estSombre ? const Color(0xFF20242C) : Colors.grey.shade50;
  static Color get grey100 =>
      estSombre ? const Color(0xFF272B34) : Colors.grey.shade100;
  static Color get grey200 =>
      estSombre ? const Color(0xFF2F343E) : Colors.grey.shade200;
  static Color get grey300 =>
      estSombre ? const Color(0xFF3B414D) : Colors.grey.shade300;
  static Color get grey400 =>
      estSombre ? const Color(0xFF6B7384) : Colors.grey.shade400;
  static Color get grey500 => estSombre ? const Color(0xFF8B94A5) : Colors.grey;
  static Color get grey600 =>
      estSombre ? const Color(0xFFA3ABB9) : Colors.grey.shade600;
  static Color get grey700 =>
      estSombre ? const Color(0xFFBCC2CD) : Colors.grey.shade700;

  /// Fond pâle posé en dur dans une page (pastille, bandeau, filet) : en clair
  /// la couleur d'origine, en sombre la même teinte ramenée à un fond profond —
  /// même famille de couleur, mais qui ne crève plus l'écran.
  static Color fond(int valeurClaire) {
    final clair = Color(valeurClaire);
    if (!estSombre) return clair;
    final hsl = HSLColor.fromColor(clair);
    return hsl
        .withSaturation((hsl.saturation * 0.6).clamp(0.0, 0.5))
        .withLightness(0.13 + (1 - hsl.lightness) * 0.9)
        .toColor();
  }
}

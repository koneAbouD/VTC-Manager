import 'package:flutter/material.dart';

/// Charte graphique centralisée de l'application.
///
/// **Source unique de vérité** des couleurs : modifier une valeur ici se
/// répercute partout (thème global + composants partagés + pages qui
/// référencent ces jetons).
abstract final class AppColors {
  // ── Marque / accent ───────────────────────────────────────────────────
  static const primary = Color(0xFF43A047);
  static const primaryDark = Color(0xFF2E7D32);
  static const primaryTint = Color(0xFFE8F5E9);

  // ── Fonds ─────────────────────────────────────────────────────────────
  /// Fond des pages (scaffold) et des en-têtes.
  static const scaffold = Color(0xFFF8F9FB);
  static const header = scaffold;
  static const surface = Color(0xFFFFFFFF); // cartes / conteneurs

  // ── En-tête ───────────────────────────────────────────────────────────
  /// Fond des boutons ronds d'en-tête (retour, actions).
  static const headerButton = Color(0xFFF0F2F8);

  // ── Cartes en relief ──────────────────────────────────────────────────
  /// Filet dégradé des cartes mises en avant (solde de l'accueil, bandeau de
  /// profil des réglages) : posé en fond d'un conteneur de 1.5 px de padding,
  /// il dessine un contour clair-sombre qui décolle la carte de la page.
  static const cardBorderGradient = LinearGradient(
    colors: [Color(0xFFBDBDBD), Color(0xFFEEEEEE), Color(0xFF9E9E9E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Fond de ces mêmes cartes : un vert à peine posé, qui les rattache à la
  /// couleur de marque sans concurrencer le contenu.
  static final cardTint = Colors.green.withValues(alpha: 0.08);

  /// Arrondi extérieur des cartes en relief, et arrondi intérieur
  /// correspondant (extérieur moins l'épaisseur du filet).
  static const cardRadius = 18.0;
  static const cardInnerRadius = 16.5;

  // ── Texte / champs ────────────────────────────────────────────────────
  static const dark = Color(0xFF1A1A2E);
  static const hint = Color(0xFF8A94A6);
  static const label = Color(0xFF6B7280);
  static const border = Color(0xFFE4E9EE);
  static const fieldFill = Color(0xFFF3F6F4);

  // ── Couleurs sémantiques (statuts / toasts) ───────────────────────────
  static const success = Color(0xFF1B5E20);
  static const error = Color(0xFFB71C1C);
  static const warning = Color(0xFFE65100);
  static const info = Color(0xFF1A237E);
}

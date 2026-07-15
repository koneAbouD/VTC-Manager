import 'package:flutter/material.dart';

/// Charte graphique centralisée de l'application (alignée sur l'app gestionnaire).
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

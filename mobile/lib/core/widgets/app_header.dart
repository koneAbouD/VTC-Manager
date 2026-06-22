import 'package:flutter/material.dart';

/// En-tête standard de toutes les pages.
///
/// Implémente [PreferredSizeWidget] → s'utilise directement en `appBar:`
/// sans aucun wrapper [PreferredSize] ni [SafeArea].
///
/// ```dart
/// // Cas minimal
/// appBar: const AppHeader(title: 'Ma page'),
///
/// // Avec action icône
/// appBar: AppHeader(
///   title: 'Ma page',
///   action: AppHeaderAction(icon: Icons.add_rounded, onTap: _add),
/// ),
///
/// // Sans bouton retour (écran racine)
/// appBar: AppHeader(title: '', showBack: false, action: ...),
/// ```
class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;

  /// Masque le bouton retour (ex. : écrans racines sans navigation parent).
  final bool showBack;

  /// Surcharge du comportement du bouton retour.
  final VoidCallback? backOverride;

  /// Widget affiché à droite. Si null et [showBack] est true → placeholder
  /// invisible pour centrer le titre.
  final Widget? action;

  /// Pill colorée affichée sous le titre (ex. : "Sélection").
  final String? badge;

  /// Couleur de fond (blanc par défaut).
  final Color? backgroundColor;

  const AppHeader({
    super.key,
    required this.title,
    this.showBack = true,
    this.backOverride,
    this.action,
    this.badge,
    this.backgroundColor,
  });

  @override
  Size get preferredSize => const Size.fromHeight(66);

  @override
  Widget build(BuildContext context) {
    final backBtn = showBack
        ? GestureDetector(
            onTap: backOverride ?? () => Navigator.of(context).pop(),
            child: Container(
              width: 56,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F2F8),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.arrow_back_rounded,
                  size: 18, color: Color(0xFF1A1A2E)),
            ),
          )
        : null;

    // Placeholder de même taille que le bouton pour centrer le titre.
    const placeholder = SizedBox(width: 56, height: 38);

    final titleColumn = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title.isNotEmpty)
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A1A2E),
              letterSpacing: -0.3,
            ),
          ),
        if (badge != null) ...[
          const SizedBox(height: 4),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFE3F0FF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              badge!,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1565C0),
              ),
            ),
          ),
        ],
      ],
    );

    // Layout selon la présence du bouton retour
    final row = showBack
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              backBtn!,
              Expanded(child: titleColumn),
              action ?? placeholder,
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: titleColumn),
              if (action != null) action!,
            ],
          );

    return Container(
      color: backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: row,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Bouton d'action ovale standard (même style que le bouton retour).
///
/// Supporte trois variantes :
/// - **icône** : [icon] seul → bouton ovale avec icône
/// - **texte** : [label] seul → bouton ovale avec texte "Modifier" etc.
/// - **chargement** : [loading] = true → indicateur circulaire à la place
class AppHeaderAction extends StatelessWidget {
  final VoidCallback? onTap;

  /// Icône affichée (mutuellement exclusif avec [label]).
  final IconData? icon;

  /// Taille de l'icône (20 par défaut).
  final double iconSize;

  /// Texte affiché à la place d'une icône (ex. : "Modifier").
  final String? label;

  /// Affiche un indicateur de chargement à la place de l'icône/texte.
  final bool loading;

  const AppHeaderAction({
    super.key,
    this.onTap,
    this.icon,
    this.iconSize = 20,
    this.label,
    this.loading = false,
  }) : assert(
          icon != null || label != null || loading,
          'AppHeaderAction requires icon, label, or loading:true',
        );

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (loading) {
      child = const Center(
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFF1A1A2E),
          ),
        ),
      );
    } else if (label != null) {
      child = Text(
        label!,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1A1A2E),
        ),
      );
    } else {
      child = Icon(icon, size: iconSize, color: const Color(0xFF1A1A2E));
    }

    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        height: 38,
        // Largeur fixe pour icône, padding horizontal pour texte
        width: label != null ? null : 56,
        padding: label != null
            ? const EdgeInsets.symmetric(horizontal: 14)
            : null,
        decoration: BoxDecoration(
          color: const Color(0xFFF0F2F8),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(child: child),
      ),
    );
  }
}

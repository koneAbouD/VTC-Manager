import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

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

  /// Widget affiché à droite. Sa largeur est libre : le titre reste centré sur
  /// la barre quoi qu'il arrive.
  final Widget? action;

  /// Widget affiché à gauche sur les écrans racines (ex. : bouton menu de
  /// l'accueil). Ignoré quand [showBack] est true, le bouton retour occupant
  /// déjà cette place.
  final Widget? leading;

  /// Pill colorée affichée sous le titre (ex. : "Sélection").
  final String? badge;

  /// Contenu centré à la place du titre (ex. : pastilles d'onglets de la
  /// Flotte). Occupe la place laissée libre par [leading] et [action] ;
  /// [title] et [badge] sont alors ignorés.
  final Widget? center;

  /// Couleur de fond (blanc par défaut).
  final Color? backgroundColor;

  /// Fond du bouton retour ([AppColors.headerButton] par défaut). À surcharger
  /// quand l'en-tête est posé sur une teinte proche, où la pastille se
  /// confondrait avec le fond.
  final Color? backButtonColor;

  const AppHeader({
    super.key,
    required this.title,
    this.showBack = true,
    this.backOverride,
    this.action,
    this.badge,
    this.backgroundColor,
    this.backButtonColor,
    this.leading,
    this.center,
  });

  /// Padding vertical de la barre, en haut comme en bas.
  static const double _paddingVertical = 14;

  /// Hauteur du contenu, paddings exclus : celle du bouton retour.
  static const double _hauteurContenu = 38;

  /// Hauteur du contenu avec badge : le titre (~24) et la pilule (~20)
  /// s'empilent, séparés de 4. Sans ce supplément, la colonne déborde de
  /// l'en-tête ("RenderFlex overflowed on the bottom").
  static const double _hauteurContenuBadge = 62;

  /// Hauteur du contenu selon la présence du badge.
  double get _hauteurContenuEffective =>
      badge == null ? _hauteurContenu : _hauteurContenuBadge;

  @override
  Size get preferredSize =>
      Size.fromHeight(_hauteurContenuEffective + _paddingVertical * 2);

  @override
  Widget build(BuildContext context) {
    final backBtn = showBack
        ? GestureDetector(
            onTap: backOverride ?? () => Navigator.of(context).pop(),
            child: Container(
              width: 56,
              height: 38,
              decoration: BoxDecoration(
                color: backButtonColor ?? AppColors.headerButton,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.arrow_back_rounded,
                  size: 18, color: AppColors.dark),
            ),
          )
        : null;

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
              color: AppColors.dark,
              letterSpacing: -0.3,
            ),
          ),
        if (badge != null) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primaryTint,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              badge!,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ],
    );

    // Le titre est centré sur la barre, et non dans la place que lui laissent
    // ses voisins : une action large (filtre, bouton « Modifier ») ne le
    // décale donc plus. [NavigationToolbar] — la mécanique interne d'[AppBar] —
    // s'en charge, et le repousse de lui-même le jour où le titre et une
    // action se disputeraient la même place.
    // Hauteur imposée : la toolbar cherche à remplir ce qu'on lui donne, et
    // [AppHeader] ne sert pas qu'en `appBar:` — posé dans le corps d'une page
    // (bandeau de profil des réglages), il reçoit une hauteur illimitée et
    // s'étirerait à l'infini.
    final row = SizedBox(
      height: _hauteurContenuEffective,
      child: NavigationToolbar(
        leading: showBack ? backBtn : leading,
        middle: center ?? titleColumn,
        trailing: action,
        centerMiddle: true,
        // Les pastilles d'onglets occupent toute la ligne : sans marge propre,
        // elles colleraient un bouton latéral quand il y en a un.
        middleSpacing: center != null ? 4 : 8,
      ),
    );

    return Container(
      color: backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: _paddingVertical),
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
      child = const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.dark,
        ),
      );
    } else if (label != null) {
      child = Text(
        label!,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.dark,
        ),
      );
    } else {
      child = Icon(icon, size: iconSize, color: AppColors.dark);
    }

    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        height: 38,
        // Largeur fixe pour icône, padding horizontal pour texte
        width: label != null ? null : 56,
        padding:
            label != null ? const EdgeInsets.symmetric(horizontal: 14) : null,
        decoration: BoxDecoration(
          color: AppColors.headerButton,
          borderRadius: BorderRadius.circular(20),
        ),
        // `widthFactor: 1` : le bouton se règle sur son contenu. Un [Center]
        // nu s'étirerait à toute la largeur offerte — sans conséquence dans une
        // Row, mais la barre borne désormais ses côtés pour centrer le titre,
        // et le bouton « Modifier » s'étalait alors sur tout l'en-tête.
        child: Align(widthFactor: 1, heightFactor: 1, child: child),
      ),
    );
  }
}

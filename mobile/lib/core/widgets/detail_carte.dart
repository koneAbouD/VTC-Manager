import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'long_press_info_bubble.dart';

/// Briques d'une page de détail « à la maintenance » : une carte d'en-tête qui
/// nomme l'objet et son statut, puis une carte unique où les couples
/// libellé/valeur se lisent d'un trait — sans titre de rubrique ni filet.
///
/// Elles reprennent les mesures de [MaintenanceDetailPage] pour que les pages
/// de détail des différents modules se ressemblent.

/// En-tête : pastille colorée par le statut, libellé de l'objet, et badge de
/// statut poussé au bord droit. Tout est centré sur la hauteur de la pastille.
class DetailHeroCard extends StatelessWidget {
  final IconData icon;
  final String titre;
  final String statutLabel;
  final Color statutColor;

  /// Teinte de la pastille quand elle ne doit pas suivre le statut — le sens
  /// d'un mouvement de caisse, par exemple, ne se déduit pas de son statut.
  final Color? iconColor;

  const DetailHeroCard({
    super.key,
    required this.icon,
    required this.titre,
    required this.statutLabel,
    required this.statutColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final teinte = iconColor ?? statutColor;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: teinte.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: teinte, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              titre,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.dark,
                  letterSpacing: -0.3),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statutColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              statutLabel,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: statutColor),
            ),
          ),
        ],
      ),
    );
  }
}

/// Carte unique des rubriques : la marge appartient à la carte, ses enfants ne
/// font que se suivre. Le retrait bas est plus court que le haut, la dernière
/// ligne apportant déjà le sien.
class DetailInfoCard extends StatelessWidget {
  final List<Widget> children;

  const DetailInfoCard({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

/// Ligne libellé/valeur. Se masque quand la valeur est nulle ou vide, ce qui
/// dispense l'appelant de conditionner chaque ligne.
class DetailInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;

  const DetailInfoRow(this.icon, this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: AppColors.label),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Text(label,
                style: const TextStyle(fontSize: 13, color: AppColors.label)),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value!,
              textAlign: TextAlign.end,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.dark),
            ),
          ),
        ],
      ),
    );
  }
}

/// Variante actionnable de [DetailInfoRow] : la ligne reste en tout point
/// identique aux autres — même icône, même libellé, mêmes mesures — et seule
/// **la valeur** répond au toucher. Le libellé n'est pas un bouton : c'est le
/// nom du chauffeur qu'on va changer, pas le mot « Chauffeur ».
///
/// L'affordance tient à un rien : un chevron suit la valeur. Le nom, lui, garde
/// le noir des autres rubriques — le teinter le faisait lire comme autre chose
/// qu'une donnée de la fiche.
///
/// Quand [verrouille] est vrai, le chevron cède la place à un cadenas et le tap
/// n'ouvre rien : un appui
/// prolongé montre [motifVerrou] dans une bulle. Dire pourquoi c'est fermé vaut
/// mieux que retirer l'indice, qui laisserait chercher.
class DetailInfoRowAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback onTap;

  /// Teinte du chevron — le seul indice que la valeur est modifiable.
  /// Défaut : le vert de la charte.
  final Color accent;

  final bool verrouille;
  final String? motifVerrou;

  const DetailInfoRowAction(
    this.icon,
    this.label,
    this.value, {
    super.key,
    required this.onTap,
    this.accent = AppColors.primaryDark,
    this.verrouille = false,
    this.motifVerrou,
  });

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.isEmpty) return const SizedBox.shrink();

    // La valeur et son indice, réunis : c'est la seule zone qui réagit.
    Widget valeur = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            value!,
            textAlign: TextAlign.end,
            // Le noir des autres valeurs, verrouillée ou non : la teinte
            // signalait l'action, mais elle faisait aussi lire le nom comme
            // autre chose qu'une donnée de la fiche. Le chevron suffit à dire
            // qu'on peut le toucher.
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.dark),
          ),
        ),
        const SizedBox(width: 3),
        Icon(
          verrouille ? Icons.lock_outline_rounded : Icons.chevron_right_rounded,
          size: verrouille ? 12 : 15,
          color: verrouille ? AppColors.hint : accent,
        ),
      ],
    );

    // Aucun retrait autour de la zone tactile : la valeur doit rester sur la
    // même ligne de base que celles des rubriques voisines. La cible fait la
    // hauteur du texte et la largeur du nom — celle d'un lien dans une phrase.
    valeur = verrouille
        ? LongPressInfoBubble(
            infoText: motifVerrou ?? 'Cette valeur ne peut plus être modifiée.',
            color: AppColors.warning,
            child: valeur,
          )
        : Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: onTap,
              child: valeur,
            ),
          );

    // À partir d'ici, mesures strictement identiques à [DetailInfoRow].
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: AppColors.label),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Text(label,
                style: const TextStyle(fontSize: 13, color: AppColors.label)),
          ),
          Expanded(
            flex: 3,
            child: Align(alignment: Alignment.centerRight, child: valeur),
          ),
        ],
      ),
    );
  }
}

/// En-tête d'une sous-liste, au style d'une ligne d'info : icône fine et
/// libellé discret, pour qu'il se lise dans la continuité des lignes.
class DetailLabel extends StatelessWidget {
  final IconData icon;
  final String label;

  const DetailLabel(this.icon, this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 10),
      child: Row(children: [
        Icon(icon, size: 15, color: AppColors.label),
        const SizedBox(width: 10),
        Text(label,
            style: const TextStyle(fontSize: 13, color: AppColors.label)),
      ]),
    );
  }
}

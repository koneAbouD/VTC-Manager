import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

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

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Briques d'interface « premium » partagées par les pages de détail finance
/// (recette, cotisation, pénalité, contravention). Même langage visuel que les
/// cartes de `rapports_tab.dart` : surfaces arrondies, bordures fines,
/// pastilles d'icône teintées et hiérarchie typographique nette.

/// En-tête synthèse : montant en gros, puces de statut, puis une ligne de
/// contexte (véhicule / chauffeur…).
class PremiumHero extends StatelessWidget {
  final String amount;
  final List<Widget> chips;
  final IconData footerIcon;
  final String footer;

  const PremiumHero({
    super.key,
    required this.amount,
    this.chips = const [],
    this.footerIcon = Icons.directions_car_outlined,
    required this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(amount,
              style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.dark,
                  letterSpacing: -0.5)),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: chips),
          ],
          const SizedBox(height: 14),
          Row(children: [
            Icon(footerIcon, size: 16, color: AppColors.label),
            const SizedBox(width: 8),
            Expanded(
              child: Text(footer,
                  style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.dark)),
            ),
          ]),
        ],
      ),
    );
  }
}

/// Carte-section : en-tête (icône teintée + titre) puis lignes. La section
/// disparaît si toutes ses lignes sont vides (`PremiumRow` masqués).
class PremiumSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  final Color accent;

  const PremiumSection({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
    this.accent = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    if (children.every((w) => w is SizedBox)) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 18, color: accent),
            const SizedBox(width: 8),
            Text(title,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.dark)),
          ]),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

/// Ligne label / valeur. Se masque si la valeur est nulle ou vide.
class PremiumRow extends StatelessWidget {
  final String label;
  final String? value;
  final bool strong;
  final Color? valueColor;

  const PremiumRow(this.label, this.value,
      {super.key, this.strong = false, this.valueColor});

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: const TextStyle(fontSize: 12.5, color: AppColors.label)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(value!,
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
                    color: valueColor ?? AppColors.dark)),
          ),
        ],
      ),
    );
  }
}

/// Puce de statut colorée.
class PremiumChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const PremiumChip(this.label, this.color, {super.key, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
        ],
        Text(label,
            style: TextStyle(
                fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}

/// Titre d'une liste (« Encaissements (2) »).
class PremiumListHeader extends StatelessWidget {
  final String title;
  const PremiumListHeader(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Text(title,
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.dark)),
    );
  }
}

/// Tuile d'un encaissement : pastille + montant + mode·date·réf, et le
/// commentaire de saisie s'il existe.
class PremiumEncaissementTile extends StatelessWidget {
  final String montant;
  final String meta;
  final String? commentaire;
  final bool especes;

  const PremiumEncaissementTile({
    super.key,
    required this.montant,
    required this.meta,
    this.commentaire,
    required this.especes,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primaryTint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(especes ? Icons.payments_outlined : Icons.smartphone,
                size: 21, color: AppColors.primaryDark),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(montant,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.dark)),
                const SizedBox(height: 2),
                Text(meta,
                    style:
                        const TextStyle(fontSize: 12, color: AppColors.label)),
                if (commentaire != null && commentaire!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(commentaire!,
                      style: const TextStyle(
                          fontSize: 12.5,
                          height: 1.3,
                          fontStyle: FontStyle.italic,
                          color: AppColors.dark)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// État vide d'une liste.
class PremiumEmpty extends StatelessWidget {
  final String message;
  final IconData icon;
  const PremiumEmpty(this.message,
      {super.key, this.icon = Icons.inbox_outlined});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 22),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.8),
      ),
      child: Column(children: [
        Icon(icon, size: 26, color: AppColors.hint),
        const SizedBox(height: 6),
        Text(message,
            style: const TextStyle(fontSize: 12.5, color: AppColors.label)),
      ]),
    );
  }
}

/// Bouton d'action pleine largeur. `filled` → plein coloré ; sinon contour.
class PremiumButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool filled;
  final VoidCallback onPressed;

  const PremiumButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.color = AppColors.primary,
    this.filled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SizedBox(
        height: 50,
        width: double.infinity,
        child: filled
            ? FilledButton.icon(
                onPressed: onPressed,
                style: FilledButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                icon: Icon(icon, size: 18),
                label: Text(label,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
              )
            : OutlinedButton.icon(
                onPressed: onPressed,
                style: OutlinedButton.styleFrom(
                  foregroundColor: color,
                  side: BorderSide(color: color.withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                icon: Icon(icon, size: 18),
                label: Text(label,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
              ),
      ),
    );
  }
}

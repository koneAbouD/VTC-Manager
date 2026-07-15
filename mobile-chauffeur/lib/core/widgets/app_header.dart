import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// En-tête personnalisé (charte app gestionnaire) : pastille retour à gauche,
/// titre centré, pastille d'action optionnelle à droite.
class AppHeader extends StatelessWidget {
  final String titre;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  const AppHeader({
    super.key,
    required this.titre,
    this.actionIcon,
    this.onAction,
  });

  Widget _pill(IconData icon, VoidCallback? onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 56,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.headerButton,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(icon, size: 18, color: AppColors.dark),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.header,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          _pill(Icons.arrow_back_rounded, () => Navigator.pop(context)),
          Expanded(
            child: Text(
              titre,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.dark,
                letterSpacing: -0.3,
              ),
            ),
          ),
          // Pastille d'action, ou espace équivalent pour garder le titre centré.
          actionIcon != null
              ? _pill(actionIcon!, onAction)
              : const SizedBox(width: 56),
        ],
      ),
    );
  }
}

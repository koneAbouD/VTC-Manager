import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Décoration d'un choix de formulaire (tuile, pastille, ligne de liste) :
/// le style premium partagé, celui des onglets « Informations / Documents »
/// des fiches véhicule et chauffeur.
///
/// - Au repos : fond gris des champs, sans contour — il se lit comme un champ.
/// - Choisi : fond de surface (blanc en clair) détaché par un léger relief,
///   contour à la [couleur] (l'accent par défaut).
///
/// Jamais de fond teinté : un choix n'est pas un statut, il ne doit pas
/// colorer le formulaire. La [couleur] reste réservée au contour, au texte et
/// à l'icône du choix retenu.
BoxDecoration decorationChoix({
  required bool choisi,
  Color? couleur,
  double rayon = 12,
}) {
  return BoxDecoration(
    color: choisi ? AppColors.surface : AppColors.fieldFill,
    borderRadius: BorderRadius.circular(rayon),
    border: Border.all(
      color: choisi ? (couleur ?? AppColors.primary) : Colors.transparent,
      width: 1.5,
    ),
    boxShadow: choisi
        ? [
            BoxShadow(
              color: Colors.black
                  .withValues(alpha: AppColors.estSombre ? 0.35 : 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ]
        : const [],
  );
}

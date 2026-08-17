import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Apparence d'un type de notification, partagée par le centre de notifications
/// et le bandeau affiché à la réception.
///
/// Les deux doivent se ressembler : c'est le même événement, vu une fois quand
/// il arrive et une fois quand on le relit. Une icône qui change entre les deux
/// donnerait à croire qu'il s'agit de deux faits différents.
IconData iconeNotification(String type) => switch (type) {
      'PENALITE_APPLIQUEE' => Icons.gavel_rounded,
      'ARRETE_COMPTE_DISPONIBLE' => Icons.receipt_long_rounded,
      'MAINTENANCE_A_VENIR' => Icons.build_circle_outlined,
      'RECETTE_ENCAISSEE' => Icons.payments_rounded,
      // Même icône que le bouton « Cotisations » de l'accueil.
      'COTISATION_ENCAISSEE' => Icons.analytics_outlined,
      _ => Icons.notifications_none_rounded,
    };

Color couleurNotification(String type) => switch (type) {
      'PENALITE_APPLIQUEE' => AppColors.error,
      'ARRETE_COMPTE_DISPONIBLE' => AppColors.info,
      'MAINTENANCE_A_VENIR' => AppColors.warning,
      // Les rentrées d'argent, en vert : elles se repèrent d'un coup d'œil dans
      // une liste où le reste alerte.
      'RECETTE_ENCAISSEE' || 'COTISATION_ENCAISSEE' => AppColors.success,
      _ => AppColors.primary,
    };

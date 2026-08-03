import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Apparence d'un type de notification, partagée par le centre de notifications
/// et le bandeau affiché à la réception.
///
/// Les deux doivent se ressembler : c'est le même événement, vu une fois quand
/// il arrive et une fois quand on le relit.
IconData iconeNotification(String type) => switch (type) {
      'PENALITE_APPLIQUEE' => Icons.gavel_rounded,
      'ARRETE_COMPTE_DISPONIBLE' => Icons.receipt_long_rounded,
      'RECETTE_ENCAISSEE' => Icons.payments_rounded,
      'COTISATION_ENCAISSEE' => Icons.savings_rounded,
      _ => Icons.notifications_none_rounded,
    };

Color couleurNotification(String type) => switch (type) {
      'PENALITE_APPLIQUEE' => AppColors.error,
      'ARRETE_COMPTE_DISPONIBLE' => AppColors.info,
      // L'accusé d'un versement : ce que le chauffeur vient de remettre a bien
      // été porté à son compte.
      'RECETTE_ENCAISSEE' || 'COTISATION_ENCAISSEE' => AppColors.success,
      _ => AppColors.primary,
    };

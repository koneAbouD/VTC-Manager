import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Icône d'un type de maintenance.
///
/// Les types sont des données de référence (catégories de la sous-catégorie
/// « Maintenances ») sans icône en base : la correspondance se fait sur des
/// mots-clés du code ou du libellé. Les types ne portent pas de couleur
/// propre : la page les présente tous à la couleur d'accent du thème.
class TypeMaintenanceVisuel {
  TypeMaintenanceVisuel._();

  /// [code] et [libelle] sont essayés tous deux : le code historique d'une
  /// maintenance (`type`) n'est pas toujours celui de sa catégorie.
  static IconData icone({String? code, String? libelle}) {
    final cle = _sansAccents('${code ?? ''} ${libelle ?? ''}'.toUpperCase());
    if (cle.contains('VIDANGE')) return Icons.oil_barrel_outlined;
    if (cle.contains('REVISION')) return Icons.settings_outlined;
    if (cle.contains('REPARATION')) return Icons.handyman_outlined;
    if (cle.contains('MECANIQUE')) return Icons.build_outlined;
    if (cle.contains('CONTROLE')) return Icons.fact_check_outlined;
    if (cle.contains('PNEU')) return Icons.tire_repair_outlined;
    if (cle.contains('FREIN')) return Icons.emergency_outlined;
    if (cle.contains('PARALIS') || cle.contains('PARALYS')) {
      return Icons.car_crash_outlined;
    }
    if (cle.contains('TOLERIE')) return Icons.car_repair_outlined;
    if (cle.contains('PEINTURE')) return Icons.brush_outlined;
    if (cle.contains('ELECTRIC')) return Icons.electrical_services_outlined;
    if (cle.contains('CLIM')) return Icons.ac_unit_outlined;
    return Icons.construction_outlined;
  }

  static String _sansAccents(String s) => s
      .replaceAll(RegExp('[ÉÈÊË]'), 'E')
      .replaceAll(RegExp('[ÀÂÄ]'), 'A')
      .replaceAll(RegExp('[ÎÏ]'), 'I')
      .replaceAll(RegExp('[ÔÖ]'), 'O')
      .replaceAll(RegExp('[ÙÛÜ]'), 'U')
      .replaceAll('Ç', 'C');
}

/// Libellé et couleur d'un statut de maintenance, partagés par la liste et ses
/// pastilles de filtre.
class StatutMaintenanceVisuel {
  StatutMaintenanceVisuel._();

  /// Ambre des interventions au programme, aligné sur la page Contraventions.
  static Color get _ambre =>
      AppColors.estSombre ? const Color(0xFFE0A050) : const Color(0xFF854F0B);

  static String libelle(String? statut) => switch (statut) {
        'TERMINEE' => 'Terminée',
        'EN_COURS' => 'En cours',
        'ANNULEE' => 'Annulée',
        _ => 'Planifiée',
      };

  /// Libellé au pluriel, pour les pastilles de filtre.
  static String libellePluriel(String statut) => switch (statut) {
        'TERMINEE' => 'Terminées',
        'EN_COURS' => 'En cours',
        'ANNULEE' => 'Annulées',
        _ => 'Planifiées',
      };

  static Color couleur(String? statut) => switch (statut) {
        'TERMINEE' => AppColors.positive,
        'EN_COURS' => AppColors.info,
        'ANNULEE' => AppColors.hint,
        _ => _ambre,
      };

  /// Couleur du retard : une planifiée dont la date est passée.
  static Color get retard => AppColors.error;

  /// Jours de retard d'une intervention encore au programme ; 0 si elle n'est
  /// pas en retard (date du jour ou à venir, ou déjà close).
  static int joursDeRetard(String? statut, DateTime datePrevue,
      {DateTime? maintenant}) {
    if (statut != null && statut != 'PLANIFIEE') return 0;
    final now = maintenant ?? DateTime.now();
    final aujourdhui = DateTime(now.year, now.month, now.day);
    final prevue = DateTime(datePrevue.year, datePrevue.month, datePrevue.day);
    final jours = aujourdhui.difference(prevue).inDays;
    return jours > 0 ? jours : 0;
  }
}

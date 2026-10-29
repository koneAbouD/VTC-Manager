import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Icône et couleur d'un type de maintenance.
///
/// Les types sont des données de référence (catégories de la sous-catégorie
/// « Maintenances ») sans couleur ni icône en base : la correspondance se fait
/// sur des mots-clés du code ou du libellé. Un type inconnu — ajouté plus tard
/// au paramétrage — reçoit une teinte de repli choisie par son identifiant,
/// stable d'un écran à l'autre.
///
/// Ce sont des couleurs de données, comme celles des statuts véhicule : elles
/// restent des littéraux, mais avec une déclinaison claire et une sombre pour
/// rester lisibles quel que soit le thème.
class TypeMaintenanceVisuel {
  final IconData icone;
  final Color _clair;
  final Color _sombre;

  const TypeMaintenanceVisuel._(this.icone, this._clair, this._sombre);

  Color get couleur => AppColors.estSombre ? _sombre : _clair;

  static const _vidange = TypeMaintenanceVisuel._(
      Icons.oil_barrel_outlined, Color(0xFFB7791F), Color(0xFFE0A84F));
  static const _revision = TypeMaintenanceVisuel._(
      Icons.settings_outlined, Color(0xFF1E6FD9), Color(0xFF6EA8F5));
  static const _reparation = TypeMaintenanceVisuel._(
      Icons.handyman_outlined, Color(0xFF5E35B1), Color(0xFFA58BE6));
  static const _mecanique = TypeMaintenanceVisuel._(
      Icons.build_outlined, Color(0xFF3949AB), Color(0xFF9FA8DA));
  static const _controle = TypeMaintenanceVisuel._(
      Icons.fact_check_outlined, Color(0xFF00897B), Color(0xFF4DB6AC));
  static const _pneus = TypeMaintenanceVisuel._(
      Icons.tire_repair_outlined, Color(0xFF546E7A), Color(0xFF90A4AE));
  static const _freinage = TypeMaintenanceVisuel._(
      Icons.emergency_outlined, Color(0xFFC62828), Color(0xFFEF6C6C));
  static const _paralysie = TypeMaintenanceVisuel._(
      Icons.car_crash_outlined, Color(0xFFAD1457), Color(0xFFF06292));
  static const _tolerie = TypeMaintenanceVisuel._(
      Icons.car_repair_outlined, Color(0xFF8D6E63), Color(0xFFBCA59C));
  static const _peinture = TypeMaintenanceVisuel._(
      Icons.brush_outlined, Color(0xFFD84315), Color(0xFFFF8A65));
  static const _electricite = TypeMaintenanceVisuel._(
      Icons.electrical_services_outlined, Color(0xFFB98700), Color(0xFFF2C94C));
  static const _climatisation = TypeMaintenanceVisuel._(
      Icons.ac_unit_outlined, Color(0xFF0288D1), Color(0xFF4FC3F7));

  /// Teintes des types que les mots-clés ne reconnaissent pas.
  static const _replis = [
    TypeMaintenanceVisuel._(
        Icons.construction_outlined, Color(0xFF00838F), Color(0xFF4DD0E1)),
    TypeMaintenanceVisuel._(
        Icons.construction_outlined, Color(0xFF6A1B9A), Color(0xFFCE93D8)),
    TypeMaintenanceVisuel._(
        Icons.construction_outlined, Color(0xFF558B2F), Color(0xFFAED581)),
    TypeMaintenanceVisuel._(
        Icons.construction_outlined, Color(0xFF4E342E), Color(0xFFA1887F)),
  ];

  /// [code] et [libelle] sont essayés tous deux : le code historique d'une
  /// maintenance (`type`) n'est pas toujours celui de sa catégorie.
  static TypeMaintenanceVisuel de({String? code, String? libelle, int? id}) {
    final cle = _sansAccents('${code ?? ''} ${libelle ?? ''}'.toUpperCase());
    if (cle.contains('VIDANGE')) return _vidange;
    if (cle.contains('REVISION')) return _revision;
    if (cle.contains('REPARATION')) return _reparation;
    if (cle.contains('MECANIQUE')) return _mecanique;
    if (cle.contains('CONTROLE')) return _controle;
    if (cle.contains('PNEU')) return _pneus;
    if (cle.contains('FREIN')) return _freinage;
    if (cle.contains('PARALIS') || cle.contains('PARALYS')) return _paralysie;
    if (cle.contains('TOLERIE')) return _tolerie;
    if (cle.contains('PEINTURE')) return _peinture;
    if (cle.contains('ELECTRIC')) return _electricite;
    if (cle.contains('CLIM')) return _climatisation;
    return _replis[(id ?? cle.hashCode).abs() % _replis.length];
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

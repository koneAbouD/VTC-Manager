import 'package:flutter/material.dart';

/// Statut d'un véhicule, piloté par la base via `/api/v1/statuts-vehicule`
/// (libellé, signification, couleur). Un repli local couvre les codes connus
/// pendant le chargement, hors-ligne ou si l'API renvoie un code inconnu.
class StatutVehicule {
  final String code;
  final String libelle;
  final String? signification;
  final Color couleur;
  final int ordre;

  const StatutVehicule({
    required this.code,
    required this.libelle,
    this.signification,
    required this.couleur,
    required this.ordre,
  });

  factory StatutVehicule.fromJson(Map<String, dynamic> json) => StatutVehicule(
        code: (json['code'] ?? '').toString(),
        libelle: (json['libelle'] ?? json['code'] ?? '').toString(),
        signification: json['signification'] as String?,
        couleur:
            _parseHexColor(json['couleur'] as String?) ?? const Color(0xFF9E9E9E),
        ordre: (json['ordre'] as num?)?.toInt() ?? 0,
      );

  /// Couleur de fond atténuée pour pastilles / badges.
  Color get background => couleur.withValues(alpha: 0.12);

  /// Icône de présentation (non stockée en base), dérivée du code.
  IconData get icon => switch (code) {
        'EN_SERVICE' => Icons.directions_car_rounded,
        'DISPONIBLE' => Icons.check_circle_outline,
        'EN_MAINTENANCE' => Icons.build_circle_outlined,
        'IMMOBILISE' => Icons.warning_amber_rounded,
        'HORS_PARC' => Icons.block_outlined,
        _ => Icons.help_outline,
      };

  /// Repli local — couleurs alignées sur le seed backend (V13.0.0).
  static const List<StatutVehicule> fallback = [
    StatutVehicule(
        code: 'EN_SERVICE',
        libelle: 'En service',
        signification: 'Affecté à un chauffeur, en exploitation',
        couleur: Color(0xFF22C55E),
        ordre: 1),
    StatutVehicule(
        code: 'DISPONIBLE',
        libelle: 'Disponible',
        signification: 'Opérationnel mais sans chauffeur affecté',
        couleur: Color(0xFF3B82F6),
        ordre: 2),
    StatutVehicule(
        code: 'EN_MAINTENANCE',
        libelle: 'En maintenance',
        signification: 'Immobilisé pour entretien/réparation',
        couleur: Color(0xFFF97316),
        ordre: 3),
    StatutVehicule(
        code: 'IMMOBILISE',
        libelle: 'Immobilisé',
        signification: 'Panne, accident, saisie, contravention bloquante',
        couleur: Color(0xFFEF4444),
        ordre: 4),
    StatutVehicule(
        code: 'HORS_PARC',
        libelle: 'Hors parc',
        signification: 'Vendu, réformé, restitué (leasing)',
        couleur: Color(0xFF6B7280),
        ordre: 5),
  ];

  static const StatutVehicule inconnu = StatutVehicule(
      code: '', libelle: 'Inconnu', couleur: Color(0xFF9E9E9E), ordre: 999);

  /// Résout un code en [StatutVehicule] à partir d'une liste (chargée depuis
  /// l'API), avec repli sur la liste locale puis sur [inconnu].
  static StatutVehicule resolve(String? code, [List<StatutVehicule>? statuts]) {
    if (code == null || code.isEmpty) return inconnu;
    final source = (statuts != null && statuts.isNotEmpty) ? statuts : fallback;
    for (final s in source) {
      if (s.code == code) return s;
    }
    for (final s in fallback) {
      if (s.code == code) return s;
    }
    return inconnu;
  }
}

/// Convertit une couleur hexadécimale ("#RRGGBB" ou "#AARRGGBB") en [Color].
Color? _parseHexColor(String? hex) {
  if (hex == null) return null;
  var h = hex.replaceAll('#', '').trim();
  if (h.length == 6) h = 'FF$h';
  if (h.length != 8) return null;
  final value = int.tryParse(h, radix: 16);
  return value == null ? null : Color(value);
}

import 'package:flutter/material.dart';

class VehiculeStatusBadge extends StatelessWidget {
  final String? statut;
  const VehiculeStatusBadge({super.key, this.statut});

  @override
  Widget build(BuildContext context) {
    final (label, color) = _resolve(statut);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  static (String, Color) _resolve(String? statut) {
    return switch (statut) {
      'DISPONIBLE' => ('Disponible', const Color(0xFF2E7D32)),
      'EN_SERVICE' => ('En service', const Color(0xFF1565C0)),
      'EN_MAINTENANCE' => ('Maintenance', const Color(0xFFE65100)),
      'HORS_SERVICE' => ('Hors service', const Color(0xFFC62828)),
      _ => ('Inconnu', Colors.grey),
    };
  }
}

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Puce de statut colorée réutilisable.
class StatutChip extends StatelessWidget {
  final String? statut;
  const StatutChip(this.statut, {super.key});

  @override
  Widget build(BuildContext context) {
    final s = (statut ?? '').toUpperCase();
    final (Color bg, Color fg) = switch (s) {
      'SOLDEE' || 'PAYEE' || 'PAYE' || 'RESTITUEE' => (
          AppColors.primaryTint,
          AppColors.success
        ),
      'ANNULEE' || 'ANNULE' => (const Color(0xFFF1F1F1), Colors.black54),
      'PARTIELLE' || 'PARTIEL' => (const Color(0xFFFFF4E5), AppColors.warning),
      _ => (const Color(0xFFFDECEA), AppColors.error),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(s.isEmpty ? '—' : s,
          style: TextStyle(
              color: fg, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

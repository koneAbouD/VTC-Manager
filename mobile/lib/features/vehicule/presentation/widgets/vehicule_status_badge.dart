import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/statut_vehicule.dart';
import '../providers/referentiel_provider.dart';

class VehiculeStatusBadge extends ConsumerWidget {
  final String? statut;
  const VehiculeStatusBadge({super.key, this.statut});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statuts = ref.watch(statutsVehiculeResolvedProvider);
    final s = StatutVehicule.resolve(statut, statuts);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: s.couleur.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: s.couleur.withValues(alpha: 0.4)),
      ),
      child: Text(
        s.libelle,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: s.couleur,
        ),
      ),
    );
  }
}

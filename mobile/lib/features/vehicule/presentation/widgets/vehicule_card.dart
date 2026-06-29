import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/statut_vehicule.dart';
import '../../domain/entities/vehicule.dart';
import '../providers/referentiel_provider.dart';

class VehiculeCard extends ConsumerWidget {
  final Vehicule vehicule;

  const VehiculeCard({super.key, required this.vehicule});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDisponible = vehicule.statut == 'DISPONIBLE';
    final s = StatutVehicule.resolve(
        vehicule.statut, ref.watch(statutsVehiculeResolvedProvider));
    final statusLabel = s.libelle;
    final statusColor = s.couleur;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDisponible
              ? const Color(0xFF2E7D32).withValues(alpha: 0.35)
              : const Color(0xFFE4E9F5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isDisponible)
                Container(width: 4, color: const Color(0xFF2E7D32)),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                      isDisponible ? 12 : 16, 14, 16, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              vehicule.immatriculation,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1A1A2E),
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              vehicule.displayName,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF6B7280),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (vehicule.kilometrage != null) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.speed_outlined,
                                      size: 13, color: Color(0xFFADB5BD)),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${vehicule.kilometrage} km',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFFADB5BD),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      _StatusPill(
                        label: statusLabel,
                        color: statusColor,
                        isDisponible: isDisponible,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final bool isDisponible;

  const _StatusPill({
    required this.label,
    required this.color,
    required this.isDisponible,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDisponible ? color : color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: isDisponible ? null : Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isDisponible) ...[
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isDisponible ? Colors.white : color,
            ),
          ),
        ],
      ),
    );
  }
}

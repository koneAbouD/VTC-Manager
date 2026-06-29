import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/app_header.dart';
import '../../domain/entities/vehicule.dart';
import '../providers/vehicule_provider.dart';
import '../providers/vehicule_state.dart';

class VehiculeSelectorPage extends ConsumerStatefulWidget {
  const VehiculeSelectorPage({super.key});

  @override
  ConsumerState<VehiculeSelectorPage> createState() =>
      _VehiculeSelectorPageState();
}

class _VehiculeSelectorPageState extends ConsumerState<VehiculeSelectorPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vehiculeNotifierProvider);

    final List<Vehicule> allVehicules = switch (state) {
      VehiculeLoaded(:final vehicules) => vehicules,
      VehiculeActionSuccess(:final vehicules) => vehicules,
      _ => [],
    };

    final filtered = _query.isEmpty
        ? allVehicules
        : allVehicules
            .where((v) =>
                v.immatriculation
                    .toLowerCase()
                    .contains(_query.toLowerCase()) ||
                v.displayName.toLowerCase().contains(_query.toLowerCase()))
            .toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const AppHeader(title: 'Sélectionner un véhicule'),
      body: Column(
        children: [
          // ── Barre de recherche ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Rechercher un véhicule...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
              ),
            ),
          ),

          // ── Liste ───────────────────────────────────────────────────────
          Expanded(
            child: filtered.isEmpty
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.directions_car_outlined,
                          size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      const Text('Aucun véhicule trouvé',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('Aucun véhicule disponible',
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 13)),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final v = filtered[i];
                      return GestureDetector(
                        onTap: () => Navigator.pop(context, v),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border:
                                Border.all(color: const Color(0xFFE4E7EC)),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    Colors.black.withValues(alpha: 0.03),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      v.immatriculation,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        color: Color(0xFF1A1A2E),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      v.displayName,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

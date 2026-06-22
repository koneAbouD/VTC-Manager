import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/app_header.dart';
import '../../features/configuration_vehicule/presentation/pages/configuration_vehicule_page.dart';
import '../../features/vehicule/domain/entities/vehicule.dart';
import '../../features/vehicule/presentation/providers/vehicule_provider.dart';
import '../../features/vehicule/presentation/providers/vehicule_state.dart';

/// Page intermédiaire : sélectionner un véhicule puis ouvrir
/// [ConfigurationVehiculePage] (affectation chauffeur / condition de travail).
class ConfigurerPage extends ConsumerStatefulWidget {
  const ConfigurerPage({super.key});

  @override
  ConsumerState<ConfigurerPage> createState() => _ConfigurerPageState();
}

class _ConfigurerPageState extends ConsumerState<ConfigurerPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vehiculeNotifierProvider);

    final List<Vehicule> vehicules = switch (state) {
      VehiculeLoaded(:final vehicules) => vehicules,
      VehiculeActionSuccess(:final vehicules) => vehicules,
      _ => [],
    };

    final filtered = _query.isEmpty
        ? vehicules
        : vehicules
            .where((v) =>
                _label(v).toLowerCase().contains(_query.toLowerCase()) ||
                v.immatriculation
                    .toLowerCase()
                    .contains(_query.toLowerCase()))
            .toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const AppHeader(title: 'Configurer'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Sous-titre ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'Sélectionnez un véhicule à configurer.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ),

          // ── Barre de recherche ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Rechercher un véhicule…',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),

          // ── Liste ──────────────────────────────────────────────────────
          Expanded(
            child: state is VehiculeLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.directions_car_outlined,
                                size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            const Text(
                              'Aucun véhicule trouvé',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Ajoutez d\'abord des véhicules à la flotte.',
                              style: TextStyle(
                                  color: Colors.grey.shade500, fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) =>
                            _VehiculeTile(vehicule: filtered[i]),
                      ),
          ),
        ],
      ),
    );
  }

  static String _label(Vehicule v) =>
      v.libelle?.isNotEmpty == true
          ? v.libelle!
          : '${v.marque} ${v.modele}';
}

// ── Tuile véhicule ─────────────────────────────────────────────────────────────

class _VehiculeTile extends StatelessWidget {
  final Vehicule vehicule;
  const _VehiculeTile({required this.vehicule});

  String get _label =>
      vehicule.libelle?.isNotEmpty == true
          ? vehicule.libelle!
          : '${vehicule.marque} ${vehicule.modele}';

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        final id = vehicule.id;
        if (id == null) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ConfigurationVehiculePage(
              vehiculeId: id,
              vehiculeLabel: _label,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE4E7EC)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icône
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.directions_car_outlined,
                  color: Colors.blue.shade700, size: 22),
            ),
            const SizedBox(width: 12),
            // Infos
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _label,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Color(0xFF1A1A2E)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    vehicule.immatriculation,
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}

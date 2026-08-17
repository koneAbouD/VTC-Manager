import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/header_tabs_pills.dart';
import '../home_nav_provider.dart';

/// Onglets de la Flotte, posés dans l'en-tête de page.
///
/// La sélection transite par [fleetTabIndexProvider], seul lien entre
/// l'en-tête (HomeScreen) et le `TabBarView` (FleetScreen). L'ordre des
/// libellés suit [FleetTab].
class FleetTabsPills extends ConsumerWidget {
  const FleetTabsPills({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return HeaderTabsPills(
      labels: const ['État de parc', 'Véhicules', 'Chauffeurs'],
      index: ref.watch(fleetTabIndexProvider),
      onSelected: (i) => ref.read(fleetTabIndexProvider.notifier).state = i,
    );
  }
}

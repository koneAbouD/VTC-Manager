import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/header_tabs_pills.dart';
import '../home_nav_provider.dart';

/// Onglets du hub Finances, posés dans l'en-tête de page.
///
/// La sélection transite par [financeTabIndexProvider], seul lien entre
/// l'en-tête (HomeScreen) et le `TabBarView` (FinanceScreen). L'ordre des
/// libellés suit [FinanceTab] : les cinq onglets ne tenant pas sur la ligne
/// d'un téléphone, la rangée défile et suit l'onglet actif.
class FinanceTabsPills extends ConsumerWidget {
  const FinanceTabsPills({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return HeaderTabsPills(
      labels: const [
        'Trésorerie',
        'Créances',
        'Partenaires',
        'Opérations',
        'Rapports',
      ],
      index: ref.watch(financeTabIndexProvider),
      onSelected: (i) => ref.read(financeTabIndexProvider.notifier).state = i,
    );
  }
}

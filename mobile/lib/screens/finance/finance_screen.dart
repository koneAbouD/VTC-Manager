import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/operation_financiere/presentation/pages/operations_financieres_page.dart';
import '../../features/tresorerie/presentation/pages/creances_tab.dart';
import '../../features/tresorerie/presentation/pages/rapports_tab.dart';
import '../../features/tresorerie/presentation/pages/tresorerie_tab.dart';
import '../home_nav_provider.dart';
import 'finance_refresh.dart';

/// Index de l'onglet Finances dans la barre de navigation principale.
const _financeNavIndex = 3;

/// Hub "Finances" : Trésorerie (soldes), Créances (balance âgée),
/// Opérations (liste existante) et Rapports (rapport existant).
class FinanceScreen extends ConsumerStatefulWidget {
  const FinanceScreen({super.key});

  @override
  ConsumerState<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends ConsumerState<FinanceScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
    // Reflète la sélection manuelle de l'utilisateur dans le provider partagé.
    _tab.addListener(() {
      if (!_tab.indexIsChanging) {
        ref.read(financeTabIndexProvider.notifier).state = _tab.index;
      }
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Rafraîchit tout le module Finances à chaque entrée dans l'onglet
    // (bottom nav) : garantit des données à jour après n'importe quelle
    // opération faite ailleurs (encaissement rapide, maintenance, contravention…),
    // sans dépendre d'un appel manuel à refreshFinances sur chaque flux.
    ref.listen<int>(homeTabIndexProvider, (prev, next) {
      if (next == _financeNavIndex && prev != next) {
        refreshFinances(ref);
      }
    });

    // Permet à un autre écran (ex. « Plus d'opérations » de l'Accueil) de
    // demander l'affichage d'un sous-onglet précis.
    final requestedTab = ref.watch(financeTabIndexProvider);
    if (requestedTab != _tab.index) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _tab.index != requestedTab) {
          _tab.animateTo(requestedTab);
        }
      });
    }

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TabBar(
            controller: _tab,
            indicator: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: const Color(0xFF43A047),
            unselectedLabelColor: Colors.grey.shade600,
            labelStyle:
                const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            labelPadding: const EdgeInsets.symmetric(horizontal: 4),
            tabs: const [
              Tab(text: 'Trésorerie'),
              Tab(text: 'Créances'),
              Tab(text: 'Opérations'),
              Tab(text: 'Rapports'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: const [
              TresorerieTab(),
              CreancesTab(),
              OperationsFinancieresPage(),
              RapportsTab(),
            ],
          ),
        ),
      ],
    );
  }
}

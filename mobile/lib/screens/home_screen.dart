import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/chauffeur/presentation/providers/chauffeur_provider.dart';
import '../features/contravention/presentation/providers/contravention_provider.dart';
import '../features/maintenance/presentation/providers/maintenance_provider.dart';
import '../features/operation_financiere/presentation/providers/operation_financiere_provider.dart';
import '../features/vehicule/presentation/providers/vehicule_provider.dart';
import '../core/widgets/app_header.dart';
import 'accueil/accueil_screen.dart';
import 'finance/finance_screen.dart';
import 'home_nav_provider.dart';
import 'fleet/fleet_screen.dart';
import 'settings/settings_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static const _screens = <Widget>[
    AccueilScreen(),
    FleetScreen(),
    _PlaceholderScreen(icon: Icons.location_on_outlined, label: 'Localisation'),
    FinanceScreen(),
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadAllData);
  }

  void _loadAllData() {
    ref.read(vehiculeNotifierProvider.notifier).loadVehicules();
    ref.read(chauffeurNotifierProvider.notifier).loadChauffeurs();
    ref.read(operationFinanciereNotifierProvider.notifier).loadAll();
    ref.read(contraventionNotifierProvider.notifier).loadContraventions();
    ref.read(maintenanceNotifierProvider.notifier).loadMaintenances();
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(homeTabIndexProvider);

    // Action de l'en-tête :
    //  • Accueil → accès aux paramètres
    //  • Autres onglets → aucune action (l'export CSV de la Flotte est
    //    désormais intégré aux barres de recherche des onglets Véhicules
    //    et Chauffeurs).
    final AppHeaderAction? headerAction = currentIndex == 0
        ? AppHeaderAction(
            icon: Icons.settings_outlined,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          )
        : null;

    return Scaffold(
      appBar: AppHeader(
        title: '',
        showBack: false,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        action: headerAction,
      ),
      body: IndexedStack(
        index: currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: _FloatingNavBar(
        selectedIndex: currentIndex,
        onSelected: (i) =>
            ref.read(homeTabIndexProvider.notifier).state = i,
      ),
    );
  }
}

// ── Barre de navigation flottante personnalisée ──────────────────────────────

class _NavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  const _NavItem(this.icon, this.selectedIcon, this.label);
}

const _navItems = [
  _NavItem(Icons.home_outlined,                   Icons.home,                   'Accueil'),
  _NavItem(Icons.directions_car_outlined,          Icons.directions_car,          'Flotte'),
  _NavItem(Icons.location_on_outlined,             Icons.location_on,             'Localisation'),
  _NavItem(Icons.account_balance_wallet_outlined,  Icons.account_balance_wallet,  'Finances'),
];

class _FloatingNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _FloatingNavBar({required this.selectedIndex, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    // Android : barre ancrée pleine largeur, collée au bas, prolongée derrière
    // la barre de navigation système (edge-to-edge). iPhone : pilule flottante.
    final isAndroid = Theme.of(context).platform == TargetPlatform.android;
    return isAndroid ? _docked(context) : _floating(context);
  }

  /// Android — barre ancrée : coins droits (pas d'arrondi), ombre portée vers le
  /// haut, fond blanc qui descend jusqu'au bord de l'écran (au-dessus des
  /// boutons système grâce au padding = hauteur de la barre système).
  Widget _docked(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 20,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(8, 8, 8, 8 + bottomInset),
      child: _items(),
    );
  }

  /// iPhone — pilule flottante au-dessus de la zone sûre.
  Widget _floating(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: _items(),
        ),
      ),
    );
  }

  Widget _items() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: List.generate(_navItems.length, (i) {
        final item = _navItems[i];
        final selected = i == selectedIndex;
        return GestureDetector(
          onTap: () => onSelected(i),
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            decoration: BoxDecoration(
              color: selected
                  ? const Color(0xFF43A047).withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  selected ? item.selectedIcon : item.icon,
                  size: 22,
                  color: selected ? const Color(0xFF43A047) : Colors.grey.shade500,
                ),
                const SizedBox(height: 3),
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? const Color(0xFF43A047) : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _PlaceholderScreen extends StatelessWidget {
  final IconData icon;
  final String label;
  const _PlaceholderScreen({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(label,
              style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Text('Fonctionnalité à venir',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
        ],
      ),
    );
  }
}

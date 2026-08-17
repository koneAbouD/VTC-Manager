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
import 'finance/finance_tabs_pills.dart';
import 'home_nav_provider.dart';
import 'fleet/fleet_screen.dart';
import 'fleet/fleet_tabs_pills.dart';
import '../features/parametrage/presentation/pages/settings_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

/// Index de l'onglet Accueil dans la barre de navigation principale.
const _accueilNavIndex = 0;

/// Index des onglets dont les sous-onglets sont portés par l'en-tête.
const _flotteNavIndex = 1;
const _financesNavIndex = 3;

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

    // Bouton d'en-tête, à gauche :
    //  • Accueil → menu, qui ouvre les réglages
    //  • Autres onglets → aucune action (l'export CSV de la Flotte est
    //    désormais intégré aux barres de recherche des onglets Véhicules
    //    et Chauffeurs).
    final AppHeaderAction? headerAction = currentIndex == 0
        ? AppHeaderAction(
            icon: Icons.menu_rounded,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          )
        : null;

    // Les onglets n'ont pas de bouton retour : le retour système y ramène à
    // l'Accueil au lieu de quitter l'application. Depuis l'Accueil lui-même,
    // le geste garde son comportement normal (sortie de l'app).
    return PopScope(
      canPop: currentIndex == _accueilNavIndex,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        ref.read(homeTabIndexProvider.notifier).state = _accueilNavIndex;
      },
      child: Scaffold(
        appBar: AppHeader(
          title: '',
          showBack: false,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          leading: headerAction,
          // Flotte et Finances posent leurs sous-onglets sur la ligne de
          // l'en-tête, restée libre (ni titre ni action sur ces onglets).
          center: switch (currentIndex) {
            _flotteNavIndex => const FleetTabsPills(),
            _financesNavIndex => const FinanceTabsPills(),
            _ => null,
          },
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
    // Chaque entrée occupe un quart de la barre : sur une fenêtre étroite
    // (navigateur redimensionné), les libellés se resserrent au lieu de faire
    // déborder la rangée.
    return Row(
      children: List.generate(_navItems.length, (i) {
        final item = _navItems[i];
        final selected = i == selectedIndex;
        return Expanded(
          child: GestureDetector(
            onTap: () => onSelected(i),
            behavior: HitTestBehavior.opaque,
            // Sans fond : l'onglet actif se signale par son icône pleine, sa
            // couleur et la graisse de son libellé.
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    selected ? item.selectedIcon : item.icon,
                    size: 22,
                    color:
                        selected ? const Color(0xFF43A047) : Colors.grey.shade500,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.label,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? const Color(0xFF43A047)
                          : Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
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

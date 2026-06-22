import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/chauffeur/domain/entities/chauffeur.dart';
import '../features/chauffeur/presentation/providers/chauffeur_provider.dart';
import '../features/chauffeur/presentation/providers/chauffeur_state.dart';
import '../features/contravention/presentation/providers/contravention_provider.dart';
import '../features/maintenance/presentation/providers/maintenance_provider.dart';
import '../features/operation_financiere/presentation/providers/operation_financiere_provider.dart';
import '../features/vehicule/domain/entities/vehicule.dart';
import '../features/vehicule/presentation/providers/vehicule_provider.dart';
import '../features/vehicule/presentation/providers/vehicule_state.dart';
import '../core/utils/csv_downloader.dart';
import '../core/widgets/app_header.dart';
import 'accueil/accueil_screen.dart';
import 'fleet/fleet_filter_provider.dart';
import 'fleet/fleet_screen.dart';
import 'settings/settings_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  static const _screens = <Widget>[
    AccueilScreen(),
    FleetScreen(),
    _PlaceholderScreen(icon: Icons.location_on_outlined, label: 'Localisation'),
    _PlaceholderScreen(icon: Icons.account_balance_wallet_outlined, label: 'Finances'),
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
    final fleetTab = ref.watch(fleetActiveTabProvider);
    final onFleetExportable =
        _currentIndex == 1 && (fleetTab == 1 || fleetTab == 2);

    return Scaffold(
      appBar: AppHeader(
        title: '',
        showBack: false,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        action: AppHeaderAction(
          icon: onFleetExportable
              ? Icons.file_download_outlined
              : Icons.settings_outlined,
          onTap: onFleetExportable
              ? () => _exportCsv(fleetTab)
              : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const SettingsScreen()),
                  ),
        ),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: _FloatingNavBar(
        selectedIndex: _currentIndex,
        onSelected: (i) => setState(() => _currentIndex = i),
      ),
    );
  }

  // ── Export CSV ──────────────────────────────────────────────────────────

  Future<void> _exportCsv(int fleetTab) async {
    if (fleetTab == 1) {
      final all = switch (ref.read(vehiculeNotifierProvider)) {
        VehiculeLoaded(:final vehicules) => vehicules,
        VehiculeActionSuccess(:final vehicules) => vehicules,
        _ => <Vehicule>[],
      };
      final query =
          ref.read(vehiculeFilterQueryProvider).toLowerCase().trim();
      final statut = ref.read(vehiculeFilterStatutProvider);
      final filtered = all.where((v) {
        final matchQ = query.isEmpty ||
            v.immatriculation.toLowerCase().contains(query) ||
            v.displayName.toLowerCase().contains(query) ||
            (v.groupe?.toLowerCase().contains(query) ?? false);
        return matchQ && (statut == null || v.statut == statut);
      }).toList();
      final path = await downloadCsvFile(_vehiculesToCsv(filtered), 'vehicules.csv');
      _showExportSnack('${filtered.length} véhicule(s) exporté(s)', path: path);
    } else if (fleetTab == 2) {
      final all = switch (ref.read(chauffeurNotifierProvider)) {
        ChauffeurLoaded(:final chauffeurs) => chauffeurs,
        ChauffeurActionSuccess(:final chauffeurs) => chauffeurs,
        _ => <Chauffeur>[],
      };
      final query =
          ref.read(chauffeurFilterQueryProvider).toLowerCase().trim();
      final statut = ref.read(chauffeurFilterStatutProvider);
      final filtered = all.where((c) {
        final matchQ = query.isEmpty ||
            c.displayName.toLowerCase().contains(query) ||
            (c.telephone?.contains(query) ?? false) ||
            (c.vehiculeNom?.toLowerCase().contains(query) ?? false);
        return matchQ && (statut == null || c.statut == statut);
      }).toList();
      final path = await downloadCsvFile(_chauffeursToCsv(filtered), 'chauffeurs.csv');
      _showExportSnack('${filtered.length} chauffeur(s) exporté(s)', path: path);
    }
  }

  void _showExportSnack(String message, {String? path}) {
    if (!mounted) return;
    final detail = path != null ? '\n$path' : '';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_outline_rounded,
              color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text('$message$detail')),
        ]),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static String _vehiculesToCsv(List<Vehicule> vehicules) {
    final buf = StringBuffer()
      ..writeln(
          'Immatriculation;Marque;Modèle;Couleur;Statut;Kilométrage (km);'
          'Groupe;Type activité;Date achat;Date mise en circulation;'
          'Date entrée flotte;Date prochaine maintenance');
    for (final v in vehicules) {
      buf.writeln([
        v.immatriculation,
        v.marque,
        v.modele,
        v.couleur ?? '',
        _statutVehiculeLabel(v.statut),
        '${v.kilometrage ?? ''}',
        v.groupe ?? '',
        v.typeActiviteNom ?? '',
        _fmtDate(v.dateAchat),
        _fmtDate(v.dateMiseEnCirculation),
        _fmtDate(v.dateEntreeFlotte),
        _fmtDate(v.dateProchaineMaintenance),
      ].map(_csvEscape).join(';'));
    }
    return buf.toString();
  }

  static String _chauffeursToCsv(List<Chauffeur> chauffeurs) {
    final buf = StringBuffer()
      ..writeln('Prénom;Nom;Téléphone;Email;Statut;Type;'
          'Véhicule assigné;Matricule;Date embauche');
    for (final c in chauffeurs) {
      buf.writeln([
        c.prenom,
        c.nom,
        c.telephone ?? '',
        c.email ?? '',
        c.statut?.label ?? '',
        c.type?.label ?? '',
        c.vehiculeNom ?? '',
        c.vehiculeMatricule ?? '',
        _fmtDate(c.dateEmbauche),
      ].map(_csvEscape).join(';'));
    }
    return buf.toString();
  }

  static String _statutVehiculeLabel(String? s) => switch (s) {
        'DISPONIBLE' => 'Disponible',
        'EN_SERVICE' => 'En service',
        'EN_MAINTENANCE' => 'En maintenance',
        'HORS_SERVICE' => 'Hors service',
        _ => s ?? '',
      };

  static String _fmtDate(DateTime? d) {
    if (d == null) return '';
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  static String _csvEscape(String v) {
    if (v.contains(';') || v.contains('"') || v.contains('\n')) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
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
          child: Row(
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
                        ? Colors.indigo.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        selected ? item.selectedIcon : item.icon,
                        size: 22,
                        color: selected ? Colors.indigo : Colors.grey.shade500,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected ? Colors.indigo : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
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

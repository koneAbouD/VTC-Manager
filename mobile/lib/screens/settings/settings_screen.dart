import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/operation_financiere/presentation/providers/operation_financiere_provider.dart';
import '../../features/vehicule/presentation/providers/referentiel_provider.dart';
import '../../features/vehicule/presentation/providers/vehicule_provider.dart';
import '../../features/chauffeur/presentation/providers/chauffeur_provider.dart';
import '../../features/maintenance/presentation/providers/maintenance_provider.dart';
import '../../features/recette/presentation/providers/ligne_recette_provider.dart';
import '../../features/cotisation/presentation/providers/ligne_cotisation_provider.dart';
import '../../features/penalite/presentation/providers/penalite_provider.dart';
import '../../features/jour_ferie/presentation/jours_feries_page.dart';
import '../../core/widgets/app_header.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: const AppHeader(title: 'Paramètres'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _MenuSection(
            title: 'Compte',
            items: [
              _MenuItem(
                icon: Icons.person_outline,
                label: 'Mon profil',
                onTap: () {},
              ),
              _MenuItem(
                icon: Icons.notifications_outlined,
                label: 'Notifications',
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '7',
                    style: TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: 24),
          _MenuSection(
            title: 'Application',
            items: [
              _MenuItem(
                icon: Icons.refresh,
                label: 'Rafraîchir les données',
                onTap: () => _refreshData(context, ref),
              ),
              _MenuItem(
                icon: Icons.info_outline,
                label: 'À propos',
                onTap: () => _showAboutDialog(context),
              ),
              _MenuItem(
                icon: Icons.settings_outlined,
                label: 'Paramètres',
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: 24),
          _MenuSection(
            title: 'Configuration',
            items: [
              _MenuItem(
                icon: Icons.flag_outlined,
                label: 'Jours fériés',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const JoursFeriesPage()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _MenuSection(
            title: 'Autre',
            items: [
              _MenuItem(
                icon: Icons.help_outline,
                label: 'Aide & Support',
                onTap: () {},
              ),
              _MenuItem(
                icon: Icons.logout,
                label: 'Déconnexion',
                labelColor: Colors.red,
                iconColor: Colors.red,
                onTap: () {
                  Navigator.pop(context);
                  ref.read(authNotifierProvider.notifier).logout();
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Version 1.0.0',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  /// Recharge les données de l'application depuis le serveur :
  /// - Accueil (opérations / solde) ;
  /// - listes métier : véhicules, chauffeurs, maintenances, recettes,
  ///   cotisations, pénalités (rechargement des notifiers partagés) ;
  /// - référentiels en cache (types véhicule/activité, groupes, statuts).
  void _refreshData(BuildContext context, WidgetRef ref) {
    // Accueil
    ref.read(operationFinanciereNotifierProvider.notifier).loadAll();

    // Listes métier (notifiers partagés → rechargement sûr, pas d'écran blanc).
    ref.read(vehiculeNotifierProvider.notifier).loadVehicules();
    ref.read(chauffeurNotifierProvider.notifier).loadChauffeurs();
    ref.read(maintenanceNotifierProvider.notifier).loadMaintenances();
    ref.read(ligneRecetteNotifierProvider.notifier).load();
    ref.read(ligneCotisationNotifierProvider.notifier).load();
    ref.read(lignePenaliteNotifierProvider.notifier).load();

    // Référentiels (FutureProviders en cache → invalidation = refetch).
    ref.invalidate(typesVehiculesProvider);
    ref.invalidate(typesActivitesProvider);
    ref.invalidate(groupesProvider);
    ref.invalidate(statutsVehiculeProvider);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Données rafraîchies')),
      );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('À propos'),
        content: const Text(
          'DJULATCHE - Gestion de flotte VTC\n\nVersion 1.0.0\n\n© 2026 DJULATCHE',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }
}

class _MenuSection extends StatelessWidget {
  final String title;
  final List<_MenuItem> items;

  const _MenuSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: items
                .map((item) => Column(
                      children: [
                        item,
                        if (item != items.last)
                          Divider(
                            height: 1,
                            indent: 56,
                            endIndent: 16,
                            color: Colors.grey.shade200,
                          ),
                      ],
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget? trailing;
  final VoidCallback onTap;
  final Color? labelColor;
  final Color? iconColor;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
    this.labelColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (iconColor ?? const Color(0xFF3B5BDB)).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: iconColor ?? const Color(0xFF3B5BDB),
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: labelColor ?? const Color(0xFF1A1A2E),
                ),
              ),
            ),
            if (trailing != null) trailing!,
            Icon(
              Icons.chevron_right,
              color: Colors.grey.shade400,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

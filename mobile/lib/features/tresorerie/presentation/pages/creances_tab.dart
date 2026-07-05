import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/creance.dart';
import '../providers/tresorerie_providers.dart';
import 'creances_chauffeur_page.dart';
import 'creances_vehicule_page.dart';

/// Onglet Créances : balance âgée (qui doit quoi, depuis quand), au choix
/// **par chauffeur** ou **par véhicule** via le sélecteur intégré à la carte
/// « Total dû ».
class CreancesTab extends ConsumerStatefulWidget {
  const CreancesTab({super.key});

  @override
  ConsumerState<CreancesTab> createState() => _CreancesTabState();
}

class _CreancesTabState extends ConsumerState<CreancesTab> {
  /// false = par chauffeur, true = par véhicule.
  bool _parVehicule = false;

  void _toggle() => setState(() => _parVehicule = !_parVehicule);

  @override
  Widget build(BuildContext context) {
    // Le sélecteur chauffeur/véhicule est intégré à la carte rouge « Total dû »
    // de chaque vue (voir _TotalDuCard).
    return _parVehicule
        ? _VehiculesView(parVehicule: _parVehicule, onToggle: _toggle)
        : _ChauffeursView(parVehicule: _parVehicule, onToggle: _toggle);
  }
}

// ── Vue par chauffeur ─────────────────────────────────────────────────────────

class _ChauffeursView extends ConsumerWidget {
  final bool parVehicule;
  final VoidCallback onToggle;
  const _ChauffeursView({required this.parVehicule, required this.onToggle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncBalance = ref.watch(balanceAgeeProvider);

    return RefreshIndicator(
      onRefresh: () => ref.refresh(balanceAgeeProvider.future),
      child: asyncBalance.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            _ErrorList(onRetry: () => ref.invalidate(balanceAgeeProvider)),
        data: (creances) {
          if (creances.isEmpty) return const _EmptyList();

          final total = creances.fold<double>(0, (s, c) => s + c.total);
          final totalPlus30 =
              creances.fold<double>(0, (s, c) => s + c.duPlus30Jours);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            children: [
              _TotalDuCard(
                  label: 'Total dû par les chauffeurs',
                  total: total,
                  totalPlus30: totalPlus30,
                  parVehicule: parVehicule,
                  onToggle: onToggle),
              const SizedBox(height: 8),
              for (final creance in creances)
                _CreanceChauffeurTile(
                  creance: creance,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CreancesChauffeurPage(
                        chauffeurId: creance.chauffeurId,
                        chauffeurNom: creance.displayName,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ── Vue par véhicule ──────────────────────────────────────────────────────────

class _VehiculesView extends ConsumerWidget {
  final bool parVehicule;
  final VoidCallback onToggle;
  const _VehiculesView({required this.parVehicule, required this.onToggle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncBalance = ref.watch(balanceAgeeVehiculeProvider);

    return RefreshIndicator(
      onRefresh: () => ref.refresh(balanceAgeeVehiculeProvider.future),
      child: asyncBalance.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorList(
            onRetry: () => ref.invalidate(balanceAgeeVehiculeProvider)),
        data: (creances) {
          if (creances.isEmpty) return const _EmptyList();

          final total = creances.fold<double>(0, (s, c) => s + c.total);
          final totalPlus30 =
              creances.fold<double>(0, (s, c) => s + c.duPlus30Jours);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            children: [
              _TotalDuCard(
                  label: 'Total dû rattaché aux véhicules',
                  total: total,
                  totalPlus30: totalPlus30,
                  parVehicule: parVehicule,
                  onToggle: onToggle),
              const SizedBox(height: 8),
              for (final creance in creances)
                _CreanceVehiculeTile(
                  creance: creance,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CreancesVehiculePage(
                        vehiculeId: creance.vehiculeId,
                        vehiculeNom: creance.displayName,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ── Vues d'état partagées ──────────────────────────────────────────────────────

class _EmptyList extends StatelessWidget {
  const _EmptyList();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 120),
        Icon(Icons.check_circle_outline_rounded,
            size: 56, color: Colors.green.shade200),
        const SizedBox(height: 12),
        Center(
          child: Text('Aucune créance en cours',
              style: TextStyle(fontSize: 15, color: Colors.grey.shade600)),
        ),
      ],
    );
  }
}

class _ErrorList extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorList({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 120),
        Center(
            child: Text('Impossible de charger les créances',
                style: TextStyle(color: Colors.grey.shade600))),
        Center(
          child: TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Réessayer'),
          ),
        ),
      ],
    );
  }
}

class _TotalDuCard extends StatelessWidget {
  final String label;
  final double total;
  final double totalPlus30;
  final bool parVehicule;
  final VoidCallback onToggle;
  const _TotalDuCard(
      {required this.label,
      required this.total,
      required this.totalPlus30,
      required this.parVehicule,
      required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEA),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Libellé + sélecteur chauffeur/véhicule intégré (bascule au tap).
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(label,
                      style: TextStyle(
                          fontSize: 13, color: Colors.red.shade900)),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: onToggle,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.only(
                      left: 12, right: 6, top: 6, bottom: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(parVehicule ? 'Par véhicule' : 'Par chauffeur',
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.red.shade900)),
                      Icon(Icons.arrow_drop_down,
                          size: 18, color: Colors.red.shade900),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            CurrencyFormatter.format(total),
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.red.shade900),
          ),
          if (totalPlus30 > 0) ...[
            const SizedBox(height: 4),
            Text(
              'dont ${CurrencyFormatter.format(totalPlus30)} à plus de 30 jours',
              style: TextStyle(fontSize: 12, color: Colors.red.shade800),
            ),
          ],
        ],
      ),
    );
  }
}

class _CreanceChauffeurTile extends StatelessWidget {
  final CreanceChauffeur creance;
  final VoidCallback onTap;
  const _CreanceChauffeurTile({required this.creance, required this.onTap});

  String get _initials {
    final p = creance.prenom.isNotEmpty ? creance.prenom[0] : '';
    final n = creance.nom.isNotEmpty ? creance.nom[0] : '';
    final ini = '$p$n'.toUpperCase();
    return ini.isEmpty ? '?' : ini;
  }

  @override
  Widget build(BuildContext context) {
    return _CreanceRow(
      leading: CircleAvatar(
        radius: 19,
        backgroundColor: AppColors.primaryTint,
        child: Text(_initials,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark)),
      ),
      title: creance.displayName,
      subtitle:
          '${creance.nbLignes} ligne${creance.nbLignes > 1 ? 's' : ''} due${creance.nbLignes > 1 ? 's' : ''}',
      total: creance.total,
      tranche: creance.trancheDominante,
      onTap: onTap,
    );
  }
}

class _CreanceVehiculeTile extends StatelessWidget {
  final CreanceVehicule creance;
  final VoidCallback onTap;
  const _CreanceVehiculeTile({required this.creance, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _CreanceRow(
      leading: const CircleAvatar(
        radius: 19,
        backgroundColor: AppColors.primaryTint,
        child: Icon(Icons.directions_car_rounded,
            size: 18, color: AppColors.primaryDark),
      ),
      title: creance.displayName,
      subtitle:
          '${creance.nbLignes} ligne${creance.nbLignes > 1 ? 's' : ''} due${creance.nbLignes > 1 ? 's' : ''}',
      total: creance.total,
      tranche: creance.trancheDominante,
      onTap: onTap,
    );
  }
}

/// Ligne générique de balance âgée (chauffeur ou véhicule).
class _CreanceRow extends StatelessWidget {
  final Widget leading;
  final String title;
  final String subtitle;
  final double total;
  final TrancheAge tranche;
  final VoidCallback onTap;
  const _CreanceRow({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.total,
    required this.tranche,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: const BoxDecoration(
          border:
              Border(bottom: BorderSide(color: AppColors.border, width: 0.6)),
        ),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.dark)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.label)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(CurrencyFormatter.format(total),
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.dark)),
                const SizedBox(height: 3),
                _TrancheBadge(tranche),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TrancheBadge extends StatelessWidget {
  final TrancheAge tranche;
  const _TrancheBadge(this.tranche);

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tranche) {
      TrancheAge.plus30 => (const Color(0xFFFDECEA), Colors.red.shade900),
      TrancheAge.de8a30 => (const Color(0xFFFFF3E0), Colors.orange.shade900),
      TrancheAge.de0a7 => (AppColors.headerButton, AppColors.label),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(tranche.label,
          style: TextStyle(
              fontSize: 10.5, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

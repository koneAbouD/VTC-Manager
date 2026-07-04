import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/creance.dart';
import '../providers/tresorerie_providers.dart';
import 'creances_chauffeur_page.dart';

/// Onglet Créances : balance âgée par chauffeur (qui doit quoi, depuis quand).
class CreancesTab extends ConsumerWidget {
  const CreancesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncBalance = ref.watch(balanceAgeeProvider);

    return RefreshIndicator(
      onRefresh: () => ref.refresh(balanceAgeeProvider.future),
      child: asyncBalance.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(
          children: [
            const SizedBox(height: 120),
            Center(
                child: Text('Impossible de charger les créances',
                    style: TextStyle(color: Colors.grey.shade600))),
            Center(
              child: TextButton.icon(
                onPressed: () => ref.invalidate(balanceAgeeProvider),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Réessayer'),
              ),
            ),
          ],
        ),
        data: (creances) {
          if (creances.isEmpty) {
            return ListView(
              children: [
                const SizedBox(height: 120),
                Icon(Icons.check_circle_outline_rounded,
                    size: 56, color: Colors.green.shade200),
                const SizedBox(height: 12),
                Center(
                  child: Text('Aucune créance en cours',
                      style: TextStyle(
                          fontSize: 15, color: Colors.grey.shade600)),
                ),
              ],
            );
          }

          final total = creances.fold<double>(0, (s, c) => s + c.total);
          final totalPlus30 =
              creances.fold<double>(0, (s, c) => s + c.duPlus30Jours);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            children: [
              _TotalDuCard(total: total, totalPlus30: totalPlus30),
              const SizedBox(height: 8),
              for (final creance in creances)
                _CreanceTile(
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

class _TotalDuCard extends StatelessWidget {
  final double total;
  final double totalPlus30;
  const _TotalDuCard({required this.total, required this.totalPlus30});

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
          Text('Total dû par les chauffeurs',
              style: TextStyle(fontSize: 13, color: Colors.red.shade900)),
          const SizedBox(height: 4),
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

class _CreanceTile extends StatelessWidget {
  final CreanceChauffeur creance;
  final VoidCallback onTap;
  const _CreanceTile({required this.creance, required this.onTap});

  String get _initials {
    final p = creance.prenom.isNotEmpty ? creance.prenom[0] : '';
    final n = creance.nom.isNotEmpty ? creance.nom[0] : '';
    final ini = '$p$n'.toUpperCase();
    return ini.isEmpty ? '?' : ini;
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: const BoxDecoration(
          border: Border(
              bottom: BorderSide(color: AppColors.border, width: 0.6)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 19,
              backgroundColor: AppColors.primaryTint,
              child: Text(_initials,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDark)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(creance.displayName,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.dark)),
                  const SizedBox(height: 2),
                  Text(
                    '${creance.nbLignes} ligne${creance.nbLignes > 1 ? 's' : ''} due${creance.nbLignes > 1 ? 's' : ''}',
                    style:
                        const TextStyle(fontSize: 12, color: AppColors.label),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(CurrencyFormatter.format(creance.total),
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.dark)),
                const SizedBox(height: 3),
                _TrancheBadge(creance.trancheDominante),
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

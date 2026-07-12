import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../providers/tresorerie_providers.dart';
import 'arrete_detail_page.dart';
import 'arretes_history_page.dart' show fmtDate;

/// Relevé de compte d'un chauffeur : tous ses arrêtés (multi-périodes).
class ReleveChauffeurPage extends ConsumerWidget {
  final int chauffeurId;
  final String nom;
  const ReleveChauffeurPage(
      {super.key, required this.chauffeurId, required this.nom});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(releveChauffeurProvider(chauffeurId));
    return Scaffold(
      appBar: AppBar(title: Text('Relevé — $nom')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(releveChauffeurProvider(chauffeurId).future),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [
            const SizedBox(height: 120),
            Center(
                child: Text('Impossible de charger le relevé',
                    style: TextStyle(color: Colors.grey.shade600))),
          ]),
          data: (arretes) {
            if (arretes.isEmpty) {
              return ListView(children: [
                const SizedBox(height: 120),
                Center(
                    child: Text('Aucun arrêté pour ce chauffeur',
                        style:
                            TextStyle(fontSize: 15, color: Colors.grey.shade600))),
              ]);
            }
            final totalRestitue = arretes
                .where((a) => !a.estAnnule)
                .fold<double>(0, (s, a) {
              final r = a.reglements
                  .where((r) => r.chauffeurId == chauffeurId)
                  .fold<double>(0, (s2, r) => s2 + r.montantNet);
              return s + r;
            });
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: AppColors.primaryTint,
                      borderRadius: BorderRadius.circular(14)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total restitué (${arretes.length} arrêté${arretes.length > 1 ? 's' : ''})',
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.primaryDark)),
                      const SizedBox(height: 4),
                      Text(CurrencyFormatter.format(totalRestitue),
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryDark)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                for (final a in arretes)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(a.reference ?? 'Arrêté #${a.id}',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            decoration:
                                a.estAnnule ? TextDecoration.lineThrough : null,
                            color: AppColors.dark)),
                    subtitle: Text(
                        '${fmtDate(a.periodeDebut)} → ${fmtDate(a.periodeFin)}',
                        style: const TextStyle(fontSize: 12, color: AppColors.label)),
                    trailing: Text(
                        CurrencyFormatter.format(a.reglements
                            .where((r) => r.chauffeurId == chauffeurId)
                            .fold<double>(0, (s, r) => s + r.montantNet)),
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.green.shade800)),
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => ArreteDetailPage(id: a.id!))),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

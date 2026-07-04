import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/csv_downloader.dart';
import '../../../../core/widgets/month_filter_pill.dart';
import '../../../../screens/finance/rapport_financier_page.dart';
import '../providers/tresorerie_providers.dart';
import 'bilan_page.dart';
import 'compte_resultat_page.dart';

/// Onglet Rapports : point d'entrée vers les états financiers.
class RapportsTab extends ConsumerWidget {
  const RapportsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        _RapportCard(
          icone: Icons.bar_chart_rounded,
          titre: 'Rapport financier',
          description: 'Revenus et dépenses du mois, par chauffeur ou véhicule',
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const RapportFinancierPage())),
        ),
        _RapportCard(
          icone: Icons.stacked_line_chart_rounded,
          titre: 'Compte de résultat',
          description:
              'Cascade produits → charges → résultat, base caisse ou engagement, marge par véhicule',
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const CompteResultatPage())),
        ),
        _RapportCard(
          icone: Icons.account_balance_outlined,
          titre: 'Situation (bilan de gestion)',
          description:
              'Trésorerie, créances, valeur de la flotte, situation nette',
          onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const BilanPage())),
        ),
        _RapportCard(
          icone: Icons.file_download_outlined,
          titre: 'Export comptable',
          description:
              'Journal CSV du mois pour le cabinet (plan comptable SYSCOHADA)',
          onTap: () => _exporter(context, ref),
        ),
        _RapportCard(
          icone: Icons.lock_clock_rounded,
          titre: 'Clôture mensuelle',
          description:
              'Fige une période : plus aucune écriture ni annulation possible',
          onTap: () => _ouvrirClotures(context, ref),
        ),
      ],
    );
  }

  // ── Export comptable ──────────────────────────────────────────────────────

  Future<void> _exporter(BuildContext context, WidgetRef ref) async {
    final periode = await _choisirPeriode(context,
        titre: 'Exporter quel mois ?', action: 'Exporter');
    if (periode == null || !context.mounted) return;

    try {
      final csv = await ref.read(tresorerieDatasourceProvider).getExportComptable(
          annee: periode.$1, mois: periode.$2);
      final nom =
          'journal_${periode.$1}_${periode.$2.toString().padLeft(2, '0')}.csv';
      final path = await downloadCsvFile(csv, nom);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Journal exporté${path != null ? '\n$path' : ''}')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Échec de l\'export : $e')));
      }
    }
  }

  // ── Clôture mensuelle ─────────────────────────────────────────────────────

  Future<void> _ouvrirClotures(BuildContext context, WidgetRef ref) async {
    final periode = await _choisirPeriode(context,
        titre: 'Clôturer quel mois ?',
        action: 'Clôturer',
        avertissement:
            'Une période clôturée ne peut plus recevoir d\'écriture ni '
            'd\'annulation. Cette action est définitive.');
    if (periode == null || !context.mounted) return;

    try {
      await ref
          .read(tresorerieDatasourceProvider)
          .cloturerPeriode(annee: periode.$1, mois: periode.$2);
      ref.invalidate(cloturesPeriodeProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text('Période ${periode.$2}/${periode.$1} clôturée')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Clôture refusée : $e')));
      }
    }
  }

  /// Sélecteur (année, mois) — le mois précédent par défaut.
  Future<(int, int)?> _choisirPeriode(BuildContext context,
      {required String titre,
      required String action,
      String? avertissement}) async {
    final precedent = DateTime(DateTime.now().year, DateTime.now().month - 1);
    var annee = precedent.year;
    var mois = precedent.month;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(titre,
              style:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MonthFilterPill(
                mois: mois,
                annee: annee,
                onChanged: (m, a) => setState(() {
                  mois = m;
                  annee = a;
                }),
              ),
              if (avertissement != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(avertissement,
                      style: TextStyle(
                          fontSize: 12, color: Colors.orange.shade900)),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annuler')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true), child: Text(action)),
          ],
        ),
      ),
    );
    return ok == true ? (annee, mois) : null;
  }
}

class _RapportCard extends StatelessWidget {
  final IconData icone;
  final String titre;
  final String description;
  final VoidCallback onTap;

  const _RapportCard({
    required this.icone,
    required this.titre,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.8),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primaryTint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icone, size: 21, color: AppColors.primaryDark),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titre,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.dark)),
                    const SizedBox(height: 2),
                    Text(description,
                        style: const TextStyle(
                            fontSize: 11.5, color: AppColors.label)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  size: 20, color: AppColors.hint),
            ],
          ),
        ),
      ),
    );
  }
}

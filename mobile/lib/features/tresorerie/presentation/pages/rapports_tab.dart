import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/csv_downloader.dart';
import '../../../../core/widgets/month_filter_pill.dart';
import '../../../../screens/finance/rapport_financier_page.dart';
import '../providers/tresorerie_providers.dart';
import 'bilan_page.dart';
import 'compte_resultat_page.dart';
import 'comptes_courants_page.dart';

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
          icone: Icons.gavel_outlined,
          titre: 'Restitution des cotisations',
          description:
              'Compte courant chauffeur/véhicule : arrêté de compte et versement du net',
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const ComptesCourantsPage())),
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
        titre: 'Exporter quel mois ?',
        action: 'Exporter',
        icone: Icons.file_download_outlined);
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
        icone: Icons.lock_clock_rounded,
        accent: AppColors.warning,
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

  /// Sélecteur (année, mois) premium — le mois précédent par défaut. L'accent
  /// (icône + bouton + bandeau) est paramétrable : primaire pour l'export,
  /// `warning` pour une action définitive comme la clôture.
  Future<(int, int)?> _choisirPeriode(BuildContext context,
      {required String titre,
      required String action,
      IconData icone = Icons.calendar_month_rounded,
      Color accent = AppColors.primary,
      String? avertissement}) async {
    final precedent = DateTime(DateTime.now().year, DateTime.now().month - 1);
    var annee = precedent.year;
    var mois = precedent.month;

    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Dialog(
          backgroundColor: AppColors.surface,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Icône dans une pastille teintée à l'accent.
                Center(
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icone, size: 28, color: accent),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  titre,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.dark,
                      letterSpacing: -0.4),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choisissez le mois à ${action.toLowerCase()}.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 13.5, height: 1.4, color: AppColors.label),
                ),
                const SizedBox(height: 18),
                MonthFilterPill(
                  mois: mois,
                  annee: annee,
                  onChanged: (m, a) => setState(() {
                    mois = m;
                    annee = a;
                  }),
                ),
                if (avertissement != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 11),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                      border:
                          Border.all(color: accent.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            size: 18, color: accent),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(avertissement,
                              style: TextStyle(
                                  fontSize: 12.5,
                                  height: 1.35,
                                  fontWeight: FontWeight.w500,
                                  color: accent)),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.label,
                            side: const BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text('Annuler',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: FilledButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text(action,
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
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

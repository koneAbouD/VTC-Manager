import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/compte_tresorerie.dart';
import '../providers/tresorerie_providers.dart';
import '../widgets/tresorerie_dialogs.dart';
import 'comptes_courants_page.dart';

/// Onglet Trésorerie : total et disponible réel (dépôts cotisations et « à
/// reverser à l'État » retranchés), alerte de couverture, soldes par compte.
class TresorerieTab extends ConsumerWidget {
  const TresorerieTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSummary = ref.watch(tresorerieSummaryProvider);

    return RefreshIndicator(
      onRefresh: () => ref.refresh(tresorerieSummaryProvider.future),
      child: asyncSummary.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorRetry(
          message: 'Impossible de charger la trésorerie',
          onRetry: () => ref.invalidate(tresorerieSummaryProvider),
        ),
        data: (summary) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            _TotalCard(summary: summary),
            if (summary.couvertureInsuffisante) ...[
              const SizedBox(height: 10),
              _CouvertureBandeau(manque: -summary.disponibleReel),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => showTransfertDialog(
                        context, ref, summary.comptes),
                    icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                    label: const Text('Transfert'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => showClotureCaisseDialog(
                      context,
                      ref,
                      [
                        for (final c in summary.comptes)
                          CompteAvecSoldeVue(
                              id: c.id, libelle: c.libelle, solde: c.solde),
                      ],
                    ),
                    icon: const Icon(Icons.lock_outline_rounded, size: 18),
                    label: const Text('Clôturer la caisse'),
                  ),
                ),
              ],
            ),
            _EcartsBandeau(
              comptes: [
                for (final c in summary.comptes)
                  CompteAvecSoldeVue(
                      id: c.id, libelle: c.libelle, solde: c.solde),
              ],
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.55,
              children: [
                for (final compte in summary.comptes) _CompteCard(compte),
              ],
            ),
            if (summary.comptes.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 32),
                child: Center(
                  child: Text('Aucun compte de trésorerie configuré',
                      style: TextStyle(color: Colors.grey.shade500)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Total des comptes, puis ce qui n'appartient pas à l'entreprise : les dépôts
/// de cotisations à rendre aux chauffeurs et les contraventions à reverser à
/// l'État. Le disponible réel en découle — c'est lui qu'il faut regarder avant
/// une dépense, pas le total.
class _TotalCard extends StatelessWidget {
  final TresorerieSummary summary;
  const _TotalCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final total = summary.totalTresorerie;
    final detail = summary.depotsCotisations > 0 || summary.aReverserEtat > 0;
    final disponible = summary.disponibleReel;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Total trésorerie',
              style: TextStyle(fontSize: 13, color: AppColors.label)),
          const SizedBox(height: 6),
          Text(
            CurrencyFormatter.format(total),
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: total < 0 ? AppColors.error : AppColors.dark,
            ),
          ),
          if (detail) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 4),
            if (summary.depotsCotisations > 0)
              _LigneRetenue(
                icone: Icons.analytics_outlined,
                libelle: 'Dépôts cotisations à rendre',
                montant: summary.depotsCotisations,
                // Le détail par chauffeur / véhicule est dans les comptes
                // courants : c'est de là que partent les arrêtés.
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ComptesCourantsPage()),
                ),
              ),
            if (summary.aReverserEtat > 0)
              _LigneRetenue(
                icone: Icons.account_balance_outlined,
                libelle: "À reverser à l'État (contraventions)",
                montant: summary.aReverserEtat,
              ),
            const SizedBox(height: 4),
            Row(children: [
              const Expanded(
                child: Text('Disponible réel',
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.dark)),
              ),
              Text(
                CurrencyFormatter.format(disponible),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: disponible < 0 ? AppColors.error : AppColors.primaryDark,
                ),
              ),
            ]),
          ],
        ],
      ),
    );
  }
}

/// Montant retranché du total : ce que la trésorerie détient sans le posséder.
class _LigneRetenue extends StatelessWidget {
  final IconData icone;
  final String libelle;
  final double montant;
  final VoidCallback? onTap;

  const _LigneRetenue({
    required this.icone,
    required this.libelle,
    required this.montant,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          Icon(icone, size: 16, color: AppColors.label),
          const SizedBox(width: 8),
          Expanded(
            child: Text(libelle,
                style: const TextStyle(fontSize: 12.5, color: AppColors.label)),
          ),
          Text('− ${CurrencyFormatter.format(montant)}',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.dark)),
          if (onTap != null) ...[
            const SizedBox(width: 2),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: AppColors.hint),
          ],
        ]),
      ),
    );
  }
}

/// Alerte : la trésorerie ne suffit plus à rendre ce qu'elle détient pour les
/// chauffeurs et l'État. Un arrêté important échouerait alors au versement
/// (une caisse ne passe pas en négatif), et toute dépense aggrave le trou.
class _CouvertureBandeau extends StatelessWidget {
  final double manque;
  const _CouvertureBandeau({required this.manque});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 20, color: AppColors.error),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'La trésorerie ne couvre pas les dépôts des chauffeurs',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.error),
                ),
                const SizedBox(height: 2),
                Text(
                  'Il manque ${CurrencyFormatter.format(manque)} pour rendre les '
                  "cotisations et reverser l'État. Évitez toute dépense non "
                  'urgente avant le prochain arrêté.',
                  style: const TextStyle(
                      fontSize: 11.5, height: 1.3, color: AppColors.dark),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Écarts de caisse restés sans décision.
///
/// N'apparaît que s'il y en a : le reste du temps, il n'y a rien à faire et
/// rien à montrer. Sa présence est la seule façon d'apprendre qu'un mois refuse
/// d'être clôturé — le refus, lui, ne se lit qu'au moment où l'on essaie, dans
/// un autre onglet.
class _EcartsBandeau extends ConsumerWidget {
  final List<CompteAvecSoldeVue> comptes;
  const _EcartsBandeau({required this.comptes});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ecarts = ref.watch(ecartsEnAttenteProvider).valueOrNull ?? const [];
    if (ecarts.isEmpty) return const SizedBox.shrink();

    final pluriel = ecarts.length > 1;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: InkWell(
        onTap: () => showEcartsCaisseDialog(context, ref, comptes),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.warning.withValues(alpha: 0.30)),
          ),
          child: Row(
            children: [
              const Icon(Icons.balance_rounded,
                  size: 20, color: AppColors.warning),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pluriel
                          ? '${ecarts.length} écarts de caisse à trancher'
                          : 'Un écart de caisse à trancher',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.dark),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      pluriel
                          ? 'Tant qu\'ils attendent, les mois où ils tombent ne '
                              'peuvent pas être clôturés'
                          : 'Tant qu\'il attend, le mois où il tombe ne peut pas '
                              'être clôturé',
                      style: const TextStyle(
                          fontSize: 11.5, height: 1.3, color: AppColors.label),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded,
                  size: 20, color: AppColors.hint),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompteCard extends StatelessWidget {
  final CompteTresorerie compte;
  const _CompteCard(this.compte);

  IconData get _icon => switch (compte.type) {
        'CAISSE' => Icons.payments_outlined,
        'MOBILE_MONEY' => Icons.phone_iphone_rounded,
        'BANQUE' => Icons.account_balance_outlined,
        _ => Icons.wallet_outlined,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(_icon, size: 16, color: AppColors.label),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  compte.libelle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppColors.label),
                ),
              ),
            ],
          ),
          Text(
            CurrencyFormatter.format(compte.solde),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: compte.solde < 0 ? AppColors.error : AppColors.dark,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorRetry({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    // ListView : garde le pull-to-refresh actif même en erreur.
    return ListView(
      children: [
        const SizedBox(height: 120),
        Center(child: Text(message, style: TextStyle(color: Colors.grey.shade600))),
        const SizedBox(height: 12),
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

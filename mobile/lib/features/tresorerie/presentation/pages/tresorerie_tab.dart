import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/compte_tresorerie.dart';
import '../providers/tresorerie_providers.dart';
import '../widgets/tresorerie_dialogs.dart';

/// Onglet Trésorerie : total, encart "à reverser à l'État", soldes par compte.
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
            _TotalCard(total: summary.totalTresorerie),
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
            if (summary.aReverserEtat > 0) ...[
              const SizedBox(height: 12),
              _AReverserCard(montant: summary.aReverserEtat),
            ],
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

class _TotalCard extends StatelessWidget {
  final double total;
  const _TotalCard({required this.total});

  @override
  Widget build(BuildContext context) {
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

class _AReverserCard extends StatelessWidget {
  final double montant;
  const _AReverserCard({required this.montant});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_balance_outlined,
              size: 20, color: Color(0xFFE65100)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'À reverser à l\'État (contraventions)',
              style: TextStyle(
                  fontSize: 13,
                  color: Colors.orange.shade900,
                  fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            CurrencyFormatter.format(montant),
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.orange.shade900),
          ),
        ],
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

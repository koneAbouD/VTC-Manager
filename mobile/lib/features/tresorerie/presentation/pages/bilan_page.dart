import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/app_header.dart';
import '../providers/tresorerie_providers.dart';

/// Situation patrimoniale (bilan de gestion) : photo des stocks à aujourd'hui.
class BilanPage extends ConsumerWidget {
  const BilanPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncBilan = ref.watch(bilanProvider);

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: const AppHeader(title: 'Situation'),
      body: asyncBilan.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Impossible de charger la situation',
                  style: TextStyle(color: Colors.grey.shade600)),
              TextButton.icon(
                onPressed: () => ref.invalidate(bilanProvider),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
        data: (bilan) => RefreshIndicator(
          onRefresh: () => ref.refresh(bilanProvider.future),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Text(
                'Au ${DateFormat('dd/MM/yyyy').format(bilan.date)}',
                style: const TextStyle(fontSize: 12, color: AppColors.label),
              ),
              const SizedBox(height: 10),
              _Section(
                titre: 'Actif — ce que l\'entreprise possède',
                lignes: [
                  ('Trésorerie', bilan.tresorerie, 'Soldes des comptes actifs'),
                  ('Créances chauffeurs', bilan.creancesChauffeurs,
                      'Recettes, cotisations, pénalités, contraventions dues'),
                  ('Immobilisations nettes', bilan.immobilisationsNettes,
                      'Véhicules : prix d\'achat − amortissement couru'),
                ],
                total: ('Total actif', bilan.totalActif),
              ),
              const SizedBox(height: 12),
              _Section(
                titre: 'Passif — ce que l\'entreprise doit',
                lignes: [
                  ('Dette État (contraventions)', bilan.detteEtatContraventions,
                      'Encaissé auprès des chauffeurs, non reversé'),
                ],
                total: null,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: bilan.situationNette >= 0
                      ? AppColors.primaryTint
                      : const Color(0xFFFDECEA),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Situation nette',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: bilan.situationNette >= 0
                                ? AppColors.primaryDark
                                : Colors.red.shade900)),
                    Text(CurrencyFormatter.format(bilan.situationNette),
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: bilan.situationNette >= 0
                                ? AppColors.primaryDark
                                : Colors.red.shade900)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Bilan de gestion dérivé des données de l\'application — '
                'le bilan comptable officiel reste établi par votre cabinet '
                'à partir de l\'export.',
                style: TextStyle(fontSize: 11, color: AppColors.hint),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String titre;
  final List<(String, double, String)> lignes;
  final (String, double)? total;

  const _Section({required this.titre, required this.lignes, this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titre,
              style: const TextStyle(fontSize: 13, color: AppColors.label)),
          const SizedBox(height: 8),
          for (final (libelle, montant, detail) in lignes)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(libelle, style: const TextStyle(fontSize: 13.5)),
                      Text(CurrencyFormatter.format(montant),
                          style: const TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  Text(detail,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.hint)),
                ],
              ),
            ),
          if (total != null) ...[
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(total!.$1,
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w700)),
                Text(CurrencyFormatter.format(total!.$2),
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w700)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

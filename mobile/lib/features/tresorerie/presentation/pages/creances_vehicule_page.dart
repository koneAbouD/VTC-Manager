import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../cotisation/presentation/pages/ligne_cotisation_detail_page.dart';
import '../../../penalite/presentation/pages/ligne_penalite_detail_page.dart';
import '../../../recette/presentation/pages/ligne_recette_detail_page.dart';
import '../../../contravention/presentation/pages/contravention_detail_page.dart';
import '../../../contravention/presentation/providers/contravention_provider.dart';
import '../../domain/entities/creance.dart';
import '../providers/tresorerie_providers.dart';

/// Détail des documents ouverts rattachés à un véhicule, tous chauffeurs et
/// modules confondus. Le tap sur une ligne rouvre le flux d'encaissement du
/// module d'origine.
class CreancesVehiculePage extends ConsumerWidget {
  final int vehiculeId;
  final String vehiculeNom;

  const CreancesVehiculePage({
    super.key,
    required this.vehiculeId,
    required this.vehiculeNom,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncLignes = ref.watch(creancesVehiculeProvider(vehiculeId));

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: AppHeader(title: vehiculeNom),
      body: asyncLignes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Impossible de charger le détail',
                  style: TextStyle(color: Colors.grey.shade600)),
              TextButton.icon(
                onPressed: () =>
                    ref.invalidate(creancesVehiculeProvider(vehiculeId)),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
        data: (lignes) {
          if (lignes.isEmpty) {
            return Center(
              child: Text('Aucune créance en cours',
                  style: TextStyle(color: Colors.grey.shade600)),
            );
          }
          final total = lignes.fold<double>(0, (s, l) => s + l.restant);
          // Liste triée par date de référence décroissante (plus récent en tête).
          final triees = [...lignes]
            ..sort((a, b) => b.dateReference.compareTo(a.dateReference));
          return RefreshIndicator(
            onRefresh: () =>
                ref.refresh(creancesVehiculeProvider(vehiculeId).future),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border, width: 0.8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Restant dû',
                          style: TextStyle(
                              fontSize: 14, color: AppColors.label)),
                      Text(CurrencyFormatter.format(total),
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.dark)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                for (final ligne in triees)
                  _LigneCreanceTile(
                    ligne: ligne,
                    onTap: () => _ouvrirDocument(context, ref, ligne),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _ouvrirDocument(
      BuildContext context, WidgetRef ref, LigneCreance ligne) async {
    switch (ligne.document) {
      case 'RECETTE':
        _push(context, LigneRecetteDetailPage(ligneId: ligne.documentId));
      case 'COTISATION':
        _push(context, LigneCotisationDetailPage(ligneId: ligne.documentId));
      case 'PENALITE':
        _push(context, LignePenaliteDetailPage(ligneId: ligne.documentId));
      default:
        // Contravention : on charge l'entité par son id puis on ouvre son
        // détail (la page attend une Contravention complète).
        final result = await ref
            .read(contraventionRepositoryProvider)
            .getContraventionById(ligne.documentId);
        if (!context.mounted) return;
        result.fold(
          (f) => ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(f.message)),
          ),
          (c) => _push(context, ContraventionDetailPage(contravention: c)),
        );
    }
  }

  void _push(BuildContext context, Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));
}

class _LigneCreanceTile extends StatelessWidget {
  final LigneCreance ligne;
  final VoidCallback onTap;
  const _LigneCreanceTile({required this.ligne, required this.onTap});

  (String, IconData) get _libelleEtIcone => switch (ligne.document) {
        'RECETTE' => ('Recette', Icons.attach_money_rounded),
        'COTISATION' => ('Cotisation', Icons.savings_outlined),
        'PENALITE' => ('Pénalité', Icons.gavel_rounded),
        'CONTRAVENTION' => ('Contravention', Icons.receipt_long_outlined),
        _ => (ligne.document, Icons.description_outlined),
      };

  @override
  Widget build(BuildContext context) {
    final (libelle, icone) = _libelleEtIcone;
    final date = DateFormat('dd/MM/yyyy').format(ligne.dateReference);
    final chauffeur = ligne.chauffeurNom;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.8),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.headerButton,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icone, size: 18, color: AppColors.label),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$libelle · $date',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.dark)),
                    const SizedBox(height: 2),
                    if (chauffeur != null && chauffeur.isNotEmpty)
                      Text(chauffeur,
                          style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: AppColors.primaryDark)),
                    Text(
                      'Dû ${CurrencyFormatter.format(ligne.montantDu)}'
                      ' · réglé ${CurrencyFormatter.format(ligne.montantRegle)}',
                      style: const TextStyle(
                          fontSize: 11.5, color: AppColors.label),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(CurrencyFormatter.format(ligne.restant),
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.red.shade900)),
                  const SizedBox(height: 2),
                  const Text('Encaisser →',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryDark)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

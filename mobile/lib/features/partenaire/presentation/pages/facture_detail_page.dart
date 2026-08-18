import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/detail_carte.dart';
import '../../../../core/widgets/detail_premium.dart';
import '../../../../core/widgets/motif_annulation_dialog.dart';
import '../../../../screens/finance/finance_refresh.dart';
import '../../domain/entities/facture_partenaire.dart';
import '../providers/partenaire_providers.dart';
import '../widgets/facture_dialogs.dart';

/// Détail d'une facture : ce qu'on doit, ce qu'on a déjà payé, et quand.
///
/// L'historique des règlements est la pièce qui explique le restant dû — sans
/// lui, un montant partiel reste inexplicable.
class FactureDetailPage extends ConsumerWidget {
  final int factureId;
  const FactureDetailPage({super.key, required this.factureId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(factureProvider(factureId));

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: const AppHeader(title: 'Facture'),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('$e',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.label)),
          ),
        ),
        data: (facture) => _Corps(facture: facture),
      ),
    );
  }
}

class _Corps extends ConsumerWidget {
  final FacturePartenaire facture;
  const _Corps({required this.facture});

  Future<void> _annuler(BuildContext context, WidgetRef ref) async {
    final motif = await showMotifAnnulationDialog(
      context,
      titre: 'Annuler la facture ?',
      message: 'La charge disparaîtra du résultat et la dette du bilan. '
          'Indiquez le motif.',
    );
    if (motif == null || !context.mounted) return;
    try {
      await ref
          .read(partenaireDatasourceProvider)
          .annulerFacture(facture.id!, motif);
      if (!context.mounted) return;
      refreshPartenaires(ref);
      refreshFinances(ref);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Facture annulée')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: AppColors.error),
      );
    }
  }

  /// Couleur du statut, reprise par la pastille et le badge de l'en-tête.
  Color get _statutColor => switch (facture.statut) {
        StatutFacture.aPayer => AppColors.warning,
        StatutFacture.partiellementPayee => AppColors.info,
        StatutFacture.payee => AppColors.success,
        StatutFacture.annulee => AppColors.error,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reglements = ref.watch(reglementsFactureProvider(facture.id!));
    final retard = facture.joursDeRetard(DateTime.now());
    final dateFmt = DateFormat('dd/MM/yyyy');
    final annulable = facture.statut.estOuverte && facture.montantPaye == 0;

    return ListView(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, 32 + MediaQuery.of(context).padding.bottom),
      children: [
        // Tant que la facture pèse sur la dette, c'est le restant dû qui est la
        // question du jour ; une fois soldée, son montant la nomme mieux qu'un
        // zéro.
        DetailHeroCard(
          icon: Icons.receipt_long_outlined,
          titre: CurrencyFormatter.format(
              facture.statut.estOuverte ? facture.restantDu : facture.montant),
          statutLabel: facture.statut.label,
          statutColor: _statutColor,
        ),
        DetailInfoCard(children: [
          DetailInfoRow(Icons.store_outlined, 'Partenaire',
              facture.partenaireNom ?? 'Partenaire'),
          DetailInfoRow(Icons.tag_outlined, 'Référence', facture.reference),
          DetailInfoRow(Icons.payments_outlined, 'Montant',
              CurrencyFormatter.format(facture.montant)),
          DetailInfoRow(Icons.check_circle_outline_rounded, 'Déjà réglé',
              CurrencyFormatter.format(facture.montantPaye)),
          DetailInfoRow(Icons.hourglass_bottom_outlined, 'Restant dû',
              CurrencyFormatter.format(facture.restantDu)),
          DetailInfoRow(Icons.calendar_today_outlined, 'Date de la facture',
              dateFmt.format(facture.dateFacture)),
          DetailInfoRow(Icons.event_outlined, 'Échéance',
              dateFmt.format(facture.dateEcheance)),
          // Le retard n'est plus un bandeau rouge : il se lit dans la suite des
          // dates, là où on cherche l'échéance.
          DetailInfoRow(Icons.warning_amber_rounded, 'Retard',
              retard > 0 ? '$retard jour(s)' : null),
          DetailInfoRow(
              Icons.description_outlined, 'N° de pièce', facture.numeroPiece),
          DetailInfoRow(Icons.label_outline_rounded, 'Catégorie',
              facture.categorieLibelle),
          DetailInfoRow(Icons.directions_car_filled_rounded, 'Véhicule',
              facture.vehiculeImmatriculation),
          DetailInfoRow(
              Icons.notes_outlined, 'Description', facture.description),
          DetailInfoRow(Icons.info_outline_rounded, "Motif d'annulation",
              facture.motifAnnulation),
        ]),

        // Le détail de l'intervention : ce que cette dette paie exactement.
        if (facture.lignes.isNotEmpty) ...[
          const SizedBox(height: 2),
          DetailLabel(
              Icons.checklist_rounded,
              facture.issueDeMaintenance
                  ? 'Ce que couvre la dette (intervention)'
                  : 'Ce que couvre la dette'),
          DetailInfoCard(children: [
            for (final l in facture.lignes)
              DetailInfoRow(Icons.build_outlined, l.libelle,
                  CurrencyFormatter.format(l.montant)),
          ]),
        ],

        // ── Historique : ce qui explique le restant dû.
        reglements.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          ),
          error: (_, __) => const SizedBox.shrink(),
          data: (liste) => _Historique(reglements: liste),
        ),

        const SizedBox(height: 8),
        if (facture.statut.estOuverte)
          // L'annulation n'a de sens que sur une facture jamais réglée : au-delà,
          // il faut d'abord extourner le règlement.
          annulable
              ? PremiumButtonRow(buttons: [
                  PremiumButton(
                    label: 'Annuler',
                    icon: Icons.block_rounded,
                    color: AppColors.error,
                    filled: false,
                    expanded: true,
                    onPressed: () => _annuler(context, ref),
                  ),
                  PremiumButton(
                    label: 'Régler',
                    icon: Icons.payments_outlined,
                    expanded: true,
                    onPressed: () =>
                        showReglementFactureDialog(context, ref, facture),
                  ),
                ])
              : PremiumButton(
                  label: 'Régler cette facture',
                  icon: Icons.payments_outlined,
                  onPressed: () =>
                      showReglementFactureDialog(context, ref, facture),
                ),
      ],
    );
  }
}

class _Historique extends StatelessWidget {
  final List<ReglementFacture> reglements;
  const _Historique({required this.reglements});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 2),
        DetailLabel(Icons.receipt_outlined, 'Règlements (${reglements.length})'),
        if (reglements.isEmpty)
          const DetailInfoCard(children: [
            DetailInfoRow(Icons.hourglass_empty_rounded, 'Règlements',
                'Aucun pour le moment'),
          ])
        else
          DetailInfoCard(
            children: [
              for (final r in reglements) _ligne(r),
            ],
          ),
      ],
    );
  }

  /// Un règlement : date et mode à gauche, montant à droite. Une extourne reste
  /// visible mais barrée — c'est ce qui explique un restant dû qui remonte.
  Widget _ligne(ReglementFacture r) {
    final couleur = r.extourne ? AppColors.hint : AppColors.dark;
    final barre = r.extourne ? TextDecoration.lineThrough : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
              r.extourne
                  ? Icons.undo_rounded
                  : Icons.check_circle_outline_rounded,
              size: 15,
              color: AppColors.label),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(DateFormat('dd/MM/yyyy').format(r.date),
                    style: TextStyle(
                        fontSize: 13,
                        color: AppColors.label,
                        decoration: barre)),
                if (r.modePaiement != null)
                  Text(
                      r.modePaiement == 'MOBILE_MONEY'
                          ? 'Mobile money'
                          : 'Espèces',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.hint)),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(CurrencyFormatter.format(r.montant),
                textAlign: TextAlign.end,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: couleur,
                    decoration: barre)),
          ),
        ],
      ),
    );
  }
}

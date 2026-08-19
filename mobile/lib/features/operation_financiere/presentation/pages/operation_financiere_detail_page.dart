import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/detail_carte.dart';
import '../../../../core/widgets/detail_premium.dart';
import '../../domain/entities/operation_financiere.dart';
import '../../domain/enums/mode_paiement.dart';
import '../../domain/enums/statut_operation.dart';
import '../../domain/enums/type_operation.dart';
import '../providers/operation_financiere_provider.dart';
import '../providers/operation_financiere_state.dart';
import '../../../../screens/finance/finance_refresh.dart';
import 'operation_financiere_form_page.dart';
import '../../../../core/widgets/motif_annulation_dialog.dart';

/// Page de détail d'une opération financière.
///
/// Reçoit l'opération sélectionnée et relit en continu la liste partagée du
/// provider : ainsi, après une modification via le formulaire, le détail
/// reflète automatiquement les nouvelles valeurs.
class OperationFinanciereDetailPage extends ConsumerWidget {
  final OperationFinanciere? operation;

  /// Ouverture depuis un écran qui ne connaît que l'identifiant : l'opération
  /// est alors chargée avant d'être affichée.
  final int? operationId;

  const OperationFinanciereDetailPage({super.key, required this.operation})
      : operationId = null;

  const OperationFinanciereDetailPage.parId({super.key, required int id})
      : operationId = id,
        operation = null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (operation == null) return _chargeeParId(ref);

    final state = ref.watch(operationFinanciereNotifierProvider);
    final ops = switch (state) {
      OperationFinanciereLoaded(:final operations) => operations,
      OperationFinanciereActionSuccess(:final operations) => operations,
      _ => const <OperationFinanciere>[],
    };
    // NB : on n'utilise pas `firstWhere(orElse:)` car `ops` peut contenir à
    // l'exécution des sous-types (OperationFinanciereModel) ; la covariance
    // ferait alors échouer le closure `orElse` typé OperationFinanciere.
    final match = ops.where((o) => o.id == operation!.id);
    final op = match.isEmpty ? operation! : match.first;

    return Scaffold(
      appBar: const AppHeader(title: 'Détail opération'),
      body: _DetailBody(op: op),
    );
  }

  /// Détail servi à partir du seul identifiant : la liste partagée n'est pas
  /// forcément chargée — ni même complète, puisqu'elle est paginée — l'opération
  /// est donc relue au serveur.
  Widget _chargeeParId(WidgetRef ref) {
    final async = ref.watch(operationFinanciereByIdProvider(operationId!));
    return Scaffold(
      appBar: const AppHeader(title: 'Détail opération'),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded,
                    size: 40, color: AppColors.hint),
                const SizedBox(height: 12),
                Text(
                  e.toString().replaceFirst('Exception: ', ''),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: AppColors.label),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () => ref
                      .invalidate(operationFinanciereByIdProvider(operationId!)),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Réessayer'),
                ),
              ],
            ),
          ),
        ),
        data: (op) => _DetailBody(op: op),
      ),
    );
  }
}

// ── Corps ──────────────────────────────────────────────────────────────────

class _DetailBody extends ConsumerWidget {
  final OperationFinanciere op;
  const _DetailBody({required this.op});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final money =
        NumberFormat.currency(locale: 'fr_FR', symbol: 'XOF', decimalDigits: 0);
    final dateFmt = DateFormat('dd/MM/yyyy', 'fr_FR');

    // Ce qui compte à l'œil, c'est le sens dans lequel l'argent bouge — pas le
    // type de l'écriture. Une extourne conserve le type de l'origine mais porte
    // un montant opposé : une dépense annulée fait donc rentrer de l'argent.
    final isRevenu = op.typeOperation == TypeOperation.REVENU;
    final effetCaisse = isRevenu ? op.montant : -op.montant;
    final entreEnCaisse = effetCaisse >= 0;
    final color = entreEnCaisse ? AppColors.success : AppColors.error;
    final sign = entreEnCaisse ? '+' : '-';
    final statutColor = switch (op.statut) {
      StatutOperation.ENCAISSE || StatutOperation.PAYE => AppColors.success,
      StatutOperation.ANNULEE => AppColors.error,
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // La pastille suit le sens du mouvement, pas le statut : une dépense
        // payée sort de la caisse, et un badge vert le dirait mal.
        DetailHeroCard(
          icon: entreEnCaisse
              ? Icons.trending_up_rounded
              : Icons.trending_down_rounded,
          iconColor: color,
          titre: '$sign${money.format(effetCaisse.abs())}',
          statutLabel: op.statut.libelle,
          statutColor: statutColor,
        ),
        DetailInfoCard(children: [
          DetailInfoRow(Icons.swap_vert_rounded, 'Type',
              op.typeOperation.libelle),
          DetailInfoRow(
              Icons.label_outline_rounded, 'Catégorie', op.categorieLibelle),
          DetailInfoRow(Icons.subdirectory_arrow_right_rounded,
              'Sous-catégorie', op.sousCategorieLibelle),
          DetailInfoRow(Icons.calendar_today_outlined, 'Date',
              dateFmt.format(op.dateOperation)),
          DetailInfoRow(Icons.account_balance_wallet_outlined,
              'Mode de paiement', op.modePaiement?.libelle),
          DetailInfoRow(
              Icons.directions_car_filled_rounded, 'Véhicule', op.vehiculeNom),
          DetailInfoRow(Icons.store_outlined, 'Partenaire', op.partenaireNom),
          DetailInfoRow(
              Icons.person_outline_rounded, 'Chauffeur', op.chauffeurNom),
          DetailInfoRow(Icons.tag_outlined, 'Référence', op.reference),
          DetailInfoRow(Icons.notes_outlined, 'Commentaire', op.commentaire),
        ]),

        // ── Détail maintenance (si présent) ──────────────────────────────
        if (op.detailMaintenance != null) ...[
          const SizedBox(height: 2),
          const DetailLabel(Icons.build_circle_outlined, 'Détail maintenance'),
          DetailInfoCard(children: [
            DetailInfoRow(
                Icons.timer_outlined,
                'Durée',
                op.detailMaintenance!.dureeMaintenance != null
                    ? '${op.detailMaintenance!.dureeMaintenance} min'
                    : null),
            for (final el in op.detailMaintenance!.elements)
              DetailInfoRow(Icons.build_outlined, el.libelleAvecQuantite,
                  money.format(el.montant)),
          ]),
        ],

        const SizedBox(height: 8),

        // ── Actions (masquées si l'opération est déjà annulée) ────────────
        //
        // « Modifier » ne s'affiche que si le serveur accepte encore de
        // retoucher l'écriture : un encaissement et une dépense de maintenance
        // en sont exclus, leur montant appartient à la créance ou à
        // l'intervention qui les a produits. Pour ceux-là, la seule voie est
        // l'annulation, qui repositionne la source, puis la ressaisie.
        //
        // « Annuler » disparaît de son côté dès qu'un arrêté — période close ou
        // caisse comptée — couvre la date de l'écriture : la contre-passation
        // serait refusée.
        //
        // Les deux peuvent tomber en même temps — une écriture d'encaissement
        // d'un mois clos, par exemple : la barre disparaît alors entièrement
        // plutôt que de laisser une bande vide.
        if (op.statut != StatutOperation.ANNULEE &&
            (op.annulable || op.modifiable))
          PremiumButtonRow(buttons: [
            if (op.annulable)
              PremiumButton(
                label: 'Annuler',
                icon: Icons.cancel_outlined,
                color: AppColors.error,
                filled: false,
                expanded: true,
                onPressed: () => _supprimer(context, ref),
              ),
            if (op.modifiable)
              PremiumButton(
                label: 'Modifier',
                icon: Icons.edit_outlined,
                expanded: true,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OperationFinanciereFormPage(
                      initialType: op.typeOperation,
                      initial: op,
                    ),
                  ),
                ),
              ),
          ]),
      ],
    );
  }

  Future<void> _supprimer(BuildContext context, WidgetRef ref) async {
    final id = op.id;
    if (id == null) return;

    // L'écriture n'est pas effacée : elle est contre-passée par une extourne
    // datée du jour, qui porte ce motif. Il est donc obligatoire.
    final motif = await showMotifAnnulationDialog(
      context,
      titre: 'Annuler l\'opération ?',
      message: "L'opération sera contre-passée par une écriture d'extourne "
          'datée du jour. Indiquez le motif.',
    );
    if (motif == null) return;
    if (!context.mounted) return;

    final error = await ref
        .read(operationFinanciereNotifierProvider.notifier)
        .annuler(id, motif);
    if (!context.mounted) return;

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
    } else {
      // Annuler une opération impacte trésorerie, créances, résultat… :
      // rafraîchit tout le module Finances.
      refreshFinances(ref);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Opération extournée')),
      );
      Navigator.pop(context);
    }
  }
}


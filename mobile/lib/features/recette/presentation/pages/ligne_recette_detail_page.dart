import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/encaissement.dart';
import '../../domain/entities/ligne_recette.dart';
import '../providers/ligne_recette_provider.dart';
import 'encaissement_form_page.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/detail_carte.dart';
import '../../../../core/widgets/detail_premium.dart';
import '../../../../core/widgets/motif_annulation_dialog.dart';
import '../../../../screens/finance/finance_refresh.dart';

class LigneRecetteDetailPage extends ConsumerWidget {
  final int ligneId;

  const LigneRecetteDetailPage({super.key, required this.ligneId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncLigne = ref.watch(ligneRecetteDetailProvider(ligneId));

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: AppHeader(
        title: 'Détail recette',
        action: AppHeaderAction(
          icon: Icons.refresh,
          onTap: () => ref.invalidate(ligneRecetteDetailProvider(ligneId)),
        ),
      ),
      body: asyncLigne.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(e.toString().replaceFirst('Exception: ', ''),
              style: const TextStyle(color: AppColors.error)),
        ),
        data: (ligne) => _DetailBody(ligne: ligne, ligneId: ligneId),
      ),
    );
  }
}

// ── Corps du détail ────────────────────────────────────────────────────────

class _DetailBody extends ConsumerWidget {
  final LigneRecette ligne;
  final int ligneId;

  const _DetailBody({required this.ligne, required this.ligneId});

  (String, Color) get _statut => switch (ligne.statut) {
        StatutLigneRecette.enAttente => (ligne.statut.label, AppColors.warning),
        StatutLigneRecette.partiellementEncaisse =>
          (ligne.statut.label, AppColors.info),
        StatutLigneRecette.encaisse => (ligne.statut.label, AppColors.success),
        StatutLigneRecette.annulee => (ligne.statut.label, AppColors.error),
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt =
        NumberFormat.currency(locale: 'fr_FR', symbol: 'XOF', decimalDigits: 0);
    final dateFmt = DateFormat('dd/MM/yyyy');
    final (statutLabel, statutColor) = _statut;
    final restant = ligne.montantRestant;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        // Le statut n'est plus une ligne d'info : le badge de l'en-tête le dit
        // déjà, et le répéter en dessous n'apprenait rien.
        DetailHeroCard(
          icon: Icons.receipt_long_outlined,
          titre: fmt.format(ligne.montantAttendu ?? ligne.montantEncaisse),
          statutLabel: statutLabel,
          statutColor: statutColor,
        ),
        DetailInfoCard(children: [
          DetailInfoRow(Icons.calendar_today_outlined, 'Date',
              dateFmt.format(ligne.dateRecette)),
          DetailInfoRow(Icons.directions_car_filled_rounded, 'Véhicule',
              ligne.vehiculeImmatriculation ?? 'Véhicule #${ligne.vehiculeId}'),
          DetailInfoRow(
              Icons.person_outline_rounded, 'Chauffeur', ligne.chauffeurNom),
          DetailInfoRow(
              Icons.payments_outlined,
              'Attendu',
              ligne.montantAttendu != null
                  ? fmt.format(ligne.montantAttendu)
                  : null),
          DetailInfoRow(Icons.check_circle_outline_rounded, 'Encaissé',
              fmt.format(ligne.montantEncaisse)),
          DetailInfoRow(Icons.schedule_outlined, 'Restant',
              restant != null ? fmt.format(restant) : null),
          DetailInfoRow(Icons.info_outline_rounded, 'Motif annulation',
              ligne.motifAnnulation),
        ]),
        if (ligne.estActive && ligne.montantAttendu == null)
          PremiumButton(
            label: 'Confirmer le versement',
            icon: Icons.check_circle_outline,
            onPressed: () => _confirmerVersement(context, ref),
          ),
        if (ligne.estActive)
          PremiumButtonRow(buttons: [
            PremiumButton(
              label: 'Annuler',
              icon: Icons.cancel_outlined,
              color: AppColors.error,
              filled: false,
              expanded: true,
              onPressed: () => _annuler(context, ref),
            ),
            PremiumButton(
              label: 'Encaisser',
              icon: Icons.add,
              expanded: true,
              onPressed: () => _encaisser(context, ref),
            ),
          ]),
        const SizedBox(height: 10),
        // Le compteur ne retient que les versements qui tiennent encore : un
        // encaissement extourné reste listé, barré, mais il ne compte plus —
        // c'est le montant encaissé de la ligne qui doit s'y retrouver.
        DetailLabel(Icons.receipt_outlined,
            'Encaissements (${ligne.encaissements.where((e) => !e.estAnnule).length})'),
        if (ligne.encaissements.isEmpty)
          const PremiumEmpty('Aucun encaissement enregistré.')
        else
          ...ligne.encaissements.map((e) => PremiumEncaissementTile(
                montant: fmt.format(e.montant),
                especes: e.modeEncaissement == ModeEncaissement.especes,
                meta:
                    '${e.modeEncaissement.label} · ${dateFmt.format(e.dateEncaissement)}'
                    '${e.reference != null ? ' · ${e.reference}' : ''}',
                commentaire: e.commentaire,
                annule: e.estAnnule,
                motifAnnulation: e.motifAnnulation,
              )),
      ],
    );
  }

  Future<void> _encaisser(BuildContext context, WidgetRef ref) async {
    final refreshed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => EncaissementFormPage(ligne: ligne)),
    );
    if (refreshed == true) {
      ref.invalidate(ligneRecetteDetailProvider(ligneId));
      refreshFinances(ref);
    }
  }

  Future<void> _confirmerVersement(BuildContext context, WidgetRef ref) async {
    final error = await ref
        .read(ligneRecetteNotifierProvider.notifier)
        .confirmerVersement(ligneId);
    if (!context.mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: AppColors.error));
    } else {
      ref.invalidate(ligneRecetteDetailProvider(ligneId));
      refreshFinances(ref);
    }
  }

  Future<void> _annuler(BuildContext context, WidgetRef ref) async {
    final motif = await showMotifAnnulationDialog(context);
    if (motif == null || !context.mounted) return;

    final error = await ref
        .read(ligneRecetteNotifierProvider.notifier)
        .annuler(ligneId, motif);
    if (!context.mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: AppColors.error));
    } else {
      // Actualise immédiatement le détail + toutes les pages du module Finances.
      ref.invalidate(ligneRecetteDetailProvider(ligneId));
      refreshFinances(ref);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Ligne annulée')));
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/encaissement_cotisation.dart';
import '../../domain/entities/ligne_cotisation.dart';
import '../providers/ligne_cotisation_provider.dart';
import 'encaissement_cotisation_form_page.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/detail_premium.dart';
import '../../../../core/widgets/motif_annulation_dialog.dart';
import '../../../../screens/finance/finance_refresh.dart';

class LigneCotisationDetailPage extends ConsumerWidget {
  final int ligneId;
  const LigneCotisationDetailPage({super.key, required this.ligneId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncLigne = ref.watch(ligneCotisationDetailProvider(ligneId));
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: AppHeader(
        title: 'Détail cotisation',
        action: AppHeaderAction(
          icon: Icons.refresh,
          onTap: () => ref.invalidate(ligneCotisationDetailProvider(ligneId)),
        ),
      ),
      body: asyncLigne.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text(e.toString().replaceFirst('Exception: ', ''),
                style: const TextStyle(color: AppColors.error))),
        data: (ligne) => _Body(ligne: ligne, ligneId: ligneId),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  final LigneCotisation ligne;
  final int ligneId;
  const _Body({required this.ligne, required this.ligneId});

  (String, Color) get _statut => switch (ligne.statut) {
        StatutLigneCotisation.enAttente =>
          (ligne.statut.label, AppColors.warning),
        StatutLigneCotisation.partiellementEncaisse =>
          (ligne.statut.label, AppColors.info),
        StatutLigneCotisation.encaisse =>
          (ligne.statut.label, AppColors.success),
        StatutLigneCotisation.annulee => (ligne.statut.label, AppColors.error),
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt =
        NumberFormat.currency(locale: 'fr_FR', symbol: 'XOF', decimalDigits: 0);
    final dateFmt = DateFormat('dd/MM/yyyy');
    final restant = ligne.montantRestant ?? (ligne.montantDu - ligne.montantEncaisse);
    final (statutLabel, statutColor) = _statut;

    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), children: [
      PremiumHero(
        amount: fmt.format(ligne.montantDu),
        footerIcon: Icons.directions_car_outlined,
        footer: [
          ligne.vehiculeImmatriculation ?? 'Véhicule #${ligne.vehiculeId}',
          if (ligne.chauffeurNom != null) ligne.chauffeurNom!,
        ].join('  ·  '),
        chips: [
          PremiumChip(statutLabel, statutColor),
          if (restant > 0)
            PremiumChip('Restant ${fmt.format(restant)}', AppColors.warning),
        ],
      ),
      const SizedBox(height: 14),
      PremiumSection(
        title: 'Cotisation',
        icon: Icons.savings_outlined,
        children: [
          PremiumRow('Cotisation', ligne.nomCotisation),
          PremiumRow('Date', dateFmt.format(ligne.dateCotisation)),
          PremiumRow('Véhicule',
              ligne.vehiculeImmatriculation ?? '#${ligne.vehiculeId}'),
          PremiumRow('Chauffeur', ligne.chauffeurNom),
          PremiumRow('Statut', statutLabel, valueColor: statutColor),
          PremiumRow('Motif annulation', ligne.motifAnnulation,
              valueColor: AppColors.error),
        ],
      ),
      PremiumSection(
        title: 'Montants',
        icon: Icons.payments_outlined,
        children: [
          PremiumRow('Dû', fmt.format(ligne.montantDu)),
          PremiumRow('Encaissé', fmt.format(ligne.montantEncaisse),
              valueColor: AppColors.success),
          PremiumRow('Restant', fmt.format(restant),
              valueColor: restant > 0 ? AppColors.warning : AppColors.success),
        ],
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
      PremiumListHeader('Encaissements (${ligne.encaissements.length})'),
      if (ligne.encaissements.isEmpty)
        const PremiumEmpty('Aucun encaissement enregistré.')
      else
        ...ligne.encaissements.map((e) => PremiumEncaissementTile(
              montant: fmt.format(e.montant),
              especes: e.modeEncaissement == ModePaiementCotisation.especes,
              meta:
                  '${e.modeEncaissement.label} · ${dateFmt.format(e.dateEncaissement)}'
                  '${e.reference != null ? ' · ${e.reference}' : ''}',
              commentaire: e.commentaire,
            )),
    ]);
  }

  Future<void> _encaisser(BuildContext context, WidgetRef ref) async {
    final ok = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
            builder: (_) => EncaissementCotisationFormPage(ligne: ligne)));
    if (ok == true) {
      ref.invalidate(ligneCotisationDetailProvider(ligneId));
      refreshFinances(ref);
    }
  }

  Future<void> _annuler(BuildContext context, WidgetRef ref) async {
    final motif = await showMotifAnnulationDialog(context);
    if (motif == null || !context.mounted) return;
    final error = await ref
        .read(ligneCotisationNotifierProvider.notifier)
        .annuler(ligneId, motif);
    if (!context.mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: AppColors.error));
    } else {
      ref.invalidate(ligneCotisationDetailProvider(ligneId));
      refreshFinances(ref);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Ligne annulée')));
    }
  }
}

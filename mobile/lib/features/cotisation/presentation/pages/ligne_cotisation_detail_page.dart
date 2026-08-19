import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/encaissement_cotisation.dart';
import '../../domain/entities/ligne_cotisation.dart';
import '../providers/ligne_cotisation_provider.dart';
import 'encaissement_cotisation_form_page.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/detail_carte.dart';
import '../../../../core/widgets/detail_premium.dart';
import '../../../../core/widgets/confirmation_restauration_dialog.dart';
import '../../../../core/widgets/motif_annulation_dialog.dart';
import '../../../../screens/finance/finance_refresh.dart';

class LigneCotisationDetailPage extends ConsumerWidget {
  final int ligneId;
  const LigneCotisationDetailPage({super.key, required this.ligneId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncLigne = ref.watch(ligneCotisationDetailProvider(ligneId));

    // Le rechargement ne s'affiche plus sur une ligne vivante — en attente,
    // partiellement encaissée ou soldée : ses actions la rafraîchissent déjà.
    // Il reste là où il sert encore : le temps du chargement, en cas d'erreur
    // (c'est le seul recours de cet écran) et sur une ligne annulée.
    final ligne = asyncLigne.valueOrNull;
    final actionRafraichir = ligne != null && ligne.statut != StatutLigneCotisation.annulee
        ? null
        : AppHeaderAction(
            icon: Icons.refresh,
            onTap: () => ref.invalidate(ligneCotisationDetailProvider(ligneId)),
          );

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: AppHeader(
        title: 'Détail cotisation',
        action: actionRafraichir,
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
      // Le statut n'est plus une ligne d'info : le badge de l'en-tête le dit
      // déjà, et le répéter en dessous n'apprenait rien.
      DetailHeroCard(
        // Même icône que le bouton « Cotisations » de l'accueil.
        icon: Icons.analytics_outlined,
        titre: fmt.format(ligne.montantDu),
        statutLabel: statutLabel,
        statutColor: statutColor,
      ),
      DetailInfoCard(children: [
        DetailInfoRow(
            Icons.label_outline_rounded, 'Cotisation', ligne.nomCotisation),
        DetailInfoRow(Icons.calendar_today_outlined, 'Date',
            dateFmt.format(ligne.dateCotisation)),
        DetailInfoRow(Icons.directions_car_filled_rounded, 'Véhicule',
            ligne.vehiculeImmatriculation ?? 'Véhicule #${ligne.vehiculeId}'),
        DetailInfoRow(
            Icons.person_outline_rounded, 'Chauffeur', ligne.chauffeurNom),
        DetailInfoRow(Icons.payments_outlined, 'Dû', fmt.format(ligne.montantDu)),
        DetailInfoRow(Icons.check_circle_outline_rounded, 'Encaissé',
            fmt.format(ligne.montantEncaisse)),
        DetailInfoRow(
            Icons.schedule_outlined, 'Restant', fmt.format(restant)),
        DetailInfoRow(Icons.info_outline_rounded, 'Motif annulation',
            ligne.motifAnnulation),
      ]),
      // Une ligne annulée à tort se remet en circulation tant que les livres du
      // mois sont ouverts : elle retrouve le statut que dictent ses versements.
      // Passé la clôture, le serveur refuse.
      if (ligne.statut == StatutLigneCotisation.annulee && ligne.restaurable)
        PremiumButton(
          label: 'Restaurer',
          icon: Icons.restore_rounded,
          onPressed: () => _restaurer(context, ref),
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
      // encaissement extourné reste listé, barré, mais il ne compte plus.
      DetailLabel(Icons.receipt_outlined,
          'Encaissements (${ligne.encaissements.where((e) => !e.estAnnule).length})'),
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
              annule: e.estAnnule,
              motifAnnulation: e.motifAnnulation,
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

  Future<void> _restaurer(BuildContext context, WidgetRef ref) async {
    final confirme = await showConfirmationRestaurationDialog(
      context,
      message: 'La cotisation redeviendra due par le chauffeur, avec le statut '
          'que dictent ses versements.',
    );
    if (confirme != true || !context.mounted) return;

    final error = await ref
        .read(ligneCotisationNotifierProvider.notifier)
        .restaurer(ligneId);
    if (!context.mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: AppColors.error));
    } else {
      ref.invalidate(ligneCotisationDetailProvider(ligneId));
      refreshFinances(ref);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Ligne restaurée')));
    }
  }
}

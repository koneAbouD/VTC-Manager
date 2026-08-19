import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/encaissement_cotisation.dart';
import '../../domain/entities/ligne_cotisation.dart';
import '../providers/ligne_cotisation_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/encaissement_ligne_dialog.dart';
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

    // Une seule icône dans l'en-tête, selon ce que la fiche permet :
    //   • annulée à tort et les livres encore ouverts → « Restaurer », la
    //     remet en circulation avec le statut que dictent ses versements ;
    //   • fiche illisible parce que la lecture a échoué → rechargement, seul
    //     recours de cet écran ;
    //   • sinon rien : une ligne vivante est rafraîchie par ses propres
    //     actions, et une annulation figée par un arrêté n'offre plus rien.
    final ligne = asyncLigne.valueOrNull;
    final action = switch (ligne) {
      final l? when l.statut == StatutLigneCotisation.annulee && l.restaurable =>
        AppHeaderAction(
          icon: Icons.restore_rounded,
          onTap: () => _restaurer(context, ref, ligneId),
        ),
      // Le rechargement ne s'offre qu'en cas d'échec. Pendant le premier
      // chargement, l'en-tête reste nu : une icône posée là le temps de la
      // requête, puis retirée dès la fiche arrivée, se lit comme un bouton qui
      // s'évapore — et sa flèche circulaire ressemble à s'y méprendre à celle
      // de la restauration.
      null when asyncLigne.hasError => AppHeaderAction(
          icon: Icons.refresh,
          onTap: () => ref.invalidate(ligneCotisationDetailProvider(ligneId)),
        ),
      _ => null,
    };

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: AppHeader(
        title: 'Détail cotisation',
        action: action,
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
    final repo = ref.read(ligneCotisationRepositoryProvider);
    final immat = ligne.vehiculeImmatriculation ?? 'Véhicule ${ligne.vehiculeId}';
    final nom = ligne.chauffeurNom;

    final ok = await showEncaissementLigneDialog(
      context,
      titre:     ligne.nomCotisation,
      sousTitre: (nom != null && nom.isNotEmpty) ? '$immat - $nom' : immat,
      montantRestant: ligne.montantRestant ??
          (ligne.montantDu - ligne.montantEncaisse),
      couleur: const Color(0xFFE65100),
      icone:   Icons.analytics_outlined,
      onEncaisser: (saisie) async {
        final enc = EncaissementCotisation(
          ligneCotisationId: ligne.id!,
          montant:           saisie.montant,
          modeEncaissement:  saisie.mode == ModeEncaissementSaisie.mobileMoney
              ? ModePaiementCotisation.mobileMoney
              : ModePaiementCotisation.especes,
          dateEncaissement:  saisie.date,
          reference:         saisie.reference,
          commentaire:       saisie.commentaire,
        );
        final r = await repo.createEncaissement(ligne.id!, enc);
        return r.fold((f) => f.message, (_) => null);
      },
    );
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

/// Remet une cotisation annulée en circulation. Portée par l'icône de
/// l'en-tête, et non plus par un bouton du corps : la confirmation reste le
/// garde-fou.
Future<void> _restaurer(BuildContext context, WidgetRef ref, int ligneId) async {
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

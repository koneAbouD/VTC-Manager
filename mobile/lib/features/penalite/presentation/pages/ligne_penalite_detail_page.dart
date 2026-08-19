import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/ligne_penalite.dart';
import '../providers/penalite_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/encaissement_ligne_dialog.dart';
import '../../../../core/widgets/detail_carte.dart';
import '../../../../core/widgets/detail_premium.dart';
import '../../../../core/widgets/confirmation_restauration_dialog.dart';
import '../../../../core/widgets/motif_annulation_dialog.dart';
import '../../../../screens/finance/finance_refresh.dart';

class LignePenaliteDetailPage extends ConsumerWidget {
  final int ligneId;
  const LignePenaliteDetailPage({super.key, required this.ligneId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncLigne = ref.watch(lignePenaliteDetailProvider(ligneId));

    // Une seule icône dans l'en-tête, selon ce que la fiche permet :
    //   • annulée à tort et les livres encore ouverts → « Restaurer », qui
    //     rend la sanction applicable ;
    //   • fiche illisible parce que la lecture a échoué → rechargement, seul
    //     recours de cet écran ;
    //   • sinon rien : une sanction vivante est rafraîchie par ses propres
    //     actions, et une annulation figée par un arrêté n'offre plus rien.
    final ligne = asyncLigne.valueOrNull;
    final action = switch (ligne) {
      final l? when l.statut == StatutLignePenalite.annulee && l.restaurable =>
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
          onTap: () => ref.invalidate(lignePenaliteDetailProvider(ligneId)),
        ),
      _ => null,
    };

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: AppHeader(
        title: 'Détail pénalité',
        action: action,
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

// ── Corps ──────────────────────────────────────────────────────────────────────

class _DetailBody extends ConsumerWidget {
  final LignePenalite ligne;
  final int ligneId;
  const _DetailBody({required this.ligne, required this.ligneId});

  (String, Color) get _statut => switch (ligne.statut) {
        StatutLignePenalite.enAttente =>
          (ligne.statut.label, AppColors.warning),
        StatutLignePenalite.partiellementEncaissee =>
          (ligne.statut.label, AppColors.info),
        StatutLignePenalite.encaissee =>
          (ligne.statut.label, AppColors.success),
        StatutLignePenalite.executee => (ligne.statut.label, AppColors.success),
        StatutLignePenalite.notifiee => (ligne.statut.label, AppColors.info),
        StatutLignePenalite.enCours => (ligne.statut.label, AppColors.warning),
        StatutLignePenalite.levee => (ligne.statut.label, AppColors.success),
        StatutLignePenalite.annulee => (ligne.statut.label, AppColors.error),
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt =
        NumberFormat.currency(locale: 'fr_FR', symbol: 'XOF', decimalDigits: 0);
    final dateFmt = DateFormat('dd/MM/yyyy');
    final dtFmt = DateFormat('dd/MM/yyyy HH:mm');
    final estAmende = ligne.typeSanction == TypeSanctionLigne.amende;
    final (statutLabel, statutColor) = _statut;
    final restant = ligne.montantRestant;

    // Action principale du moment (au plus une, selon le type et l'état) :
    // (libellé, icône, couleur, action).
    final (String, IconData, Color, VoidCallback)? primaire = ligne.isEncaissable
        ? ('Encaisser', Icons.payments_outlined, AppColors.primary,
            () => _openEncaissement(context, ref, ligne))
        : ligne.isExecutable
            ? ('Marquer exécuté', Icons.volume_up_outlined, AppColors.warning,
                () => _executer(context, ref))
            : ligne.isNotifiable
                ? ('Marquer notifié', Icons.warning_amber_rounded,
                    AppColors.warning, () => _notifier(context, ref))
                : ligne.isDemarrable
                    ? ('Démarrer', Icons.block_outlined, AppColors.error,
                        () => _demarrer(context, ref))
                    : ligne.isLevable
                        ? ('Lever', Icons.lock_open_outlined, AppColors.info,
                            () => _lever(context, ref))
                        : null;
    final annulable = !ligne.statut.isTerminal;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        // Une sanction non pécuniaire n'a pas de montant à mettre en titre :
        // c'est alors la nature de la sanction qui nomme la page.
        DetailHeroCard(
          icon: Icons.gavel_outlined,
          titre:
              estAmende ? fmt.format(ligne.montant) : ligne.typeSanction.label,
          statutLabel: statutLabel,
          statutColor: statutColor,
        ),
        DetailInfoCard(children: [
          DetailInfoRow(Icons.category_outlined, 'Type',
              ligne.typeSanction.label),
          DetailInfoRow(Icons.gavel_outlined, 'Pénalité',
              _typePenaliteLabel(ligne.typePenalite)),
          DetailInfoRow(Icons.directions_car_filled_rounded, 'Véhicule',
              ligne.vehiculeImmatriculation ?? 'Véhicule #${ligne.vehiculeId}'),
          DetailInfoRow(Icons.person_outline_rounded, 'Chauffeur',
              ligne.chauffeurNomComplet),
          DetailInfoRow(Icons.event_busy_outlined, 'Date de faute',
              ligne.dateFaute != null ? dateFmt.format(ligne.dateFaute!) : null),
          DetailInfoRow(Icons.calendar_today_outlined, 'Généré le',
              dateFmt.format(ligne.dateGeneration)),
          // Montants : seule l'amende en a.
          if (estAmende) ...[
            DetailInfoRow(Icons.payments_outlined, 'Montant total',
                fmt.format(ligne.montant)),
            DetailInfoRow(Icons.check_circle_outline_rounded, 'Encaissé',
                fmt.format(ligne.montantEncaisse)),
            DetailInfoRow(Icons.schedule_outlined, 'Restant',
                restant != null && restant > 0 ? fmt.format(restant) : null),
          ],
          if (ligne.typeSanction == TypeSanctionLigne.buzzer)
            DetailInfoRow(
                Icons.notifications_active_outlined,
                'Durée buzzer',
                ligne.dureeSanctionSecondes != null
                    ? '${ligne.dureeSanctionSecondes}s'
                    : null),
          if (ligne.typeSanction == TypeSanctionLigne.immobilisation) ...[
            DetailInfoRow(
                Icons.block_outlined,
                'Durée prévue',
                ligne.dureeImmobilisationMinutes != null
                    ? '${ligne.dureeImmobilisationMinutes} min'
                    : null),
            DetailInfoRow(
                Icons.play_arrow_outlined,
                'Début',
                ligne.dateDebutImmobilisation != null
                    ? dtFmt.format(ligne.dateDebutImmobilisation!)
                    : null),
            DetailInfoRow(
                Icons.stop_outlined,
                'Fin',
                ligne.dateFinImmobilisation != null
                    ? dtFmt.format(ligne.dateFinImmobilisation!)
                    : null),
          ],
          DetailInfoRow(
              Icons.notes_outlined, 'Commentaire', ligne.commentaire),
          DetailInfoRow(Icons.info_outline_rounded, 'Motif annulation',
              ligne.motifAnnulation),
        ]),

        // ── Boutons d'action (Annuler + action principale sur une ligne) ──
        if (primaire != null && annulable)
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
              label: primaire.$1,
              icon: primaire.$2,
              color: primaire.$3,
              expanded: true,
              onPressed: primaire.$4,
            ),
          ])
        else if (primaire != null)
          PremiumButton(
            label: primaire.$1,
            icon: primaire.$2,
            color: primaire.$3,
            onPressed: primaire.$4,
          )
        else if (annulable)
          PremiumButton(
            label: 'Annuler la pénalité',
            icon: Icons.cancel_outlined,
            color: AppColors.error,
            filled: false,
            onPressed: () => _annuler(context, ref),
          ),

        // ── Historique encaissements (AMENDE) ────────────────────────────
        if (estAmende) ...[
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
                  especes: e.modeEncaissement == 'ESPECES',
                  meta:
                      '${e.modeEncaissement} · ${dateFmt.format(e.dateEncaissement)}'
                      '${e.reference != null ? ' · ${e.reference}' : ''}',
                  commentaire: e.commentaire,
                  annule: e.estAnnule,
                  motifAnnulation: e.motifAnnulation,
                )),
        ],
      ],
    );
  }

  String _typePenaliteLabel(String type) => switch (type) {
        'RECETTE_NON_VERSEE' => 'Recette non versée',
        'HEURE_FIN_SERVICE_PASSE' => 'Fin de service dépassée',
        'EXCES_VITESSE' => 'Excès de vitesse',
        _ => type,
      };

  Future<void> _openEncaissement(
      BuildContext context, WidgetRef ref, LignePenalite l) async {
    final notifier = ref.read(lignePenaliteNotifierProvider.notifier);
    final immat = l.vehiculeImmatriculation ?? 'Véhicule ${l.vehiculeId}';
    final nom = l.chauffeurNomComplet;

    final refreshed = await showEncaissementLigneDialog(
      context,
      titre:          'Amende — ${_typePenaliteLabel(l.typePenalite)}',
      sousTitre:      (nom != null && nom.isNotEmpty) ? '$immat - $nom' : immat,
      montantRestant: l.montantRestant,
      couleur:        const Color(0xFFB71C1C),
      icone:          Icons.gavel_outlined,
      onEncaisser: (saisie) async {
        return notifier.createEncaissementDetail(l.id!, {
          'montant':           saisie.montant,
          'modeEncaissement':  saisie.mode == ModeEncaissementSaisie.mobileMoney
              ? 'MOBILE_MONEY'
              : 'ESPECES',
          'dateEncaissement':  saisie.date,
          if (saisie.reference != null) 'reference': saisie.reference,
          if (saisie.commentaire != null) 'commentaire': saisie.commentaire,
        });
      },
    );
    if (refreshed == true) {
      ref.invalidate(lignePenaliteDetailProvider(ligneId));
      refreshFinances(ref);
    }
  }

  Future<void> _executer(BuildContext context, WidgetRef ref) =>
      _executeAction(context, ref,
          () => ref.read(lignePenaliteNotifierProvider.notifier).executerDetail(ligneId));

  Future<void> _notifier(BuildContext context, WidgetRef ref) =>
      _executeAction(context, ref,
          () => ref.read(lignePenaliteNotifierProvider.notifier).notifierDetail(ligneId));

  Future<void> _demarrer(BuildContext context, WidgetRef ref) =>
      _executeAction(context, ref,
          () => ref.read(lignePenaliteNotifierProvider.notifier).demarrerDetail(ligneId));

  Future<void> _lever(BuildContext context, WidgetRef ref) =>
      _executeAction(context, ref,
          () => ref.read(lignePenaliteNotifierProvider.notifier).leverDetail(ligneId));

  Future<void> _annuler(BuildContext context, WidgetRef ref) async {
    final motif = await showMotifAnnulationDialog(context,
        titre: 'Annuler la pénalité ?');
    if (motif == null || !context.mounted) return;
    final error = await ref
        .read(lignePenaliteNotifierProvider.notifier)
        .annulerDetail(ligneId, motif);
    if (!context.mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: AppColors.error));
    } else {
      // Actualise immédiatement le détail + les écrans finance impactés.
      ref.invalidate(lignePenaliteDetailProvider(ligneId));
      refreshFinances(ref);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pénalité annulée')));
    }
  }


  Future<void> _executeAction(BuildContext context, WidgetRef ref,
      Future<String?> Function() action) async {
    final error = await action();
    if (!context.mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.error),
      );
    } else {
      ref.invalidate(lignePenaliteDetailProvider(ligneId));
    }
  }
}

/// Rend applicable une sanction annulée. Portée par l'icône de l'en-tête, et
/// non plus par un bouton du corps : la confirmation reste le garde-fou.
Future<void> _restaurer(BuildContext context, WidgetRef ref, int ligneId) async {
  final confirme = await showConfirmationRestaurationDialog(
    context,
    titre: 'Restaurer la pénalité ?',
    message: 'La sanction redeviendra applicable : une amende retrouve le '
        'statut que dictent ses versements, les autres repartent en attente.',
  );
  if (confirme != true || !context.mounted) return;

  final error = await ref
      .read(lignePenaliteNotifierProvider.notifier)
      .restaurerDetail(ligneId);
  if (!context.mounted) return;
  if (error != null) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.error));
  } else {
    ref.invalidate(lignePenaliteDetailProvider(ligneId));
    refreshFinances(ref);
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pénalité restaurée')));
  }
}

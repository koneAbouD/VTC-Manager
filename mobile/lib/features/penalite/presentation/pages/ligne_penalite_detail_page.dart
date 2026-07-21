import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/ligne_penalite.dart';
import '../providers/penalite_provider.dart';
import 'encaissement_penalite_form_page.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/detail_premium.dart';
import '../../../../core/widgets/motif_annulation_dialog.dart';
import '../../../../screens/finance/finance_refresh.dart';

class LignePenaliteDetailPage extends ConsumerWidget {
  final int ligneId;
  const LignePenaliteDetailPage({super.key, required this.ligneId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncLigne = ref.watch(lignePenaliteDetailProvider(ligneId));

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: AppHeader(
        title: 'Détail pénalité',
        action: AppHeaderAction(
          icon: Icons.refresh,
          onTap: () => ref.invalidate(lignePenaliteDetailProvider(ligneId)),
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
        PremiumHero(
          amount: estAmende ? fmt.format(ligne.montant) : ligne.typeSanction.label,
          footerIcon: Icons.directions_car_outlined,
          footer: [
            ligne.vehiculeImmatriculation ?? 'Véhicule #${ligne.vehiculeId}',
            if (ligne.chauffeurNomComplet != null) ligne.chauffeurNomComplet!,
          ].join('  ·  '),
          chips: [
            PremiumChip(statutLabel, statutColor),
            if (estAmende) PremiumChip(ligne.typeSanction.label, AppColors.info),
            if (estAmende && restant != null && restant > 0)
              PremiumChip('Restant ${fmt.format(restant)}', AppColors.warning),
          ],
        ),
        const SizedBox(height: 14),

        // ── Infos générales ──────────────────────────────────────────────
        PremiumSection(
          title: 'Sanction',
          icon: Icons.gavel_outlined,
          children: [
            PremiumRow('Type', ligne.typeSanction.label),
            PremiumRow('Pénalité', _typePenaliteLabel(ligne.typePenalite)),
            PremiumRow('Statut', statutLabel, valueColor: statutColor),
            PremiumRow('Véhicule',
                ligne.vehiculeImmatriculation ?? '#${ligne.vehiculeId}'),
            PremiumRow('Chauffeur', ligne.chauffeurNomComplet),
            PremiumRow(
                'Date de faute',
                ligne.dateFaute != null
                    ? dateFmt.format(ligne.dateFaute!)
                    : null),
            PremiumRow('Généré le', dateFmt.format(ligne.dateGeneration)),
            PremiumRow('Commentaire', ligne.commentaire),
            PremiumRow('Motif annulation', ligne.motifAnnulation,
                valueColor: AppColors.error),
          ],
        ),

        // ── Infos spécifiques selon le type ──────────────────────────────
        if (estAmende)
          PremiumSection(
            title: 'Montants',
            icon: Icons.payments_outlined,
            children: [
              PremiumRow('Montant total', fmt.format(ligne.montant)),
              PremiumRow('Encaissé', fmt.format(ligne.montantEncaisse),
                  valueColor: AppColors.success),
              PremiumRow(
                  'Restant',
                  restant != null && restant > 0 ? fmt.format(restant) : null,
                  valueColor: AppColors.warning),
            ],
          ),
        if (ligne.typeSanction == TypeSanctionLigne.buzzer &&
            ligne.dureeSanctionSecondes != null)
          PremiumSection(
            title: 'Buzzer',
            icon: Icons.notifications_active_outlined,
            children: [
              PremiumRow('Durée buzzer', '${ligne.dureeSanctionSecondes}s'),
            ],
          ),
        if (ligne.typeSanction == TypeSanctionLigne.immobilisation)
          PremiumSection(
            title: 'Immobilisation',
            icon: Icons.block_outlined,
            accent: AppColors.error,
            children: [
              PremiumRow(
                  'Durée prévue',
                  ligne.dureeImmobilisationMinutes != null
                      ? '${ligne.dureeImmobilisationMinutes} min'
                      : null),
              PremiumRow(
                  'Début',
                  ligne.dateDebutImmobilisation != null
                      ? dtFmt.format(ligne.dateDebutImmobilisation!)
                      : null),
              PremiumRow(
                  'Fin',
                  ligne.dateFinImmobilisation != null
                      ? dtFmt.format(ligne.dateFinImmobilisation!)
                      : null),
            ],
          ),

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
          PremiumListHeader('Encaissements (${ligne.encaissements.length})'),
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
    final refreshed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => EncaissementPenaliteFormPage(ligne: l)),
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

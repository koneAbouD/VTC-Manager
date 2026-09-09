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
import '../../../../core/widgets/date_filter_dialogs.dart';
import '../../../../core/widgets/detail_premium.dart';
import '../../../../core/widgets/confirmation_restauration_dialog.dart';
import '../../../../core/widgets/motif_annulation_dialog.dart';
import '../../../../core/widgets/reaffectation_chauffeur_sheet.dart';
import '../../../../screens/finance/finance_refresh.dart';
import '../../../../screens/finance/ligne_jumelle_encaissement.dart';

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
        // Dépôt rendu : ni en cours, ni en échec — un état de sortie neutre.
        StatutLigneCotisation.restituee => (ligne.statut.label, AppColors.label),
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
        // Cf. la fiche recette : la valeur porte son affordance, et un cadenas
        // remplace le chevron dès qu'un arrêté a figé le dépôt.
        DetailInfoRowAction(
          Icons.person_outline_rounded,
          'Chauffeur',
          ligne.chauffeurNom ?? 'Chauffeur #${ligne.chauffeurId}',
          accent: const Color(0xFFE65100),
          verrouille: !ligne.reaffectable,
          motifVerrou: ligne.motifNonReaffectable,
          onTap: () => _reaffecter(context, ref),
        ),
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
        // Le serveur dit, versement par versement, si sa date bouge encore :
        // l'écran n'a pas à rejouer la règle des arrêtés, ni à la deviner du
        // statut de la ligne.
        ...ligne.encaissements.map((e) => PremiumEncaissementTile(
              montant: fmt.format(e.montant),
              especes: e.modeEncaissement == ModePaiementCotisation.especes,
              meta:
                  '${e.modeEncaissement.label} · ${dateFmt.format(e.dateEncaissement)}'
                  '${e.reference != null ? ' · ${e.reference}' : ''}',
              commentaire: e.commentaire,
              annule: e.estAnnule,
              motifAnnulation: e.motifAnnulation,
              accent: const Color(0xFFE65100),
              onModifierDate: e.dateModifiable && e.id != null
                  ? () => _modifierDateEncaissement(context, ref, e)
                  : null,
              motifDateNonModifiable: e.motifDateNonModifiable,
            )),
    ]);
  }

  Future<void> _encaisser(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(ligneCotisationRepositoryProvider);
    final immat = ligne.vehiculeImmatriculation ?? 'Véhicule ${ligne.vehiculeId}';
    final nom = ligne.chauffeurNom;

    // Le même versement solde souvent la recette du jour : si elle est encore
    // ouverte, la feuille la propose à cocher.
    final jumelle = await chercherRecetteDuMemeJour(ref, ligne);
    if (!context.mounted) return;

    final ok = await showEncaissementLigneDialog(
      context,
      titre:     ligne.nomCotisation,
      sousTitre: (nom != null && nom.isNotEmpty) ? '$immat - $nom' : immat,
      montantRestant: ligne.montantRestant ??
          (ligne.montantDu - ligne.montantEncaisse),
      couleur: const Color(0xFFE65100),
      icone:   Icons.analytics_outlined,
      jumelle: jumelle,
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

  /// Porte la cotisation au compte d'un autre chauffeur. Une cotisation
  /// encaissée est un dépôt détenu pour lui : c'est son titulaire qui change,
  /// et le serveur refuse dès qu'un arrêté en a rendu tout ou partie.
  Future<void> _reaffecter(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(ligneCotisationRepositoryProvider);
    final fmt = NumberFormat.currency(
        locale: 'fr_FR', symbol: 'XOF', decimalDigits: 0);
    final dateFmt = DateFormat('dd/MM/yyyy');
    final immat =
        ligne.vehiculeImmatriculation ?? 'Véhicule #${ligne.vehiculeId}';

    final ok = await showReaffectationChauffeurSheet(
      context,
      titre: 'Réaffecter la cotisation',
      sousTitre: '${ligne.nomCotisation} · $immat · '
          '${dateFmt.format(ligne.dateCotisation)}',
      chauffeurActuel: ligne.chauffeurNom ?? 'Chauffeur #${ligne.chauffeurId}',
      accent: const Color(0xFFE65100),
      // Cf. la fiche recette : c'est le serveur qui juge et qui compte.
      chargerApercu: () async {
        final res = await repo.getApercuReaffectation(ligneId);
        return res.fold((f) => throw Exception(f.message), (apercu) => apercu);
      },
      decrireImpacts: (impacts, choisi) => [
        ImpactReaffectation('La cotisation « ${ligne.nomCotisation} » de '
            '${fmt.format(impacts.montantCreance)} passe au compte de ${choisi.nom}.'),
        if (impacts.montantEncaisse > 0)
          ImpactReaffectation(
              'Le dépôt déjà versé (${fmt.format(impacts.montantEncaisse)}) devient le sien : '
              "c'est à lui qu'un arrêté le restituera."),
      ],
      onReaffecter: (choisi, motif) async {
        final r = await repo.reaffecterChauffeur(ligneId, choisi.id, motif);
        return r.fold((f) => f.message, (_) => null);
      },
    );

    if (ok == true && context.mounted) {
      ref.invalidate(ligneCotisationDetailProvider(ligneId));
      refreshFinances(ref);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cotisation réaffectée')));
    }
  }

  /// Corrige le jour d'un versement déjà enregistré. Rien d'autre ne bouge :
  /// c'est la date à laquelle le dépôt est réputé détenu, donc l'écriture au
  /// journal, le solde de trésorerie à date et le fonds qu'un arrêté rendra.
  Future<void> _modifierDateEncaissement(BuildContext context, WidgetRef ref,
      EncaissementCotisation encaissement) async {
    // Même borne qu'à la saisie : régulariser la veille reste possible,
    // postdater non — le serveur refuse de toute façon une date à venir.
    final choisie = await showDialog<DateTime>(
      context: context,
      builder: (_) => SingleDatePickerDialog(
        initialDate: encaissement.dateEncaissement,
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
      ),
    );
    if (choisie == null || !context.mounted) return;
    if (DateUtils.isSameDay(choisie, encaissement.dateEncaissement)) return;

    final result = await ref
        .read(ligneCotisationRepositoryProvider)
        .modifierDateEncaissement(ligneId, encaissement.id!, choisie);
    if (!context.mounted) return;
    result.fold(
      (failure) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(failure.message), backgroundColor: AppColors.error)),
      (_) {
        ref.invalidate(ligneCotisationDetailProvider(ligneId));
        refreshFinances(ref);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Date du versement corrigée')));
      },
    );
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

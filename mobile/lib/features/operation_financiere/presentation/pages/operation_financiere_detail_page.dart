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
import '../../../../core/utils/libelle_operation.dart';
import '../../../../core/utils/recu_paiement.dart';
import '../../../../core/utils/whatsapp.dart';
import '../../../versement/presentation/providers/versement_provider.dart';
import '../../../versement/presentation/recu_versement.dart';
import '../../../recu/presentation/envoi_recu.dart';
import '../../../recu/presentation/providers/recu_provider.dart';

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
    //
    // Une écriture d'un versement se lit comme le billet entier : la recette et
    // la cotisation réglées ensemble, « +17 000 XOF » plutôt que la seule part
    // de l'écriture ouverte. Seulement tant qu'elle tient : une écriture
    // extournée, ou une extourne, garde son propre montant — c'est lui que la
    // correction concerne. Le total vient du serveur, qui en retire déjà les
    // imputations extournées.
    final ecritureVivante = !op.estUneExtourne &&
        !op.estExtournee &&
        op.statut != StatutOperation.ANNULEE;
    final versementId = ecritureVivante ? op.versementId : null;
    final versement =
        versementId == null ? null : ref.watch(versementProvider(versementId));
    final montant = versement?.valueOrNull?.total ?? op.montant;
    // Pas de montant partiel le temps de relire la pièce : il contredirait la
    // ligne du journal qui vient d'être touchée. En cas d'échec, la part de
    // l'écriture reste le seul montant sûr.
    final totalEnAttente =
        versement != null && versement.isLoading && !versement.hasValue;

    final isRevenu = op.typeOperation == TypeOperation.REVENU;
    final effetCaisse = isRevenu ? montant : -montant;
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
          titre: totalEnAttente
              ? '…'
              : '$sign${money.format(effetCaisse.abs())}',
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

        // ── Versement (pièce de caisse) ───────────────────────────────────
        //
        // L'écriture fait partie d'un billet qui en a produit une autre : la
        // ventilation montre les deux, ce que le billet vaut encore et ce qui
        // reste dû. Chaque écriture garde, elle, ses propres actions.
        if (op.versementId != null)
          _VersementSection(versementId: op.versementId!, operationId: op.id),

        const SizedBox(height: 8),

        // ── Reçu au chauffeur ─────────────────────────────────────────────
        //
        // Seulement sur ce que le chauffeur a versé — recette, cotisation,
        // pénalité — et seulement si l'écriture tient encore : une extourne,
        // ou l'écriture qu'elle a neutralisée, n'atteste plus aucun paiement.
        // Une dépense de garage ne se « reçoit » pas davantage.
        if (op.estEncaissement &&
            !op.estUneExtourne &&
            !op.estExtournee &&
            op.statut != StatutOperation.ANNULEE)
          PremiumButton(
            label: 'Envoyer le reçu',
            icon: Icons.send_outlined,
            color: AppColors.success,
            filled: false,
            onPressed: () => _envoyerRecu(context, ref),
          ),

        // ── Actions ───────────────────────────────────────────────────────
        //
        // Les deux drapeaux viennent du serveur, qui seul sait ce qu'il
        // accepterait : proposer un bouton menant à un refus certain serait
        // pire que ne pas le proposer du tout.
        //
        // « Modifier » tombe sur une écriture qui ne se retouche pas en place —
        // un encaissement, une dépense de maintenance : leur montant appartient
        // à la créance ou à l'intervention qui les a produits. La voie est
        // l'annulation, qui repositionne la source, puis la ressaisie.
        //
        // « Annuler » tombe sur ce qui est déjà corrigé — une extourne, une
        // écriture extournée ou annulée — et dès qu'un arrêté, période close ou
        // caisse comptée, couvre la date de l'écriture.
        //
        // Les deux peuvent tomber ensemble — une extourne, ou un encaissement
        // d'un mois clos : la barre disparaît alors entièrement plutôt que de
        // laisser une bande vide.
        if (op.annulable || op.modifiable)
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

  /// Fait parvenir au chauffeur le reçu de son versement, par WhatsApp.
  ///
  /// L'application ne fait que rédiger et rediriger : c'est le guichetier qui
  /// envoie depuis WhatsApp. Rien n'est donc enregistré ici — ni date d'envoi,
  /// ni accusé — puisque rien ne revient le confirmer.
  ///
  /// Le reçu part en PDF, joint au message. Sur une écriture d'un versement,
  /// il couvre le billet entier et dit ce qui reste dû ; si le PDF ne peut pas
  /// être préparé, l'écran propose d'envoyer le message seul.
  Future<void> _envoyerRecu(BuildContext context, WidgetRef ref) async {
    final id = op.id;
    if (id == null) return;
    final messenger = ScaffoldMessenger.of(context);

    var recu = RecuPaiement(
      chauffeur: op.chauffeurNom,
      vehicule: op.vehiculeNom,
      lignes: [
        LigneRecu(
          libelle: libelleCreanceEncaissee(
            categorieCode: op.categorieCode,
            categorieLibelle: op.categorieLibelle,
            // La date métier : c'est la journée réglée qui parle au chauffeur,
            // pas le jour où l'écriture a été passée.
            date: op.dateAffichee,
          ),
          montant: op.montant,
        ),
      ],
      modePaiement: op.modePaiement?.libelle,
      date: op.dateOperation,
      reference: op.reference,
    );
    var operationIds = [id];
    var telephone = op.chauffeurTelephone;

    // Une écriture d'un versement : le reçu couvre le billet entier — la
    // recette et la cotisation du jour — et redit ce qui reste dû, que la
    // pièce de caisse connaît et que l'écriture seule ignore. Si la pièce ne
    // se lit pas, le reçu de l'écriture seule reste possible.
    final versementId = op.versementId;
    if (versementId != null) {
      final lu =
          await ref.read(versementRepositoryProvider).getVersement(versementId);
      if (!context.mounted) return;
      final versement = lu.fold((_) => null, (v) => v);
      if (versement != null && versement.actives.isNotEmpty) {
        recu = recuDuVersement(versement);
        operationIds = [for (final i in versement.actives) i.operationId];
        telephone = versement.chauffeurTelephone ?? telephone;
      }
    }

    // Le PDF se prépare au serveur : une seconde ou deux, qu'il faut signaler
    // pour que le bouton ne paraisse pas inerte.
    messenger.showSnackBar(const SnackBar(
        content: Text('Préparation du reçu PDF…'),
        duration: Duration(seconds: 10)));
    final issue = await envoyerRecuPdf(
      recus: ref.read(recuRepositoryProvider),
      operationIds: operationIds,
      recu: recu,
      telephone: telephone,
    );
    messenger.hideCurrentSnackBar();
    if (!context.mounted) return;

    switch (issue) {
      case RecuPartage():
        break;
      case RecuEnregistre(:final emplacement):
        messenger.showSnackBar(SnackBar(
            content: Text('Reçu PDF enregistré'
                '${emplacement == null ? '' : ' ($emplacement)'} : '
                'joignez-le au message dans WhatsApp.')));
      case RecuPdfIndisponible(:final motif):
        final message = composerRecu(recu);
        final numero = telephone;
        messenger.showSnackBar(SnackBar(
          content: Text('Le reçu PDF n\'a pas pu être préparé : $motif'),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: 'Message seul',
            textColor: Colors.white,
            onPressed: () => _ouvrirWhatsApp(context, numero, message),
          ),
        ));
    }
  }

  Future<void> _ouvrirWhatsApp(
      BuildContext context, String? telephone, String message) async {
    try {
      await ouvrirWhatsApp(telephone: telephone, message: message);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("WhatsApp n'a pas pu être ouvert sur cet appareil."),
          backgroundColor: AppColors.error));
    }
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

// ── Versement ──────────────────────────────────────────────────────────────

/// La pièce de caisse dont l'écriture fait partie : ses imputations, ce que le
/// billet vaut encore, ce qui reste dû. Relue au serveur — l'écriture ouverte
/// ne connaît ni sa sœur ni les créances qu'elles soldent.
class _VersementSection extends ConsumerWidget {
  final String versementId;
  final int? operationId;

  const _VersementSection({required this.versementId, required this.operationId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final money =
        NumberFormat.currency(locale: 'fr_FR', symbol: 'XOF', decimalDigits: 0);
    final jour = DateFormat('dd/MM/yyyy', 'fr_FR');

    return ref.watch(versementProvider(versementId)).when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: LinearProgressIndicator(minHeight: 2),
          ),
          // Un complément : son absence ne doit pas masquer l'écriture.
          error: (_, __) => const SizedBox.shrink(),
          data: (v) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 2),
              DetailLabel(Icons.receipt_long_outlined,
                  'Versement du ${jour.format(v.dateEncaissement)}'),
              DetailInfoCard(children: [
                for (final i in v.imputations)
                  DetailInfoRow(
                    // L'écriture ouverte se distingue de sa sœur.
                    i.operationId == operationId
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    '${i.libelle ?? 'Imputation'}'
                    '${i.dateReference != null ? ' du ${jour.format(i.dateReference!)}' : ''}',
                    i.annulee
                        ? '${money.format(i.montant)} · annulée'
                        : money.format(i.montant),
                  ),
                DetailInfoRow(Icons.functions_rounded, 'Total du billet',
                    money.format(v.total)),
                DetailInfoRow(Icons.schedule_outlined, 'Reste dû',
                    v.resteDu == null ? null : money.format(v.resteDu)),
              ]),
            ],
          ),
        );
  }
}

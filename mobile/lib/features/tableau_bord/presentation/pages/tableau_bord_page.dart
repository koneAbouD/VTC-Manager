import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_error_banner.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/date_filter_dialogs.dart';
import '../../../../core/widgets/responsive_field_row.dart'
    show kFormPhoneBreakpoint;
import '../../data/models/tableau_bord_model.dart';
import '../providers/tableau_bord_provider.dart';
import '../widgets/tb_briques.dart';
import '../widgets/tb_tendance.dart';

/// Tableau de bord de supervision.
///
/// **La page répond à quatre questions, dans l'ordre où un exploitant se les
/// pose** : est-ce que je gagne de l'argent (résultat), est-ce que l'argent
/// rentre (cash), est-ce que mon parc produit (flotte), qu'est-ce qui menace la
/// suite (alertes). Ce n'est pas un empilement de chiffres : chaque bloc a un
/// chiffre dominant, ses ratios de contexte, puis son détail.
///
/// Tous les montants viennent des états déjà publiés — compte de résultat,
/// balance âgée, marges par véhicule, état de parc — assemblés côté backend en
/// un seul appel. Deux écrans ne peuvent donc pas donner deux chiffres.
class TableauBordPage extends ConsumerWidget {
  const TableauBordPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cadrage = ref.watch(tableauBordCadrageProvider);
    final asyncData = ref.watch(tableauBordProvider);
    final isWide = MediaQuery.sizeOf(context).width >= kFormPhoneBreakpoint;

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: AppHeader(
        title: 'Tableau de bord',
        action: _BoutonPeriode(cadrage: cadrage),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async => ref.invalidate(tableauBordProvider),
        child: asyncData.when(
          loading: () => const Center(
              child: Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: CircularProgressIndicator())),
          error: (e, _) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppErrorBanner(message: 'Chargement impossible : $e'),
              const SizedBox(height: 12),
              Center(
                child: FilledButton.icon(
                  onPressed: () => ref.invalidate(tableauBordProvider),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Réessayer'),
                ),
              ),
            ],
          ),
          data: (data) => ListView(
            padding: EdgeInsets.fromLTRB(
                16, 12, 16, 24 + MediaQuery.of(context).padding.bottom),
            children: [
              _BandeauPeriode(data: data),
              const SizedBox(height: 12),
              _SectionFinance(data: data, isWide: isWide),
              const SizedBox(height: 12),
              _SectionCash(data: data, isWide: isWide),
              const SizedBox(height: 12),
              _SectionFlotte(data: data, isWide: isWide),
              const SizedBox(height: 12),
              _SectionAlertes(alertes: data.alertes, isWide: isWide),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sélecteur de mois posé dans l'en-tête.
class _BoutonPeriode extends ConsumerWidget {
  final TableauBordCadrage cadrage;
  const _BoutonPeriode({required this.cadrage});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () async {
        final choix = await showDialog<DateTime>(
          context: context,
          builder: (_) => MonthPickerDialog(
              initialYear: cadrage.annee, initialMonth: cadrage.mois),
        );
        if (choix == null) return;
        ref.read(tableauBordCadrageProvider.notifier).state =
            cadrage.copyWith(annee: choix.year, mois: choix.month);
      },
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.headerButton,
          borderRadius: BorderRadius.circular(19),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_month_outlined,
                size: 15, color: AppColors.label),
            const SizedBox(width: 6),
            Text(_libelleCourt(cadrage.mois, cadrage.annee),
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.dark)),
          ],
        ),
      ),
    );
  }

  /// « mai 2026 », « sept. 2026 » : les mois courts gardent leur nom entier,
  /// les longs sont abrégés à trois lettres suivies d'un point. Tronquer à
  /// longueur fixe sortirait des noms de trois lettres (« mai », « mars »).
  static String _libelleCourt(int mois, int annee) {
    final nom = kMoisNoms[mois - 1];
    return nom.length <= 4 ? '$nom $annee' : '${nom.substring(0, 4)}. $annee';
  }
}

/// Bandeau de cadrage : période lue, avancement, base comptable.
///
/// La base n'est pas un réglage cosmétique. En CAISSE on lit l'argent entré et
/// sorti ; en ENGAGEMENT ce qui était dû, encaissé ou non. Sur un parc où les
/// versements traînent, les deux lectures divergent — et c'est justement cet
/// écart que mesure le taux de recouvrement plus bas.
class _BandeauPeriode extends ConsumerWidget {
  final TableauBordModel data;
  const _BandeauPeriode({required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = data.periode;
    final cadrage = ref.watch(tableauBordCadrageProvider);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.label,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.dark)),
                const SizedBox(height: 2),
                Text(
                  p.cloture
                      ? 'Période close — chiffres définitifs'
                      : (p.moisEnCours
                          ? 'Mois en cours — ${p.joursEcoules} j sur ${p.joursPeriode}'
                          : 'Mois complet — non clôturé'),
                  style: const TextStyle(fontSize: 11.5, color: AppColors.hint),
                ),
              ],
            ),
          ),
          _BasculeBase(
            base: cadrage.base,
            onChange: (base) => ref
                .read(tableauBordCadrageProvider.notifier)
                .state = cadrage.copyWith(base: base),
          ),
        ],
      ),
    );
  }
}

/// Bascule CAISSE / ENGAGEMENT, dans le style des pastilles d'onglets.
class _BasculeBase extends StatelessWidget {
  final String base;
  final ValueChanged<String> onChange;

  const _BasculeBase({required this.base, required this.onChange});

  @override
  Widget build(BuildContext context) {
    Widget pilule(String valeur, String libelle, String aide) {
      final actif = base == valeur;
      return Tooltip(
        message: aide,
        triggerMode: TooltipTriggerMode.longPress,
        child: GestureDetector(
          onTap: () => onChange(valeur),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: actif ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(libelle,
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: actif ? Colors.white : AppColors.label)),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.headerButton,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          pilule('CAISSE', 'Caisse',
              'Base caisse : ce qui est réellement entré et sorti sur la période.'),
          pilule('ENGAGEMENT', 'Dû',
              'Base engagement : ce qui était dû sur la période, encaissé ou non.'),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Bloc 1 — Santé financière
// ─────────────────────────────────────────────────────────────────────────

class _SectionFinance extends StatelessWidget {
  final TableauBordModel data;
  final bool isWide;

  const _SectionFinance({required this.data, required this.isWide});

  @override
  Widget build(BuildContext context) {
    final f = data.finance;

    return TbSection(
      icone: Icons.account_balance_wallet_outlined,
      titre: 'Santé financière',
      question: 'Est-ce que je gagne de l\'argent ?',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TbKpiPrincipal(
            label: 'Résultat de gestion',
            valeur: tbMontantCourt(f.resultatGestion),
            couleur: tbCouleurMontant(f.resultatGestion),
            variationPct: f.variationResultatPct,
            commentaire: _commentaireResultat(f),
          ),
          const SizedBox(height: 14),
          TbGrilleTuiles(isWide: isWide, tuiles: [
            TbKpiTuile(
              label: 'Produits',
              valeur: tbMontantCourt(f.produits),
              sousLabel: f.variationProduitsPct == null
                  ? null
                  : '${f.variationProduitsPct! >= 0 ? '+' : ''}'
                      '${f.variationProduitsPct!.toStringAsFixed(1).replaceAll('.', ',')} % vs M-1',
              aide: 'Produits d\'exploitation de la période : recettes, '
                  'pénalités et autres revenus, hors dépôts de cotisation.',
            ),
            TbKpiTuile(
              label: 'Charges',
              valeur: tbMontantCourt(f.chargesTotales),
              sousLabel: '${tbPourcent(f.tauxCharges)} des produits',
              couleur: tbCouleurTauxDecroissant(f.tauxCharges, bon: 60, moyen: 85),
              aide: 'Charges variables (carburant, entretien…) et charges '
                  'fixes (assurances, salaires…) de la période.',
            ),
            TbKpiTuile(
              label: 'Taux de marge',
              valeur: tbPourcent(f.tauxMargeVariable),
              couleur: tbCouleurTauxCroissant(f.tauxMargeVariable,
                  bon: 50, moyen: 30),
              sousLabel: 'après charges variables',
              aide: 'Marge sur coûts variables rapportée aux produits : ce que '
                  'chaque franc encaissé laisse pour couvrir les charges fixes.',
            ),
            TbKpiTuile(
              label: 'Point mort',
              valeur:
                  f.pointMort == null ? '—' : tbMontantCourt(f.pointMort!),
              couleur: tbCouleurTauxCroissant(f.tauxCouverturePointMort,
                  bon: 100, moyen: 80),
              sousLabel: f.tauxCouverturePointMort == null
                  ? 'marge insuffisante'
                  : 'couvert à ${tbPourcent(f.tauxCouverturePointMort, decimales: 0)}',
              aide: 'Chiffre d\'affaires à partir duquel les charges fixes '
                  'sont couvertes. Au-dessus, chaque franc encaissé est du '
                  'bénéfice ; en dessous, la période perd de l\'argent.',
            ),
          ]),
          const SizedBox(height: 14),
          const TbFilet(),
          TbLigneDetail(
              libelle: 'Produits d\'exploitation',
              valeur: tbMontant(f.produits)),
          const TbFilet(),
          TbLigneDetail(
              libelle: 'Charges variables', valeur: '− ${tbMontant(f.chargesVariables)}'),
          const TbFilet(),
          TbLigneDetail(
              libelle: 'Marge sur coûts variables',
              valeur: tbMontant(f.margeSurCoutsVariables),
              couleurValeur: tbCouleurMontant(f.margeSurCoutsVariables),
              forte: true),
          const TbFilet(),
          TbLigneDetail(
              libelle: 'Charges fixes', valeur: '− ${tbMontant(f.chargesFixes)}'),
          const TbFilet(),
          TbLigneDetail(
              libelle: 'Excédent brut d\'exploitation',
              valeur: tbMontant(f.excedentBrutExploitation),
              couleurValeur: tbCouleurMontant(f.excedentBrutExploitation),
              forte: true),
          const TbFilet(),
          TbLigneDetail(
              libelle: 'Amortissements',
              sousLibelle: 'Usure des véhicules sur la période',
              valeur: '− ${tbMontant(f.amortissements)}'),
          const TbFilet(),
          TbLigneDetail(
              libelle: 'Dotation aux provisions',
              sousLibelle: 'Perte attendue sur les impayés',
              valeur: '− ${tbMontant(f.dotationProvisions)}'),
          const TbFilet(),
          TbLigneDetail(
              libelle: 'Résultat de gestion',
              valeur: tbMontant(f.resultatGestion),
              couleurValeur: tbCouleurMontant(f.resultatGestion),
              forte: true),
          const SizedBox(height: 16),
          TbTendance(
              serie: f.serie,
              annee: data.periode.annee,
              mois: data.periode.mois),
        ],
      ),
    );
  }

  /// Lecture en clair du résultat : un chiffre seul ne dit pas quoi en faire.
  String _commentaireResultat(SanteFinanciere f) {
    if (f.produits == 0) return 'Aucun produit enregistré sur la période';
    if (f.resultatGestion < 0) {
      final manque = f.pointMort == null
          ? null
          : (f.pointMort! - f.produits).clamp(0, double.infinity).toDouble();
      return manque == null || manque <= 0
          ? 'La période consomme plus qu\'elle ne produit'
          : 'Il manque ${tbMontantCourt(manque)} de produits pour l\'équilibre';
    }
    return 'Après amortissements et provisions';
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Bloc 2 — Cash et créances
// ─────────────────────────────────────────────────────────────────────────

class _SectionCash extends StatelessWidget {
  final TableauBordModel data;
  final bool isWide;

  const _SectionCash({required this.data, required this.isWide});

  @override
  Widget build(BuildContext context) {
    final c = data.cash;

    return TbSection(
      icone: Icons.savings_outlined,
      titre: 'Encaissement et créances',
      question: 'Est-ce que l\'argent rentre ?',
      accent: const Color(0xFF1565C0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TbKpiPrincipal(
            label: 'Trésorerie disponible',
            valeur: tbMontantCourt(c.tresorerieDisponible),
            couleur: tbCouleurMontant(c.tresorerieDisponible),
            commentaire: 'Solde de tous les comptes actifs, à l\'instant',
          ),
          const SizedBox(height: 14),
          TbGrilleTuiles(isWide: isWide, tuiles: [
            TbKpiTuile(
              label: 'Taux de recouvrement',
              valeur: tbPourcent(c.tauxRecouvrement),
              couleur: tbCouleurTauxCroissant(c.tauxRecouvrement,
                  bon: 95, moyen: 80),
              sousLabel: c.resteAEncaisserPeriode > 0
                  ? '${tbMontantCourt(c.resteAEncaisserPeriode)} non encaissés'
                  : 'tout est rentré',
              aide: 'Part des produits dus de la période effectivement '
                  'encaissée. Le complément a été facturé mais dort en créance.',
            ),
            TbKpiTuile(
              label: 'Créances',
              valeur: tbMontantCourt(c.creancesBrutes),
              sousLabel: '${c.nbChauffeursDebiteurs} chauffeur'
                  '${c.nbChauffeursDebiteurs > 1 ? 's' : ''}',
              aide: 'Encours total dû par les chauffeurs, toutes périodes '
                  'confondues : recettes, cotisations et pénalités impayées.',
            ),
            TbKpiTuile(
              label: 'Dont > 30 jours',
              valeur: tbPourcent(c.partCreancesRisque),
              couleur: tbCouleurTauxDecroissant(c.partCreancesRisque,
                  bon: 10, moyen: 25),
              sousLabel: tbMontantCourt(c.creancesPlus30Jours),
              aide: 'Part de l\'encours qui a plus de 30 jours. Plus une '
                  'somme dort, moins elle rentre : c\'est la fraction à risque.',
            ),
            TbKpiTuile(
              label: 'Délai de recouvrement',
              valeur: c.dso == null
                  ? '—'
                  : '${c.dso!.toStringAsFixed(0)} j',
              couleur: tbCouleurTauxDecroissant(c.dso, bon: 7, moyen: 20),
              sousLabel: 'de production en attente',
              aide: 'Nombre de jours de production que représente l\'encours '
                  '(DSO). Au-delà du rythme de versement attendu, le décalage '
                  'devient un impayé.',
            ),
          ]),
          const SizedBox(height: 14),
          _BarreAnciennete(cash: c),
          const SizedBox(height: 14),
          const TbFilet(),
          TbLigneDetail(
              libelle: 'Créances brutes', valeur: tbMontant(c.creancesBrutes)),
          const TbFilet(),
          TbLigneDetail(
              libelle: 'Provision sur créances',
              sousLibelle: 'Perte probable, par ancienneté',
              valeur: '− ${tbMontant(c.provisionCreances)}'),
          const TbFilet(),
          TbLigneDetail(
              libelle: 'Créances nettes',
              sousLibelle: 'Ce qu\'on espère raisonnablement encaisser',
              valeur: tbMontant(c.creancesNettes),
              forte: true),
          if (c.aReverserEtat > 0) ...[
            const TbFilet(),
            TbLigneDetail(
                libelle: 'À reverser à l\'État',
                sousLibelle: 'Contraventions encaissées, non reversées',
                valeur: tbMontant(c.aReverserEtat),
                couleurValeur: kTbOrange),
          ],
          if (c.topDebiteurs.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Principaux débiteurs',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.label)),
            const SizedBox(height: 8),
            for (final d in c.topDebiteurs) _LigneDebiteur(debiteur: d),
          ],
        ],
      ),
    );
  }
}

/// Répartition de l'encours par ancienneté : une barre segmentée vaut mieux
/// que trois nombres, parce que c'est la *proportion* de vieux qui alerte.
class _BarreAnciennete extends StatelessWidget {
  final CashCreances cash;
  const _BarreAnciennete({required this.cash});

  @override
  Widget build(BuildContext context) {
    final total = cash.creancesBrutes;
    if (total <= 0) {
      return const Text('Aucune créance ouverte',
          style: TextStyle(fontSize: 12, color: AppColors.hint));
    }

    final segments = <(String, double, Color)>[
      ('0 – 7 j', cash.creances0a7Jours, kTbVert),
      ('8 – 30 j', cash.creances8a30Jours, kTbOrange),
      ('> 30 j', cash.creancesPlus30Jours, kTbRouge),
    ].where((s) => s.$2 > 0).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 10,
            child: Row(
              children: [
                for (var i = 0; i < segments.length; i++) ...[
                  // Filet de surface entre deux aplats : sans lui, deux
                  // segments voisins se lisent comme un seul bloc.
                  if (i > 0) const SizedBox(width: 2),
                  Expanded(
                    flex: (segments[i].$2 / total * 1000).round().clamp(1, 1000),
                    child: ColoredBox(color: segments[i].$3),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            for (final s in segments)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                          color: s.$3, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 5),
                  Text('${s.$1}  ',
                      style:
                          const TextStyle(fontSize: 11, color: AppColors.label)),
                  Text(tbMontantCourt(s.$2),
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.dark)),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class _LigneDebiteur extends StatelessWidget {
  final Debiteur debiteur;
  const _LigneDebiteur({required this.debiteur});

  @override
  Widget build(BuildContext context) {
    final ancien = debiteur.plus30Jours > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(debiteur.nom.isEmpty ? 'Chauffeur' : debiteur.nom,
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.dark),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(
                  ancien
                      ? '${debiteur.nbLignes} document${debiteur.nbLignes > 1 ? 's' : ''}'
                          ' · ${tbMontantCourt(debiteur.plus30Jours)} de plus de 30 j'
                      : '${debiteur.nbLignes} document${debiteur.nbLignes > 1 ? 's' : ''}',
                  style: TextStyle(
                      fontSize: 10.5,
                      color: ancien ? kTbRouge : AppColors.hint),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(tbMontant(debiteur.total),
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.dark)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Bloc 3 — Performance de la flotte
// ─────────────────────────────────────────────────────────────────────────

class _SectionFlotte extends StatelessWidget {
  final TableauBordModel data;
  final bool isWide;

  const _SectionFlotte({required this.data, required this.isWide});

  @override
  Widget build(BuildContext context) {
    final v = data.flotte;

    return TbSection(
      icone: Icons.directions_car_filled_outlined,
      titre: 'Performance du parc',
      question: 'Est-ce que mes véhicules produisent ?',
      accent: const Color(0xFF6A1B9A),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TbKpiPrincipal(
            label: 'Revenu par véhicule actif',
            valeur: tbMontantCourt(v.revenuParVehiculeActif),
            couleur: AppColors.dark,
            commentaire: '${v.parcActif} véhicule${v.parcActif > 1 ? 's' : ''} '
                'au parc · ${tbMontantCourt(v.revenuJournalierMoyen)} par jour et par véhicule',
          ),
          const SizedBox(height: 12),
          // Avertissement de lecture : disponibilité et utilisation sont l'état
          // du parc maintenant, pas une moyenne de la période. Sur un mois
          // passé, les confondre ferait juger mai avec la flotte d'aujourd'hui.
          const Row(
            children: [
              Icon(Icons.schedule_rounded, size: 12, color: AppColors.hint),
              SizedBox(width: 5),
              Expanded(
                child: Text(
                    'Occupation du parc à l\'instant ; montants sur la période',
                    style: TextStyle(fontSize: 10.5, color: AppColors.hint)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TbGrilleTuiles(isWide: isWide, tuiles: [
            TbKpiTuile(
              label: 'Disponibilité',
              valeur: tbPourcent(v.tauxDisponibilite),
              couleur: tbCouleurTauxCroissant(v.tauxDisponibilite),
              sousLabel: '${v.enService + v.disponibles} / ${v.parcActif} mobilisables',
              aide: 'Part du parc actif en état de rouler, à cet instant : en '
                  'service ou disponible. Le reste est en maintenance ou '
                  'immobilisé.',
            ),
            TbKpiTuile(
              label: 'Utilisation',
              valeur: tbPourcent(v.tauxUtilisation),
              couleur: tbCouleurTauxCroissant(v.tauxUtilisation),
              sousLabel: '${v.enService} en service',
              aide: 'Part du parc actif effectivement affectée à un chauffeur. '
                  'Un véhicule disponible mais sans chauffeur ne produit rien.',
            ),
            TbKpiTuile(
              label: 'Immobilisation',
              valeur: tbPourcent(v.tauxImmobilisation),
              couleur: tbCouleurTauxDecroissant(v.tauxImmobilisation,
                  bon: 5, moyen: 15),
              sousLabel: '${v.joursImmobilisation} jour'
                  '${v.joursImmobilisation > 1 ? 's' : ''} d\'arrêt',
              aide: 'Jours d\'arrêt cumulés rapportés au potentiel du parc '
                  '(véhicules × jours). Mesure le temps de flotte perdu.',
            ),
            TbKpiTuile(
              label: 'Manque à gagner',
              valeur: tbMontantCourt(v.manqueAGagnerImmobilisation),
              couleur: v.manqueAGagnerImmobilisation > 0 ? kTbRouge : kTbNeutre,
              sousLabel: 'arrêts valorisés',
              aide: 'Jours d\'arrêt valorisés au revenu journalier moyen d\'un '
                  'véhicule : ce que l\'immobilisation a coûté en produits.',
            ),
          ]),
          if (v.nbVehiculesEvalues > 0) ...[
            const SizedBox(height: 14),
            const TbFilet(),
            TbLigneDetail(
              libelle: 'Marge nette moyenne par véhicule',
              sousLibelle: 'Après charges variables et amortissement',
              valeur: tbMontant(v.margeNetteMoyenne),
              couleurValeur: tbCouleurMontant(v.margeNetteMoyenne),
              forte: true,
            ),
            const TbFilet(),
            TbLigneDetail(
              libelle: 'Véhicules déficitaires',
              sousLibelle: 'Ils coûtent plus qu\'ils ne rapportent',
              valeur: '${v.nbVehiculesDeficitaires} / ${v.nbVehiculesEvalues}',
              couleurValeur:
                  v.nbVehiculesDeficitaires > 0 ? kTbRouge : kTbVert,
            ),
          ],
          if (v.meilleurs.isNotEmpty) ...[
            const SizedBox(height: 16),
            _Palmares(titre: 'Meilleures marges', vehicules: v.meilleurs),
          ],
          if (v.moinsBons.isNotEmpty) ...[
            const SizedBox(height: 12),
            _Palmares(titre: 'Marges les plus faibles', vehicules: v.moinsBons),
          ],
        ],
      ),
    );
  }
}

class _Palmares extends StatelessWidget {
  final String titre;
  final List<VehiculePerformance> vehicules;

  const _Palmares({required this.titre, required this.vehicules});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titre,
            style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.label)),
        const SizedBox(height: 8),
        for (final v in vehicules)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(v.immatriculation,
                          style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.dark)),
                      Text(
                        v.joursImmobilisation > 0
                            ? '${tbMontantCourt(v.produits)} de produits · '
                                '${v.joursImmobilisation} j d\'arrêt'
                            : '${tbMontantCourt(v.produits)} de produits',
                        style: const TextStyle(
                            fontSize: 10.5, color: AppColors.hint),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(tbMontant(v.margeNette),
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: tbCouleurMontant(v.margeNette))),
              ],
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Bloc 4 — Alertes
// ─────────────────────────────────────────────────────────────────────────

class _SectionAlertes extends StatelessWidget {
  final AlertesTableauBord alertes;
  final bool isWide;

  const _SectionAlertes({required this.alertes, required this.isWide});

  @override
  Widget build(BuildContext context) {
    final items = <(String, int, IconData, String)>[
      ('Documents à renouveler', alertes.documentsExpirantSous30Jours,
          Icons.description_outlined, 'expirent sous 30 jours'),
      ('Permis expirés', alertes.permisExpires, Icons.badge_outlined,
          'chauffeurs bloqués'),
      ('Maintenances dues', alertes.maintenancesDuesSous7Jours,
          Icons.build_outlined, 'sous 7 jours'),
      ('Vidanges dues', alertes.vidangesDues, Icons.opacity_outlined,
          'date ou kilométrage atteint'),
      ('Arrêts longs', alertes.immobilisationsLongues, Icons.timer_off_outlined,
          'plus de 15 jours'),
      ('Sans chauffeur', alertes.vehiculesSansChauffeur,
          Icons.person_off_outlined, 'véhicules non affectés'),
    ];
    final ouverts = items.where((i) => i.$2 > 0).toList();

    return TbSection(
      icone: Icons.warning_amber_rounded,
      titre: 'Points de vigilance',
      question: 'Qu\'est-ce qui menace la suite ?',
      accent: alertes.total > 0 ? kTbOrange : AppColors.primary,
      child: ouverts.isEmpty
          ? const Row(
              children: [
                Icon(Icons.check_circle_outline_rounded,
                    size: 18, color: kTbVert),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Aucun point de vigilance ouvert',
                      style:
                          TextStyle(fontSize: 12.5, color: AppColors.label)),
                ),
              ],
            )
          : TbGrilleTuiles(
              isWide: isWide,
              tuiles: [
                for (final a in ouverts)
                  _TuileAlerte(
                      libelle: a.$1,
                      nombre: a.$2,
                      icone: a.$3,
                      precision: a.$4),
              ],
            ),
    );
  }
}

class _TuileAlerte extends StatelessWidget {
  final String libelle;
  final int nombre;
  final IconData icone;
  final String precision;

  const _TuileAlerte({
    required this.libelle,
    required this.nombre,
    required this.icone,
    required this.precision,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: kTbOrange.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kTbOrange.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icone, size: 14, color: kTbOrange),
              const SizedBox(width: 6),
              Text('$nombre',
                  style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: kTbOrange,
                      height: 1.1)),
            ],
          ),
          const SizedBox(height: 4),
          Text(libelle,
              style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.dark),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          Text(precision,
              style: const TextStyle(fontSize: 10, color: AppColors.hint),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

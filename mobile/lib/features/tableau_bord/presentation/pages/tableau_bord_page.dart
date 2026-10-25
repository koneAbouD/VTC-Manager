import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_error_banner.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/date_filter_dialogs.dart';
import '../../../../core/widgets/responsive_field_row.dart'
    show kFormPhoneBreakpoint;
import '../../../../screens/home_nav_provider.dart';
import '../../../contravention/presentation/pages/contraventions_hub_page.dart';
import '../../../maintenance/presentation/pages/lignes_maintenance_page.dart';
import '../../../tresorerie/presentation/pages/compte_resultat_page.dart';
import '../../../tresorerie/presentation/pages/creances_chauffeur_page.dart';
import '../../../vehicule/presentation/pages/vehicule_detail_page.dart';
import '../../data/models/tableau_bord_model.dart';
import '../providers/tableau_bord_provider.dart';
import '../widgets/tb_briques.dart';
import '../widgets/tb_navigation.dart';
import '../widgets/tb_tendance.dart';

/// Tableau de bord de supervision.
///
/// **Une synthèse qui mène quelque part.** La page ne garde que les chiffres
/// qui appellent une décision, dans l'ordre où on les cherche : la journée,
/// ce qui est à traiter, le résultat du mois, l'argent qui rentre, le parc.
/// Chaque chiffre est un lien vers l'écran qui en tient le détail — la
/// cascade du compte de résultat, la balance âgée, l'état de parc ne sont pas
/// recopiées ici.
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
          data: (data) {
            final cash = _SectionCash(cash: data.cash);
            final parc = _SectionParc(flotte: data.flotte);
            return ListView(
              padding: EdgeInsets.fromLTRB(
                  16, 12, 16, 24 + MediaQuery.of(context).padding.bottom),
              children: [
                _BandeauPeriode(data: data),
                const SizedBox(height: 14),
                _BandeauEssentiel(data: data, isWide: isWide),
                const SizedBox(height: 14),
                _SectionATraiter(
                    alertes: data.alertes, aReverserEtat: data.cash.aReverserEtat),
                const SizedBox(height: 14),
                _SectionResultat(data: data),
                const SizedBox(height: 14),
                // En écran large, l'argent et le parc se lisent côte à côte.
                if (isWide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: cash),
                      const SizedBox(width: 14),
                      Expanded(child: parc),
                    ],
                  )
                else ...[
                  cash,
                  const SizedBox(height: 14),
                  parc,
                ],
              ],
            );
          },
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
            Icon(Icons.calendar_month_outlined,
                size: 15, color: AppColors.label),
            const SizedBox(width: 6),
            Text(_libelleCourt(cadrage.mois, cadrage.annee),
                style: TextStyle(
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
                    style: TextStyle(
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
                  style: TextStyle(fontSize: 11.5, color: AppColors.hint),
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
// L'essentiel — les quatre montants qu'on vient chercher
// ─────────────────────────────────────────────────────────────────────────

/// Les quatre montants qu'on vient chercher — encaissé, manquant, dépenses,
/// bénéfice net —, posés avant tout bloc d'analyse : celui du jour en gros,
/// celui du mois juste dessous. Chaque carte ouvre la liste qui le compose.
///
/// Aucun chiffre n'est calculé ici. Le jour vient du bloc `journee` du
/// backend ; le mois est repris tel quel des blocs cash et compte de
/// résultat, pour qu'un total en tête ne contredise jamais son détail.
class _BandeauEssentiel extends ConsumerWidget {
  final TableauBordModel data;
  final bool isWide;

  const _BandeauEssentiel({required this.data, required this.isWide});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final j = data.journee;
    final f = data.finance;
    final c = data.cash;
    final mois = data.periode.label;

    // Un manquant négatif : les versements du jour ont aussi soldé des
    // arriérés. On n'affiche pas « -20 k manquant », on dit ce qui s'est passé.
    final rattrapage = j.manquant < 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              Icon(Icons.today_outlined, size: 16, color: AppColors.label),
              const SizedBox(width: 6),
              Text(_libelleJour(j.date, data.periode.moisEnCours),
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.label)),
            ],
          ),
        ),
        TbGrilleTuiles(isWide: isWide, tuiles: [
          _CarteEssentiel(
            icone: Icons.payments_outlined,
            label: 'Recettes encaissées',
            valeur: tbMontantCourt(j.encaisse),
            couleur: kTbVert,
            sousLabel: 'versé ce jour',
            libelleMois: mois,
            valeurMois: tbMontantCourt(c.produitsEncaissesPeriode),
            aide: 'Argent réellement versé : recettes, pénalités et autres '
                'produits d\'exploitation encaissés, arriérés compris.',
            onTap: () => tbOuvrirFinances(context, ref, FinanceTab.operations,
                typeOperation: 'REVENU'),
          ),
          _CarteEssentiel(
            icone: Icons.money_off_outlined,
            label: 'Manquant',
            valeur: tbMontantCourt(rattrapage ? 0 : j.manquant),
            couleur: j.manquant > 0 ? kTbRouge : kTbVert,
            sousLabel: rattrapage
                ? '+${tbMontantCourt(-j.manquant)} d\'arriérés rattrapés'
                : (j.manquant > 0 ? 'dû, pas encore versé' : 'aucun manquant'),
            libelleMois: mois,
            valeurMois: tbMontantCourt(c.resteAEncaisserPeriode),
            aide: 'Produits dus et pas encore encaissés : l\'écart entre ce '
                'que les chauffeurs devaient et ce qu\'ils ont versé.',
            onTap: () => tbOuvrirFinances(context, ref, FinanceTab.creances),
          ),
          _CarteEssentiel(
            icone: Icons.shopping_cart_outlined,
            label: 'Dépenses',
            valeur: tbMontantCourt(j.depenses),
            couleur: kTbOrange,
            sousLabel: 'sorties du jour',
            libelleMois: mois,
            valeurMois: tbMontantCourt(f.chargesTotales),
            aide: 'Charges variables (carburant, entretien…) et charges fixes '
                '(assurances, salaires…), hors amortissements.',
            onTap: () => tbOuvrirFinances(context, ref, FinanceTab.operations,
                typeOperation: 'DEPENSE'),
          ),
          _CarteEssentiel(
            icone: Icons.trending_up_rounded,
            label: 'Bénéfice net',
            valeur: tbMontantCourt(j.beneficeNet),
            couleur: j.beneficeNet < 0 ? kTbRouge : AppColors.info,
            sousLabel: j.beneficeNet < 0 ? 'perte du jour' : 'après toutes charges',
            libelleMois: mois,
            valeurMois: tbMontantCourt(f.resultatGestion),
            aide: 'Produits moins charges et amortissements. La dotation aux '
                'provisions ne se mesure qu\'au mois : elle ne pèse que sur '
                'le chiffre mensuel.',
            onTap: () => tbPousser(context, const CompteResultatPage()),
          ),
        ]),
      ],
    );
  }

  /// « Aujourd'hui » pour le mois en cours ; sinon la date lue, qui est le
  /// dernier jour du mois choisi.
  static String _libelleJour(DateTime? date, bool moisEnCours) {
    if (moisEnCours || date == null) return 'Aujourd\'hui';
    return 'Le ${DateFormat('d MMMM', 'fr_FR').format(date)}';
  }
}

/// Carte mise en évidence : fond teinté de sa couleur, pictogramme, montant
/// du jour en gros, total du mois en pied, chevron du lien. Plus appuyée
/// qu'une [TbKpiTuile], parce que c'est le premier regard sur la page.
class _CarteEssentiel extends StatelessWidget {
  final IconData icone;
  final String label;
  final String valeur;
  final Color couleur;
  final String sousLabel;
  final String libelleMois;
  final String valeurMois;
  final String aide;
  final VoidCallback onTap;

  const _CarteEssentiel({
    required this.icone,
    required this.label,
    required this.valeur,
    required this.couleur,
    required this.sousLabel,
    required this.libelleMois,
    required this.valeurMois,
    required this.aide,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return tbAvecAide(
      aide,
      Material(
        color: couleur.withValues(alpha: 0.07),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: couleur.withValues(alpha: 0.25)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: couleur.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icone, size: 16, color: couleur),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(label,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.label),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        size: 18, color: couleur.withValues(alpha: 0.7)),
                  ],
                ),
                const SizedBox(height: 10),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(valeur,
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: couleur,
                          height: 1.1)),
                ),
                const SizedBox(height: 4),
                Text(sousLabel,
                    style: TextStyle(fontSize: 10.5, color: AppColors.hint),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 8, right: 4),
                  child: Divider(
                      height: 1, color: couleur.withValues(alpha: 0.2)),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(libelleMois,
                            style: TextStyle(
                                fontSize: 10.5, color: AppColors.hint),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 6),
                      Text(valeurMois,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.label)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// À traiter — les signaux ouverts, chacun menant à son écran
// ─────────────────────────────────────────────────────────────────────────

/// Un point à traiter : ce qu'il compte, et où le traiter.
typedef _PointATraiter = ({
  String libelle,
  String precision,
  IconData icone,
  Color couleur,
  String valeur,
  void Function() ouvrir,
});

/// Les signaux ouverts, du plus bloquant au moins pressant. Un compteur à
/// zéro n'est pas affiché : rien à signaler, rien à lire.
class _SectionATraiter extends ConsumerWidget {
  final AlertesTableauBord alertes;
  final double aReverserEtat;

  const _SectionATraiter({required this.alertes, required this.aReverserEtat});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = alertes;
    void flotte(int onglet, [String? motif]) =>
        tbOuvrirFlotte(context, ref, onglet, motif: motif);

    final points = <_PointATraiter>[
      if (a.permisExpires > 0)
        (
          libelle: 'Permis expirés',
          precision: 'chauffeurs bloqués',
          icone: Icons.badge_outlined,
          couleur: kTbRouge,
          valeur: '${a.permisExpires}',
          ouvrir: () => flotte(FleetTab.chauffeurs),
        ),
      if (a.immobilisationsLongues > 0)
        (
          libelle: 'Arrêts longs',
          precision: 'véhicules arrêtés depuis plus de 15 jours',
          icone: Icons.timer_off_outlined,
          couleur: kTbRouge,
          valeur: '${a.immobilisationsLongues}',
          ouvrir: () => flotte(FleetTab.etatParc),
        ),
      if (a.vidangesDues > 0)
        (
          libelle: 'Vidanges dues',
          precision: 'date ou kilométrage atteint',
          icone: Icons.opacity_outlined,
          couleur: kTbOrange,
          valeur: '${a.vidangesDues}',
          ouvrir: () => flotte(FleetTab.etatParc, 'VIDANGE_DUE'),
        ),
      if (a.maintenancesDuesSous7Jours > 0)
        (
          libelle: 'Maintenances dues',
          precision: 'dans les 7 jours',
          icone: Icons.build_outlined,
          couleur: kTbOrange,
          valeur: '${a.maintenancesDuesSous7Jours}',
          ouvrir: () => tbPousser(context, const LignesMaintenancePage()),
        ),
      if (a.documentsExpirantSous30Jours > 0)
        (
          libelle: 'Documents à renouveler',
          precision: 'expirent dans les 30 jours',
          icone: Icons.description_outlined,
          couleur: kTbOrange,
          valeur: '${a.documentsExpirantSous30Jours}',
          ouvrir: () => flotte(FleetTab.etatParc),
        ),
      if (a.vehiculesSansChauffeur > 0)
        (
          libelle: 'Sans chauffeur',
          precision: 'véhicules prêts mais non affectés',
          icone: Icons.person_off_outlined,
          couleur: kTbOrange,
          valeur: '${a.vehiculesSansChauffeur}',
          ouvrir: () => flotte(FleetTab.etatParc, 'SANS_CHAUFFEUR'),
        ),
      if (aReverserEtat > 0)
        (
          libelle: 'À reverser à l\'État',
          precision: 'contraventions encaissées, non reversées',
          icone: Icons.account_balance_outlined,
          couleur: kTbOrange,
          valeur: tbMontantCourt(aReverserEtat),
          ouvrir: () => tbPousser(context, const ContraventionsHubPage()),
        ),
    ];

    final urgent = points.any((p) => p.couleur == kTbRouge);

    return TbSection(
      icone: Icons.notifications_active_outlined,
      titre: 'À traiter',
      accent: points.isEmpty ? kTbVert : (urgent ? kTbRouge : kTbOrange),
      badge: points.isEmpty
          ? null
          : TbPastille(
              texte: '${points.length}',
              couleur: urgent ? kTbRouge : kTbOrange),
      child: points.isEmpty
          ? Row(
              children: [
                Icon(Icons.check_circle_outline_rounded,
                    size: 18, color: kTbVert),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Aucun point de vigilance ouvert',
                      style:
                          TextStyle(fontSize: 12.5, color: AppColors.label)),
                ),
              ],
            )
          : Column(
              children: [
                for (var i = 0; i < points.length; i++) ...[
                  if (i > 0)
                    Divider(height: 1, indent: 46, color: AppColors.border),
                  TbLigneLien(
                    icone: points[i].icone,
                    couleur: points[i].couleur,
                    libelle: points[i].libelle,
                    precision: points[i].precision,
                    valeur: points[i].valeur,
                    couleurValeur: points[i].couleur,
                    onTap: points[i].ouvrir,
                  ),
                ],
              ],
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Résultat du mois
// ─────────────────────────────────────────────────────────────────────────

/// Est-ce que je gagne de l'argent : le résultat, la distance au point mort,
/// et la tendance. La cascade complète est un tap plus loin, dans le compte
/// de résultat.
class _SectionResultat extends StatelessWidget {
  final TableauBordModel data;

  const _SectionResultat({required this.data});

  @override
  Widget build(BuildContext context) {
    final f = data.finance;
    final couverture = f.tauxCouverturePointMort;
    final couleurCouverture =
        tbCouleurTauxCroissant(couverture, bon: 100, moyen: 80);

    return TbCarteRelief(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet_outlined,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Résultat du mois',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.dark)),
              ),
              TbLienVoir(
                  libelle: 'Détail',
                  onTap: () => tbPousser(context, const CompteResultatPage())),
            ],
          ),
          const SizedBox(height: 10),
          TbKpiPrincipal(
            label: 'Résultat de gestion',
            valeur: tbMontantCourt(f.resultatGestion),
            couleur: tbCouleurMontant(f.resultatGestion),
            variationPct: f.variationResultatPct,
            commentaire: _commentaireResultat(f),
          ),
          const SizedBox(height: 16),
          tbAvecAide(
            'Chiffre d\'affaires à partir duquel les charges fixes sont '
            'couvertes. Au-dessus, chaque franc encaissé est du bénéfice ; '
            'en dessous, la période perd de l\'argent.',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Point mort',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.label),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    Text(
                        couverture == null
                            ? 'marge insuffisante'
                            : 'couvert à ${tbPourcent(couverture, decimales: 0)}',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: couleurCouverture)),
                  ],
                ),
                const SizedBox(height: 6),
                TbProgression(taux: couverture, couleur: couleurCouverture),
                if (f.pointMort != null) ...[
                  const SizedBox(height: 5),
                  Text(
                      'Seuil ${tbMontantCourt(f.pointMort!)} · marge '
                      '${tbPourcent(f.tauxMargeVariable)} après charges variables',
                      style: TextStyle(fontSize: 10.5, color: AppColors.hint)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          TbGrilleTuiles(isWide: false, tuiles: [
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
          ]),
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
// Encaissement
// ─────────────────────────────────────────────────────────────────────────

/// Est-ce que l'argent rentre : le taux de recouvrement en jauge, la
/// trésorerie et l'encours, l'âge des créances, et qui doit.
class _SectionCash extends ConsumerWidget {
  final CashCreances cash;

  const _SectionCash({required this.cash});

  /// Débiteurs affichés : au-delà, la balance âgée prend le relais.
  static const _maxDebiteurs = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = cash;
    final couleurRecouvrement =
        tbCouleurTauxCroissant(c.tauxRecouvrement, bon: 95, moyen: 80);

    return TbSection(
      icone: Icons.savings_outlined,
      titre: 'Encaissement',
      accent: AppColors.info,
      libelleVoir: 'Créances',
      onVoir: () => tbOuvrirFinances(context, ref, FinanceTab.creances),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          tbAvecAide(
            'Part des produits dus de la période effectivement encaissée. '
            'Le complément a été facturé mais dort en créance.',
            Row(
              children: [
                TbJauge(taux: c.tauxRecouvrement, couleur: couleurRecouvrement),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Taux de recouvrement',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.dark)),
                      const SizedBox(height: 2),
                      Text(
                          c.resteAEncaisserPeriode > 0
                              ? '${tbMontantCourt(c.resteAEncaisserPeriode)} non encaissés'
                              : 'tout est rentré',
                          style: TextStyle(
                              fontSize: 11.5,
                              color: c.resteAEncaisserPeriode > 0
                                  ? couleurRecouvrement
                                  : AppColors.hint)),
                      Text('sur les produits dus du mois',
                          style:
                              TextStyle(fontSize: 10.5, color: AppColors.hint)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          TbGrilleTuiles(isWide: false, tuiles: [
            TbKpiTuile(
              label: 'Trésorerie',
              valeur: tbMontantCourt(c.tresorerieDisponible),
              couleur: tbCouleurMontant(c.tresorerieDisponible),
              sousLabel: 'disponible à l\'instant',
              aide: 'Solde de tous les comptes actifs, à l\'instant.',
              onTap: () =>
                  tbOuvrirFinances(context, ref, FinanceTab.tresorerie),
            ),
            TbKpiTuile(
              label: 'Créances',
              valeur: tbMontantCourt(c.creancesBrutes),
              sousLabel: '${c.nbChauffeursDebiteurs} chauffeur'
                  '${c.nbChauffeursDebiteurs > 1 ? 's' : ''}',
              aide: 'Encours total dû par les chauffeurs, toutes périodes '
                  'confondues : recettes et pénalités impayées.',
              onTap: () => tbOuvrirFinances(context, ref, FinanceTab.creances),
            ),
          ]),
          const SizedBox(height: 14),
          if (c.creancesBrutes <= 0)
            Text('Aucune créance ouverte',
                style: TextStyle(fontSize: 12, color: AppColors.hint))
          else ...[
            Row(
              children: [
                Expanded(
                  child: Text('Âge des créances',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.label),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                Text('${tbPourcent(c.partCreancesRisque, decimales: 0)} à risque',
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: tbCouleurTauxDecroissant(c.partCreancesRisque,
                            bon: 10, moyen: 25))),
              ],
            ),
            const SizedBox(height: 8),
            TbBarreSegments(segments: [
              (
                libelle: '0 – 7 j',
                valeur: c.creances0a7Jours,
                texte: tbMontantCourt(c.creances0a7Jours),
                couleur: kTbVert,
              ),
              (
                libelle: '8 – 30 j',
                valeur: c.creances8a30Jours,
                texte: tbMontantCourt(c.creances8a30Jours),
                couleur: kTbOrange,
              ),
              (
                libelle: '> 30 j',
                valeur: c.creancesPlus30Jours,
                texte: tbMontantCourt(c.creancesPlus30Jours),
                couleur: kTbRouge,
              ),
            ]),
          ],
          if (c.topDebiteurs.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('Principaux débiteurs',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.label)),
            const SizedBox(height: 2),
            for (final d in c.topDebiteurs.take(_maxDebiteurs))
              _LigneDebiteur(debiteur: d),
          ],
        ],
      ),
    );
  }
}

class _LigneDebiteur extends StatelessWidget {
  final Debiteur debiteur;
  const _LigneDebiteur({required this.debiteur});

  @override
  Widget build(BuildContext context) {
    final d = debiteur;
    final ancien = d.plus30Jours > 0;
    final nom = d.nom.isEmpty ? 'Chauffeur' : d.nom;
    final id = d.chauffeurId;

    return TbLigneLien(
      icone: Icons.person_outline_rounded,
      couleur: ancien ? kTbRouge : AppColors.info,
      libelle: nom,
      precision: ancien
          ? '${tbMontantCourt(d.plus30Jours)} de plus de 30 j'
          : '${d.nbLignes} document${d.nbLignes > 1 ? 's' : ''}',
      couleurPrecision: ancien ? kTbRouge : null,
      valeur: tbMontantCourt(d.total),
      onTap: id == null
          ? null
          : () => tbPousser(
              context, CreancesChauffeurPage(chauffeurId: id, chauffeurNom: nom)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Parc
// ─────────────────────────────────────────────────────────────────────────

/// Est-ce que mes véhicules produisent : la disponibilité en jauge, la
/// répartition du parc, le rendement, et les véhicules à surveiller.
class _SectionParc extends ConsumerWidget {
  final PerformanceFlotte flotte;

  const _SectionParc({required this.flotte});

  /// Véhicules « à surveiller » affichés : au-delà, l'état de parc et les
  /// marges par véhicule prennent le relais.
  static const _maxVehicules = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = flotte;
    final couleurDispo = tbCouleurTauxCroissant(v.tauxDisponibilite);
    final mobilisables = v.enService + v.disponibles;

    return TbSection(
      icone: Icons.directions_car_filled_outlined,
      titre: 'Parc',
      // Violet éclairci en sombre : le ton clair se perd sur fond nuit.
      accent: AppColors.estSombre
          ? const Color(0xFFCE93D8)
          : const Color(0xFF6A1B9A),
      libelleVoir: 'État de parc',
      onVoir: () => tbOuvrirFlotte(context, ref, FleetTab.etatParc),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          tbAvecAide(
            'Part du parc actif en état de rouler, à cet instant : en service '
            'ou disponible. Le reste est en maintenance ou immobilisé.',
            Row(
              children: [
                TbJauge(taux: v.tauxDisponibilite, couleur: couleurDispo),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Disponibilité',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.dark)),
                      const SizedBox(height: 2),
                      Text(
                          '$mobilisables / ${v.parcActif} véhicule'
                          '${v.parcActif > 1 ? 's' : ''} prêts à rouler',
                          style: TextStyle(
                              fontSize: 11.5, color: AppColors.label)),
                      // Avertissement de lecture : l'occupation est l'état du
                      // parc maintenant, pas une moyenne de la période.
                      Row(
                        children: [
                          Icon(Icons.schedule_rounded,
                              size: 11, color: AppColors.hint),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text('à l\'instant, quel que soit le mois',
                                style: TextStyle(
                                    fontSize: 10.5, color: AppColors.hint)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TbBarreSegments(segments: [
            (
              libelle: 'En service',
              valeur: v.enService.toDouble(),
              texte: '${v.enService}',
              couleur: kTbVert,
            ),
            (
              libelle: 'Disponibles',
              valeur: v.disponibles.toDouble(),
              texte: '${v.disponibles}',
              couleur: AppColors.info,
            ),
            (
              libelle: 'Maintenance',
              valeur: v.enMaintenance.toDouble(),
              texte: '${v.enMaintenance}',
              couleur: kTbOrange,
            ),
            (
              libelle: 'Immobilisés',
              valeur: v.immobilises.toDouble(),
              texte: '${v.immobilises}',
              couleur: kTbRouge,
            ),
          ]),
          const SizedBox(height: 14),
          TbGrilleTuiles(isWide: false, tuiles: [
            TbKpiTuile(
              label: 'Revenu / véhicule',
              valeur: tbMontantCourt(v.revenuParVehiculeActif),
              sousLabel: '${tbMontantCourt(v.revenuJournalierMoyen)} par jour',
              aide: 'Produits de la période rapportés au parc actif, puis '
                  'ramenés à la journée.',
            ),
            TbKpiTuile(
              label: 'Manque à gagner',
              valeur: tbMontantCourt(v.manqueAGagnerImmobilisation),
              couleur: v.manqueAGagnerImmobilisation > 0 ? kTbRouge : kTbNeutre,
              sousLabel: '${v.joursImmobilisation} jour'
                  '${v.joursImmobilisation > 1 ? 's' : ''} d\'arrêt',
              aide: 'Jours d\'arrêt valorisés au revenu journalier moyen d\'un '
                  'véhicule : ce que l\'immobilisation a coûté en produits.',
            ),
          ]),
          if (v.moinsBons.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text('À surveiller',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.label),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                if (v.nbVehiculesEvalues > 0)
                  Text(
                      '${v.nbVehiculesDeficitaires} déficitaire'
                      '${v.nbVehiculesDeficitaires > 1 ? 's' : ''} '
                      'sur ${v.nbVehiculesEvalues}',
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: v.nbVehiculesDeficitaires > 0
                              ? kTbRouge
                              : kTbVert)),
              ],
            ),
            const SizedBox(height: 2),
            for (final vp in v.moinsBons.take(_maxVehicules))
              _LigneVehicule(vehicule: vp),
          ],
        ],
      ),
    );
  }
}

class _LigneVehicule extends StatelessWidget {
  final VehiculePerformance vehicule;
  const _LigneVehicule({required this.vehicule});

  @override
  Widget build(BuildContext context) {
    final v = vehicule;
    final id = v.vehiculeId;

    return TbLigneLien(
      icone: Icons.directions_car_outlined,
      couleur: tbCouleurMontant(v.margeNette),
      libelle: v.immatriculation,
      precision: v.joursImmobilisation > 0
          ? '${tbMontantCourt(v.produits)} de produits · '
              '${v.joursImmobilisation} j d\'arrêt'
          : '${tbMontantCourt(v.produits)} de produits',
      valeur: tbMontantCourt(v.margeNette),
      couleurValeur: tbCouleurMontant(v.margeNette),
      onTap: id == null
          ? null
          : () => tbPousser(context, VehiculeDetailPage(vehiculeId: id)),
    );
  }
}

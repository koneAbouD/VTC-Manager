import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/dette_groupee.dart';
import '../../domain/entities/facture_partenaire.dart';
import '../providers/partenaire_providers.dart';
import '../widgets/facture_dialogs.dart';
import 'facture_detail_page.dart';

/// Onglet « Partenaires » : l'échéancier de ce qu'on doit, au choix **par
/// maintenance** ou **par partenaire** via le sélecteur intégré à la carte
/// « Dettes partenaires ».
///
/// Par maintenance, une ligne rassemble une intervention et tous les
/// partenaires qui y sont passés, chacun avec les éléments qu'il a fournis.
/// Par partenaire, elle rassemble un prestataire et tout ce qu'on lui doit,
/// intervention par intervention. Les deux vues lisent le même échéancier :
/// les factures en retard restent en tête, puis viennent les échéances à
/// venir, de la plus proche à la plus lointaine.
///
/// Rien ne se crée ni ne s'administre depuis cet écran : une dette naît du
/// travail qu'on a fait faire — une maintenance ou une dépense marquée « à
/// payer » — jamais d'une saisie autonome, et le référentiel des partenaires
/// se tient dans les paramètres, avec les autres données de référence. On ne
/// fait donc ici que consulter et régler.
class PartenairesTab extends ConsumerStatefulWidget {
  const PartenairesTab({super.key});

  @override
  ConsumerState<PartenairesTab> createState() => _PartenairesTabState();
}

class _PartenairesTabState extends ConsumerState<PartenairesTab> {
  VueDette _vue = VueDette.parMaintenance;

  void _basculer() => setState(() => _vue = _vue == VueDette.parMaintenance
      ? VueDette.parPartenaire
      : VueDette.parMaintenance);

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(echeancierProvider(null));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Erreur(
          message: '$e',
          onRetry: () => ref.invalidate(echeancierProvider(null)),
        ),
        data: (factures) {
          final groupes = GroupeDette.grouper(factures, _vue);

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(echeancierProvider(null)),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                _TotalDuCard(
                    factures: factures, vue: _vue, onBasculer: _basculer),
                const SizedBox(height: 12),
                if (groupes.isEmpty)
                  const _Vide()
                else
                  // La clé porte l'axe : passer d'une vue à l'autre remet les
                  // cartes à plat plutôt que de garder ouvert un groupe qui
                  // n'a plus le même sens.
                  for (final g in groupes)
                    _GroupeCard(
                        key: ValueKey('${_vue.name}-${g.id}-${g.titre}'),
                        groupe: g,
                        vue: _vue),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Ce que l'entreprise doit, avec la part déjà échue et le choix de l'axe.
class _TotalDuCard extends StatelessWidget {
  final List<FacturePartenaire> factures;
  final VueDette vue;
  final VoidCallback onBasculer;

  const _TotalDuCard({
    required this.factures,
    required this.vue,
    required this.onBasculer,
  });

  @override
  Widget build(BuildContext context) {
    final total = factures.fold<double>(0, (s, f) => s + f.restantDu);
    final enRetard = factures
        .where((f) => f.enRetard)
        .fold<double>(0, (s, f) => s + f.restantDu);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Dettes partenaires',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.label)),
              ),
              // Sélecteur d'axe : la même dette, lue par intervention ou par
              // prestataire. Bascule au tap.
              _SelecteurVue(vue: vue, onTap: onBasculer),
            ],
          ),
          const SizedBox(height: 6),
          Text(CurrencyFormatter.format(total),
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.dark)),
          if (enRetard > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFBE9E9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                  'Dont ${CurrencyFormatter.format(enRetard)} en retard',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFB71C1C))),
            ),
          ],
          const SizedBox(height: 4),
          Text('${factures.length} facture(s) à payer',
              style: const TextStyle(fontSize: 11.5, color: AppColors.hint)),
        ],
      ),
    );
  }
}

class _SelecteurVue extends StatelessWidget {
  final VueDette vue;
  final VoidCallback onTap;
  const _SelecteurVue({required this.vue, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.only(left: 12, right: 4, top: 6, bottom: 6),
        decoration: BoxDecoration(
          color: AppColors.primaryTint,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(vue.label,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryDark)),
            const Icon(Icons.arrow_drop_down,
                size: 18, color: AppColors.primaryDark),
          ],
        ),
      ),
    );
  }
}

/// Une ligne de l'axe choisi : l'intervention ou le partenaire, avec ce qu'on
/// doit au total. Se déplie sur le détail, poste par poste.
class _GroupeCard extends StatefulWidget {
  final GroupeDette groupe;
  final VueDette vue;
  const _GroupeCard({super.key, required this.groupe, required this.vue});

  @override
  State<_GroupeCard> createState() => _GroupeCardState();
}

class _GroupeCardState extends State<_GroupeCard> {
  bool _ouvert = false;

  @override
  Widget build(BuildContext context) {
    final groupe = widget.groupe;
    final retard = groupe.joursDeRetard(DateTime.now());
    final couleur = groupe.enRetard ? const Color(0xFFB71C1C) : AppColors.label;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _ouvert = !_ouvert),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: couleur.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_icone, size: 18, color: couleur),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(groupe.titre,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.dark)),
                        const SizedBox(height: 2),
                        Text(_sousTitre,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.hint)),
                        const SizedBox(height: 3),
                        Text(
                            retard > 0
                                ? 'En retard de $retard jour(s)'
                                : 'Échéance ${DateFormat('dd/MM/yyyy').format(groupe.prochaineEcheance)}',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: retard > 0
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: couleur)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(CurrencyFormatter.format(groupe.restantDu),
                      style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.dark)),
                  Icon(
                      _ouvert
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: AppColors.hint),
                ],
              ),
            ),
          ),
          if (_ouvert)
            for (final f in groupe.factures)
              _BlocFacture(facture: f, vue: widget.vue),
        ],
      ),
    );
  }

  IconData get _icone => switch (widget.vue) {
        VueDette.parMaintenance => widget.groupe.id == null
            ? Icons.receipt_long_rounded
            : Icons.build_rounded,
        VueDette.parPartenaire => Icons.store_rounded,
      };

  /// Sous l'intervention : le véhicule et la date. Sous le partenaire : le
  /// volume de ce qu'on lui doit.
  String get _sousTitre {
    final groupe = widget.groupe;
    if (widget.vue == VueDette.parPartenaire) {
      final n = groupe.factures.length;
      final p = groupe.nbPostes;
      return [
        '$n dette${n > 1 ? 's' : ''}',
        if (p > 0) '$p poste${p > 1 ? 's' : ''}',
      ].join(' · ');
    }
    final parts = [
      if (groupe.contexte.isNotEmpty) groupe.contexte,
      if (groupe.date != null)
        'du ${DateFormat('dd/MM/yyyy').format(groupe.date!)}',
    ];
    if (parts.isEmpty) {
      final n = groupe.factures.length;
      return '$n dette${n > 1 ? 's' : ''} sans intervention';
    }
    return parts.join(' · ');
  }
}

/// Une dette du groupe, dans le sens de lecture de l'axe : le partenaire qui
/// est intervenu, ou l'intervention pour laquelle on doit.
///
/// C'est la seule maille qui se règle — un groupe, lui, ne se paie pas d'un
/// bloc : chaque partenaire a sa facture, sa référence et son échéance.
class _BlocFacture extends ConsumerWidget {
  final FacturePartenaire facture;
  final VueDette vue;
  const _BlocFacture({required this.facture, required this.vue});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final couleur = facture.enRetard ? const Color(0xFFB71C1C) : AppColors.hint;

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
            builder: (_) => FactureDetailPage(factureId: facture.id!)),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border, width: 0.6)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                  vue == VueDette.parMaintenance
                      ? Icons.store_outlined
                      : Icons.build_outlined,
                  size: 15,
                  color: couleur),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_titre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.dark)),
                  // Vu depuis le partenaire, la ligne perd le repère de temps
                  // que l'en-tête porte sur l'autre axe : on lui redonne sa
                  // date d'intervention et sa propre échéance, qui n'est pas
                  // forcément la plus proche du groupe.
                  if (vue == VueDette.parPartenaire) ...[
                    const SizedBox(height: 3),
                    Text(_dates,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: facture.enRetard
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: facture.enRetard
                                ? const Color(0xFFB71C1C)
                                : AppColors.hint)),
                  ],
                  // Ce que la dette paie : le montant seul ne dit pas pourquoi
                  // on doit cet argent, les postes le disent.
                  if (facture.lignes.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    _PostesDette(lignes: facture.lignes),
                  ] else if (_complement.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(_complement,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.hint)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(CurrencyFormatter.format(facture.restantDu),
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.dark)),
                // Le total n'est rappelé que s'il diffère du restant dû.
                if (facture.montantPaye > 0)
                  Text('sur ${CurrencyFormatter.format(facture.montant)}',
                      style:
                          const TextStyle(fontSize: 10, color: AppColors.hint)),
                const SizedBox(height: 6),
                // Payer est le geste le plus fréquent : il reste à un clic.
                _BoutonRegler(facture: facture),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Sur l'axe maintenance, la dette porte le nom de celui qui est intervenu ;
  /// sur l'axe partenaire, celui de l'intervention qui l'a créée.
  String get _titre {
    if (vue == VueDette.parMaintenance) {
      return facture.partenaireNom ?? 'Partenaire';
    }
    final parts = [
      if (facture.categorieLibelle != null &&
          facture.categorieLibelle!.isNotEmpty)
        facture.categorieLibelle!,
      if (facture.vehiculeImmatriculation != null &&
          facture.vehiculeImmatriculation!.isNotEmpty)
        facture.vehiculeImmatriculation!,
    ];
    if (parts.isEmpty) {
      return facture.issueDeMaintenance ? 'Intervention' : 'Dépense';
    }
    return parts.join(' · ');
  }

  /// Les deux dates d'une dette lue depuis son partenaire : quand le travail
  /// a été fait, et pour quand il faut payer. Le retard prend la place de
  /// l'échéance — c'est le même repère, dit dans le sens qui presse.
  String get _dates {
    final format = DateFormat('dd/MM/yyyy');
    final retard = facture.joursDeRetard(DateTime.now());
    return [
      'du ${format.format(facture.dateFacture)}',
      retard > 0
          ? 'en retard de $retard j'
          : 'échéance ${format.format(facture.dateEcheance)}',
    ].join(' · ');
  }

  /// Faute de postes détaillés — cas d'une dépense saisie « à payer » — on
  /// montre au moins de quoi il retourne. Inutile sur l'axe partenaire, où la
  /// ligne porte déjà son contexte et ses dates.
  String get _complement {
    if (vue == VueDette.parPartenaire) return '';
    return [
      if (facture.categorieLibelle != null) facture.categorieLibelle!,
      if (facture.vehiculeImmatriculation != null)
        facture.vehiculeImmatriculation!,
    ].join(' · ');
  }
}

/// Les postes couverts par la dette, en pastilles. Au-delà de trois, le reste
/// est compté — la carte doit rester lisible d'un coup d'œil.
class _PostesDette extends StatelessWidget {
  final List<LigneDette> lignes;
  const _PostesDette({required this.lignes});

  @override
  Widget build(BuildContext context) {
    const maxVisibles = 3;
    final visibles = lignes.take(maxVisibles).toList();
    final reste = lignes.length - visibles.length;

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final l in visibles)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3EB),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0x33E65100)),
            ),
            child: Text(
              l.libelle,
              style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFFE65100),
                  fontWeight: FontWeight.w600),
            ),
          ),
        if (reste > 0)
          Text('+$reste',
              style: const TextStyle(fontSize: 10, color: AppColors.hint)),
      ],
    );
  }
}

/// Raccourci de règlement, sans passer par le détail.
class _BoutonRegler extends ConsumerWidget {
  final FacturePartenaire facture;
  const _BoutonRegler({required this.facture});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => showReglementFactureDialog(context, ref, facture),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primaryTint,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text('Régler',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark)),
      ),
    );
  }
}

class _Vide extends StatelessWidget {
  const _Vide();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 48),
      child: Column(
        children: [
          Icon(Icons.check_circle_outline_rounded,
              size: 40, color: AppColors.hint),
          SizedBox(height: 10),
          Text('Vous ne devez rien à vos partenaires',
              style: TextStyle(color: AppColors.label)),
          SizedBox(height: 6),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
                'Une dette apparaît ici dès qu\'une maintenance ou une '
                'dépense est enregistrée « à payer » : la charge compte pour '
                'le mois où le travail a été fait, et il vous reste à régler.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12, color: AppColors.hint, height: 1.4)),
          ),
        ],
      ),
    );
  }
}

class _Erreur extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _Erreur({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.label)),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }
}

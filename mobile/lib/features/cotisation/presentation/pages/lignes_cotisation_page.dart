import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/encaissement_cotisation.dart';
import '../../domain/entities/ligne_cotisation.dart';
import '../../domain/entities/ligne_cotisation_filtres.dart';
import '../providers/ligne_cotisation_provider.dart';
import '../../../../core/pagination/paged_list_notifier.dart';
import '../../../../core/widgets/encaissement_ligne_dialog.dart';
import '../../../../features/operation_financiere/presentation/providers/operation_financiere_provider.dart';
import '../../../../core/widgets/filtre_vehicule_chauffeur_dialog.dart';
import '../../../../features/chauffeur/domain/entities/chauffeur.dart';
import '../../../../features/vehicule/domain/entities/vehicule.dart';
import 'ligne_cotisation_detail_page.dart';
import '../../../../core/widgets/date_filter_dialogs.dart';

// ── Constantes partagées ───────────────────────────────────────────────────

enum _FiltreMode { mois, semaine, jour, periode }

/// Libellé d'une ligne : « Immatriculation - Nom chauffeur »
/// (immatriculation seule si le nom du chauffeur est absent). Le chauffeur est
/// celui qui était programmé sur le véhicule le jour de la cotisation.
String _libelleVehiculeChauffeur(LigneCotisation ligne) {
  final immat = ligne.vehiculeImmatriculation ?? 'Véhicule ${ligne.vehiculeId}';
  final nom = ligne.chauffeurNom;
  return (nom != null && nom.isNotEmpty) ? '$immat - $nom' : immat;
}

// ── Page principale ────────────────────────────────────────────────────────

class LignesCotisationPage extends ConsumerStatefulWidget {
  const LignesCotisationPage({super.key});

  @override
  ConsumerState<LignesCotisationPage> createState() =>
      _LignesCotisationPageState();
}

class _LignesCotisationPageState extends ConsumerState<LignesCotisationPage> {
  // ── Filtres serveur ────────────────────────────────────────────────────
  // null = aucun filtre par date (toutes périodes) — comportement par défaut.
  _FiltreMode? _filtreMode;
  int         _moisSelectionne    = DateTime.now().month;
  int         _anneeSelectionnee  = DateTime.now().year;
  DateTime    _jourSelectionne    = DateTime.now();
  DateTime    _semaineDebut       = mondayOf(DateTime.now());
  DateTime    _periodeDebut       = DateTime.now().subtract(const Duration(days: 30));
  DateTime    _periodeFin         = DateTime.now();

  // ── Filtres client ─────────────────────────────────────────────────────
  StatutLigneCotisation? _statut;
  String _recherche = '';
  Vehicule?  _vehiculeFiltre;
  Chauffeur? _chauffeurFiltre;

  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  OverlayEntry? _overlayEntry;
  final _filtreButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _overlayEntry?.remove();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 300) {
      ref.read(lignesCotisationListeProvider.notifier).loadMore();
    }
  }

  Future<void> _showFiltreAvance() async {
    final result = await showFiltreVehiculeChauffeurDialog(
      context,
      vehiculeInitial:  _vehiculeFiltre,
      chauffeurInitial: _chauffeurFiltre,
      avecChauffeur:    true,
    );
    if (result != null && mounted) {
      setState(() {
        _vehiculeFiltre  = result.vehicule;
        _chauffeurFiltre = result.chauffeur;
      });
      _load();
    }
  }

  // ── Logique date ────────────────────────────────────────────────────────

  // (null, null) quand aucun filtre par date n'est actif.
  (DateTime?, DateTime?) _plageActive() => switch (_filtreMode) {
        null => (null, null),
        _FiltreMode.mois => (
            DateTime(_anneeSelectionnee, _moisSelectionne, 1),
            DateTime(_anneeSelectionnee, _moisSelectionne + 1, 0),
          ),
        _FiltreMode.semaine => (
            _semaineDebut,
            _semaineDebut.add(const Duration(days: 6)),
          ),
        _FiltreMode.jour    => (_jourSelectionne, _jourSelectionne),
        _FiltreMode.periode => (_periodeDebut, _periodeFin),
      };

  // Filtres serveur (date + statut + véhicule + chauffeur), page par page.
  void _load() {
    final (debut, fin) = _plageActive();
    final repo = ref.read(ligneCotisationRepositoryProvider);
    ref.read(lignesCotisationListeProvider.notifier).load(
          (page, size) => repo.getLignesPage(
            LigneCotisationFiltres(
              vehiculeId: _vehiculeFiltre?.id,
              chauffeurId: _chauffeurFiltre?.id,
              statut: _statut,
              dateDebut: debut,
              dateFin: fin,
            ),
            page: page,
            size: size,
          ),
        );
  }

  // Recherche texte : filtre client sur les éléments déjà chargés (le backend
  // cotisation n'expose pas de recherche libre). Autres filtres = serveur.
  List<LigneCotisation> _filtrerRecherche(List<LigneCotisation> all) {
    final query = _recherche.trim().toLowerCase();
    if (query.isEmpty) return all;
    return all.where((l) {
      final hay = [
        l.vehiculeImmatriculation ?? '',
        l.nomCotisation,
        l.statut.label,
      ].join(' ').toLowerCase();
      return hay.contains(query);
    }).toList();
  }

  // ── Overlay filtre mode ─────────────────────────────────────────────────

  void _showFiltreOverlay() {
    _removeOverlay();
    final box = _filtreButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final offset = box.localToGlobal(Offset.zero);
    final size   = box.size;

    _overlayEntry = OverlayEntry(
      builder: (ctx) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _removeOverlay,
        child: Stack(children: [
          Positioned(
            left: offset.dx,
            top: offset.dy + size.height + 4,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 210,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  // null = « Toutes les périodes » (désactive le filtre par date).
                  children: <_FiltreMode?>[null, ..._FiltreMode.values].map((mode) {
                    final label = switch (mode) {
                      null                => 'Tous',
                      _FiltreMode.mois    => 'Mois',
                      _FiltreMode.semaine => 'Semaine',
                      _FiltreMode.jour    => 'Jour',
                      _FiltreMode.periode => 'Période',
                    };
                    final sel = _filtreMode == mode;
                    return InkWell(
                      onTap: () {
                        setState(() => _filtreMode = mode);
                        _removeOverlay();
                        _load();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(children: [
                          Icon(
                            sel
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off_outlined,
                            size: 18,
                            color: sel
                                ? const Color(0xFF43A047)
                                : Colors.grey.shade400,
                          ),
                          const SizedBox(width: 10),
                          Text(label,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: sel
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: sel
                                    ? const Color(0xFF43A047)
                                    : const Color(0xFF1A1A1A),
                              )),
                        ]),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  // ── Sélecteurs de date ──────────────────────────────────────────────────

  Future<void> _pickMois() async {
    final r = await showDialog<DateTime>(
      context: context,
      builder: (_) => MonthPickerDialog(
          initialYear: _anneeSelectionnee, initialMonth: _moisSelectionne),
    );
    if (r != null) {
      setState(() {
        _moisSelectionne   = r.month;
        _anneeSelectionnee = r.year;
      });
      _load();
    }
  }

  Future<void> _pickSemaine() async {
    final r = await showDialog<DateTime>(
      context: context,
      builder: (_) => WeekPickerDialog(initialWeekStart: _semaineDebut),
    );
    if (r != null) { setState(() => _semaineDebut = r); _load(); }
  }

  Future<void> _pickJour() async {
    final r = await showDialog<DateTime>(
      context: context,
      builder: (_) => SingleDatePickerDialog(initialDate: _jourSelectionne),
    );
    if (r != null) { setState(() => _jourSelectionne = r); _load(); }
  }

  Future<void> _pickPeriode() async {
    final r = await showDialog<DateTimeRange>(
      context: context,
      builder: (_) => PeriodePickerDialog(
          initialStart: _periodeDebut, initialEnd: _periodeFin),
    );
    if (r != null) {
      setState(() { _periodeDebut = r.start; _periodeFin = r.end; });
      _load();
    }
  }

  // ── Génération ──────────────────────────────────────────────────────────

  Future<void> _openEncaisserDialog(LigneCotisation ligne) async {
    final repo   = ref.read(ligneCotisationRepositoryProvider);
    final result = await showEncaissementLigneDialog(
      context,
      titre:     ligne.nomCotisation,
      sousTitre: _libelleVehiculeChauffeur(ligne),
      montantRestant: ligne.montantRestant ??
          (ligne.montantDu - ligne.montantEncaisse),
      couleur: const Color(0xFFE65100),
      icone:   Icons.analytics_outlined,
      onEncaisser: (montant, commentaire) async {
        final enc = EncaissementCotisation(
          ligneCotisationId: ligne.id!,
          montant:           montant,
          modeEncaissement:  ModePaiementCotisation.especes,
          dateEncaissement:  DateTime.now(),
          commentaire:       commentaire,
        );
        final r = await repo.createEncaissement(ligne.id!, enc);
        return r.fold((f) => f.message, (_) => null);
      },
    );
    if (result == true && mounted) {
      _load();
      ref.read(operationFinanciereNotifierProvider.notifier).loadAll();
    }
  }

  Future<void> _generer() async {
    final result =
        await ref.read(ligneCotisationRepositoryProvider).generer();
    final error = result.fold((f) => f.message, (_) => null);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(error ?? "Cotisations d'hier générées avec succès."),
      backgroundColor: error != null ? Colors.red : null,
    ));
    if (error == null) _load();
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(
        locale: 'fr_FR', symbol: 'XOF', decimalDigits: 0);
    final state = ref.watch(lignesCotisationListeProvider);
    final filtered = _filtrerRecherche(state.items);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── En-tête ────────────────────────────────────────────────
            Container(
              color: AppColors.header,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 56, height: 38,
                      decoration: BoxDecoration(
                          color: const Color(0xFFF0F2F8),
                          borderRadius: BorderRadius.circular(20)),
                      child: const Icon(Icons.arrow_back_rounded,
                          size: 18, color: Color(0xFF1A1A2E)),
                    ),
                  ),
                  const Expanded(
                    child: Text('Cotisations',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1A1A2E),
                            letterSpacing: -0.3)),
                  ),
                  GestureDetector(
                    onTap: _generer,
                    child: Container(
                      width: 56, height: 38,
                      decoration: BoxDecoration(
                          color: const Color(0xFFF0F2F8),
                          borderRadius: BorderRadius.circular(20)),
                      child: const Icon(Icons.auto_awesome_rounded,
                          size: 18, color: Color(0xFF1A1A2E)),
                    ),
                  ),
                ],
              ),
            ),

            // ── Corps ──────────────────────────────────────────────────
            Expanded(
              child: state.initialLoading && state.items.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : (state.error != null && state.items.isEmpty)
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(state.error!,
                                style: const TextStyle(color: Colors.red),
                                textAlign: TextAlign.center),
                          ))
                      : RefreshIndicator(
                          onRefresh: () => ref
                              .read(lignesCotisationListeProvider.notifier)
                              .refresh(),
                          child: CustomScrollView(
                            controller: _scrollController,
                            slivers: [
                              // ── Filtre date ──────────────────────────
                              SliverToBoxAdapter(
                                child: _FiltreDateBar(
                                  mode: _filtreMode,
                                  filtreKey: _filtreButtonKey,
                                  onFiltrePressed: _showFiltreOverlay,
                                  moisSelectionne: _moisSelectionne,
                                  anneeSelectionnee: _anneeSelectionnee,
                                  onPickMois: _pickMois,
                                  semaineDebut: _semaineDebut,
                                  onPickSemaine: _pickSemaine,
                                  jourSelectionne: _jourSelectionne,
                                  onPickJour: _pickJour,
                                  periodeDebut: _periodeDebut,
                                  periodeFin: _periodeFin,
                                  onPickPeriode: _pickPeriode,
                                ),
                              ),

                              // ── Recherche + Statut (filtre client) ───
                              SliverToBoxAdapter(
                                child: _SearchAndStatutBar(
                                  controller: _searchController,
                                  onSearchChanged: (v) =>
                                      setState(() => _recherche = v),
                                  statutSelectionne: _statut,
                                  onStatutChanged: (s) {
                                    setState(() => _statut = s);
                                    _load();
                                  },
                                  onTunePressed:   _showFiltreAvance,
                                  hasActiveFilter: _vehiculeFiltre != null || _chauffeurFiltre != null,
                                ),
                              ),

                              // ── Liste / vide / loader bas de page ────
                              if (filtered.isEmpty)
                                const SliverFillRemaining(
                                    hasScrollBody: false,
                                    child: _EmptyState())
                              else
                                SliverPadding(
                                  padding: const EdgeInsets.fromLTRB(
                                      16, 10, 16, 24),
                                  sliver: SliverList(
                                    delegate: SliverChildBuilderDelegate(
                                      (_, i) {
                                        if (i >= filtered.length) {
                                          return const PagedListLoadMoreTile();
                                        }
                                        final ligne = filtered[i];
                                        return _LigneCotisationCard(
                                          ligne: ligne,
                                          money: money,
                                          onTap: () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  LigneCotisationDetailPage(
                                                      ligneId: ligne.id!),
                                            ),
                                          ).then((_) => _load()),
                                          onEncaisser: ligne.estActive
                                              ? () => _openEncaisserDialog(ligne)
                                              : null,
                                        );
                                      },
                                      childCount: filtered.length +
                                          (state.hasMore ? 1 : 0),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Barre filtre date ──────────────────────────────────────────────────────

class _FiltreDateBar extends StatelessWidget {
  final _FiltreMode? mode;
  final GlobalKey filtreKey;
  final VoidCallback onFiltrePressed;
  final int moisSelectionne;
  final int anneeSelectionnee;
  final VoidCallback onPickMois;
  final DateTime semaineDebut;
  final VoidCallback onPickSemaine;
  final DateTime jourSelectionne;
  final VoidCallback onPickJour;
  final DateTime periodeDebut;
  final DateTime periodeFin;
  final VoidCallback onPickPeriode;

  const _FiltreDateBar({
    required this.mode,
    required this.filtreKey,
    required this.onFiltrePressed,
    required this.moisSelectionne,
    required this.anneeSelectionnee,
    required this.onPickMois,
    required this.semaineDebut,
    required this.onPickSemaine,
    required this.jourSelectionne,
    required this.onPickJour,
    required this.periodeDebut,
    required this.periodeFin,
    required this.onPickPeriode,
  });

  @override
  Widget build(BuildContext context) {
    final modeLabel = switch (mode) {
      null                => 'Tous',
      _FiltreMode.mois    => 'Mois',
      _FiltreMode.semaine => 'Semaine',
      _FiltreMode.jour    => 'Jour',
      _FiltreMode.periode => 'Période',
    };

    final Widget datePill = switch (mode) {
      // Carte de valeur statique quand aucun filtre par date n'est actif.
      null => _DatePill(
          icon: Icons.calendar_month_outlined,
          label: 'Toutes les périodes',
          onTap: onFiltrePressed),
      _FiltreMode.mois => _DatePill(
          icon: Icons.calendar_month_outlined,
          label: '${kMoisNoms[moisSelectionne - 1]} $anneeSelectionnee',
          onTap: onPickMois),
      _FiltreMode.semaine => _DatePill(
          icon: Icons.date_range_outlined,
          label:
              '${DateFormat('dd/MM').format(semaineDebut)} – ${DateFormat('dd/MM/yyyy').format(semaineDebut.add(const Duration(days: 6)))}',
          onTap: onPickSemaine),
      _FiltreMode.jour => _DatePill(
          icon: Icons.calendar_today_outlined,
          label: DateFormat('dd/MM/yyyy').format(jourSelectionne),
          onTap: onPickJour),
      _FiltreMode.periode => _DatePill(
          icon: Icons.calendar_month_outlined,
          label:
              'Du ${DateFormat('dd/MM/yyyy').format(periodeDebut)} au ${DateFormat('dd/MM/yyyy').format(periodeFin)}',
          onTap: onPickPeriode),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(children: [
        GestureDetector(
          key: filtreKey,
          onTap: onFiltrePressed,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.filter_list_rounded,
                  size: 14, color: Color(0xFF43A047)),
              const SizedBox(width: 5),
              Text(modeLabel,
                  style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF43A047),
                      fontWeight: FontWeight.w500)),
              const SizedBox(width: 3),
              const Icon(Icons.keyboard_arrow_down_rounded,
                  size: 14, color: Color(0xFF43A047)),
            ]),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: datePill),
      ]),
    );
  }
}

class _DatePill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _DatePill(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            Icon(icon, size: 13, color: Colors.grey.shade600),
            const SizedBox(width: 6),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 5),
            Icon(Icons.keyboard_arrow_down_rounded,
                size: 14, color: Colors.grey.shade600),
          ]),
        ),
      );
}

// ── Barre recherche + filtre statut ──────────────────────────────────────

class _SearchAndStatutBar extends StatefulWidget {
  final TextEditingController controller;
  final void Function(String) onSearchChanged;
  final StatutLigneCotisation? statutSelectionne;
  final void Function(StatutLigneCotisation?) onStatutChanged;
  final VoidCallback? onTunePressed;
  final bool hasActiveFilter;

  const _SearchAndStatutBar({
    required this.controller,
    required this.onSearchChanged,
    required this.statutSelectionne,
    required this.onStatutChanged,
    this.onTunePressed,
    this.hasActiveFilter = false,
  });

  @override
  State<_SearchAndStatutBar> createState() => _SearchAndStatutBarState();
}

class _SearchAndStatutBarState extends State<_SearchAndStatutBar> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    // Rebuild pour basculer loupe ↔ croix (ferme le clavier) selon le focus.
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 6),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            // Fond gris (aligné sur les champs de VehiculeFormPage) plutôt
            // qu'un blanc avec ombre portée.
            color: const Color(0xFFF2F3F5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            _focus.hasFocus
                ? GestureDetector(
                    onTap: _focus.unfocus,
                    child: const Icon(Icons.close,
                        color: Color(0xFF8A8A8E), size: 20),
                  )
                : const Icon(Icons.search,
                    color: Color(0xFF8A8A8E), size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: widget.controller,
                focusNode: _focus,
                onChanged: widget.onSearchChanged,
                style: const TextStyle(fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Véhicule, cotisation...',
                  hintStyle:
                      TextStyle(color: Color(0xFF8A8A8E), fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            TuneFilterButton(
              onTap:  widget.onTunePressed,
              active: widget.hasActiveFilter,
            ),
          ]),
        ),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _Chip(
                label: 'Tous',
                selected: widget.statutSelectionne == null,
                color: Colors.grey.shade600,
                onTap: () => widget.onStatutChanged(null),
              ),
              ...StatutLigneCotisation.values.map((s) => _Chip(
                    label: s.label,
                    selected: widget.statutSelectionne == s,
                    color: _couleur(s),
                    onTap: () => widget.onStatutChanged(s),
                  )),
            ],
          ),
        ),
        const SizedBox(height: 4),
      ]);

  Color _couleur(StatutLigneCotisation s) => switch (s) {
        StatutLigneCotisation.enAttente             => Colors.orange,
        StatutLigneCotisation.partiellementEncaisse => Colors.blue,
        StatutLigneCotisation.encaisse              => Colors.green,
        StatutLigneCotisation.annulee               => Colors.grey,
      };
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _Chip(
      {required this.label,
      required this.selected,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? color : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: selected ? color : Colors.grey.shade300),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: selected ? Colors.white : Colors.grey.shade600)),
        ),
      );
}

// ── Carte ligne de cotisation ─────────────────────────────────────────────

class _LigneCotisationCard extends StatelessWidget {
  final LigneCotisation ligne;
  final NumberFormat  money;
  final VoidCallback  onTap;
  final VoidCallback? onEncaisser;
  const _LigneCotisationCard({
    required this.ligne,
    required this.money,
    required this.onTap,
    this.onEncaisser,
  });

  @override
  Widget build(BuildContext context) {
    final color   = _couleur(ligne.statut);
    final restant = ligne.montantRestant ??
        (ligne.montantDu - ligne.montantEncaisse)
            .clamp(0, double.infinity)
            .toDouble();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle),
              child: Icon(_icone(ligne.statut), color: color, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ligne.nomCotisation,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Color(0xFF1A1A1A)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                      _libelleVehiculeChauffeur(ligne),
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade500)),
                  Text(
                    _labelDate(ligne.dateCotisation),
                    style: TextStyle(
                        fontSize: 10, color: Colors.grey.shade400),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Montants + bouton encaisser (droite)
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(
                '${NumberFormat('#,##0', 'fr_FR').format(restant)} XOF',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: restant > 0
                        ? Colors.orange.shade700
                        : const Color(0xFF2E7D32)),
              ),
              if (restant != ligne.montantDu)
                Text(
                  'sur ${NumberFormat('#,##0', 'fr_FR').format(ligne.montantDu)} XOF',
                  style: TextStyle(
                      fontSize: 10, color: Colors.grey.shade400),
                ),
              if (onEncaisser != null) ...[
                const SizedBox(height: 6),
                EncaisserChip(
                  onTap: onEncaisser!,
                  color: const Color(0xFFE65100),
                ),
              ],
            ]),
          ],
        ),
      ),
    );
  }

  String _labelDate(DateTime date) {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d     = DateTime(date.year, date.month, date.day);
    final diff  = today.difference(d).inDays;
    if (diff == 0) return "Aujourd'hui";
    if (diff == 1) return 'Hier';
    if (diff < 7) {
      const jours = [
        'Lundi', 'Mardi', 'Mercredi', 'Jeudi',
        'Vendredi', 'Samedi', 'Dimanche',
      ];
      return jours[date.weekday - 1];
    }
    return DateFormat('dd/MM/yyyy').format(date);
  }

  Color _couleur(StatutLigneCotisation s) => switch (s) {
        StatutLigneCotisation.enAttente             => Colors.orange,
        StatutLigneCotisation.partiellementEncaisse => Colors.blue,
        StatutLigneCotisation.encaisse              => Colors.green,
        StatutLigneCotisation.annulee               => Colors.grey,
      };

  IconData _icone(StatutLigneCotisation s) => switch (s) {
        StatutLigneCotisation.enAttente             => Icons.hourglass_empty_rounded,
        StatutLigneCotisation.partiellementEncaisse => Icons.hourglass_top_rounded,
        StatutLigneCotisation.encaisse              => Icons.check_circle_rounded,
        StatutLigneCotisation.annulee               => Icons.cancel_rounded,
      };
}

// ── État vide ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(alignment: Alignment.center, children: [
              Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      shape: BoxShape.circle)),
              Icon(Icons.savings_rounded,
                  size: 38, color: Colors.grey.shade300),
            ]),
            const SizedBox(height: 16),
            Text('Aucune cotisation',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600)),
            const SizedBox(height: 6),
            Text(
              'Appuyez sur ✨ pour générer les cotisations',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
}


import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/date_filter_dialogs.dart';
import '../../../../core/widgets/filtre_vehicule_chauffeur_dialog.dart';
import '../../../../features/vehicule/domain/entities/vehicule.dart';
import '../../domain/entities/maintenance.dart';
import '../providers/maintenance_provider.dart';
import '../../../../core/pagination/paged_list_notifier.dart';
import '../../../operation_financiere/presentation/providers/operation_financiere_provider.dart';
import 'maintenance_detail_page.dart';
import 'maintenance_form_page.dart';

// ── Constantes ────────────────────────────────────────────────────────────────

enum _FiltreMode { mois, semaine, jour, periode }

const _kPrimary = Color(0xFF1A5276);
const _kAccent  = Color(0xFFE65100);

// ── Page ──────────────────────────────────────────────────────────────────────

class LignesMaintenancePage extends ConsumerStatefulWidget {
  const LignesMaintenancePage({super.key});

  @override
  ConsumerState<LignesMaintenancePage> createState() =>
      _LignesMaintenancePageState();
}

class _LignesMaintenancePageState
    extends ConsumerState<LignesMaintenancePage> {
  // null = aucun filtre par date (toutes périodes) — comportement par défaut.
  _FiltreMode? _filtreMode;
  int      _moisSelectionne    = DateTime.now().month;
  int      _anneeSelectionnee  = DateTime.now().year;
  DateTime _jourSelectionne    = DateTime.now();
  DateTime _semaineDebut       = mondayOf(DateTime.now());
  DateTime _periodeDebut       =
      DateTime.now().subtract(const Duration(days: 30));
  DateTime _periodeFin         = DateTime.now();
  String?  _statutFiltre;
  String   _recherche          = '';
  Vehicule? _vehiculeFiltre;

  final _searchController  = TextEditingController();
  final _scrollController  = ScrollController();
  OverlayEntry? _overlayEntry;
  final _filtreButtonKey   = GlobalKey();

  static const _statuts = ['PLANIFIEE', 'TERMINEE', 'ANNULEE'];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    Future.microtask(() => _load());
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
      ref.read(maintenancesListeProvider.notifier).loadMore();
    }
  }

  Future<void> _showFiltreAvance() async {
    final result = await showFiltreVehiculeChauffeurDialog(
      context,
      vehiculeInitial: _vehiculeFiltre,
      avecChauffeur:   false,
    );
    if (result != null && mounted) {
      setState(() {
        _vehiculeFiltre = result.vehicule;
      });
      _load();
    }
  }

  // ── Chargement (filtres serveur : date + statut + véhicule) ────────────────

  void _load() {
    final (debut, fin) = _plageActive();
    final repo = ref.read(maintenanceRepositoryProvider);
    ref.read(maintenancesListeProvider.notifier).load(
          (page, size) => repo.getMaintenancesPage(
            page: page,
            size: size,
            dateDebut:
                debut != null ? DateFormat('yyyy-MM-dd').format(debut) : null,
            dateFin: fin != null ? DateFormat('yyyy-MM-dd').format(fin) : null,
            statut: _statutFiltre,
            vehiculeId: _vehiculeFiltre?.id,
          ),
        );
  }

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

  // Recherche texte : filtre client sur les éléments déjà chargés (le backend
  // maintenance n'expose pas de recherche libre). Date/statut/véhicule = serveur.
  List<Maintenance> _filtrerRecherche(List<Maintenance> all) {
    if (_recherche.trim().isEmpty) return all;
    final q = _recherche.toLowerCase();
    return all.where((m) {
      final hay = [
        m.type,
        m.vehiculeNom ?? '',
        m.vehiculeImmatriculation ?? '',
        m.prestataire ?? '',
      ].join(' ').toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  // ── Overlay filtre mode ───────────────────────────────────────────────────

  void _showFiltreOverlay() {
    _removeOverlay();
    final box =
        _filtreButtonKey.currentContext?.findRenderObject() as RenderBox?;
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
            top:  offset.dy + size.height + 4,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 210,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
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
                            color: sel ? _kPrimary : Colors.grey.shade400,
                          ),
                          const SizedBox(width: 10),
                          Text(label,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: sel
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: sel
                                    ? _kPrimary
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

  // ── Pickers — dialogs partagés de LignesRecettePage ──────────────────────

  Future<void> _pickMois() async {
    final result = await showDialog<DateTime>(
      context: context,
      builder: (_) => MonthPickerDialog(
        initialYear:  _anneeSelectionnee,
        initialMonth: _moisSelectionne,
      ),
    );
    if (result != null) {
      setState(() {
        _moisSelectionne   = result.month;
        _anneeSelectionnee = result.year;
      });
      _load();
    }
  }

  Future<void> _pickSemaine() async {
    final result = await showDialog<DateTime>(
      context: context,
      builder: (_) => WeekPickerDialog(initialWeekStart: _semaineDebut),
    );
    if (result != null) {
      setState(() => _semaineDebut = result);
      _load();
    }
  }

  Future<void> _pickJour() async {
    final result = await showDialog<DateTime>(
      context: context,
      builder: (_) => SingleDatePickerDialog(initialDate: _jourSelectionne),
    );
    if (result != null) {
      setState(() => _jourSelectionne = result);
      _load();
    }
  }

  Future<void> _pickPeriode() async {
    final result = await showDialog<DateTimeRange>(
      context: context,
      builder: (_) => PeriodePickerDialog(
        initialStart: _periodeDebut,
        initialEnd:   _periodeFin,
      ),
    );
    if (result != null) {
      setState(() {
        _periodeDebut = result.start;
        _periodeFin   = result.end;
      });
      _load();
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(
        locale: 'fr_FR', symbol: 'XOF', decimalDigits: 0);
    final state = ref.watch(maintenancesListeProvider);
    final filtered = _filtrerRecherche(state.items);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── En-tête ────────────────────────────────────────────────
            Container(
              color: AppColors.header,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 56, height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F2F8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.arrow_back_rounded,
                        size: 18, color: Color(0xFF1A1A2E)),
                  ),
                ),
                const Expanded(
                  child: Text(
                    'Maintenances',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1A2E),
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const MaintenanceFormPage()),
                    );
                    _load();
                  },
                  child: Container(
                    width: 56,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F2F8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.add_rounded,
                        size: 20, color: Color(0xFF1A1A2E)),
                  ),
                ),
              ]),
            ),

            // ── Corps ──────────────────────────────────────────────────
            Expanded(
              child: state.initialLoading && state.items.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: () => ref
                          .read(maintenancesListeProvider.notifier)
                          .refresh(),
                      child: CustomScrollView(
                        controller: _scrollController,
                        slivers: [
                          SliverToBoxAdapter(
                            child: _FiltreBar(
                              mode:              _filtreMode,
                              filtreKey:         _filtreButtonKey,
                              onFiltrePressed:   _showFiltreOverlay,
                              moisSelectionne:   _moisSelectionne,
                              anneeSelectionnee: _anneeSelectionnee,
                              onPickMois:        _pickMois,
                              semaineDebut:      _semaineDebut,
                              onPickSemaine:     _pickSemaine,
                              jourSelectionne:   _jourSelectionne,
                              onPickJour:        _pickJour,
                              periodeDebut:      _periodeDebut,
                              periodeFin:        _periodeFin,
                              onPickPeriode:     _pickPeriode,
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: _SearchAndStatutBar(
                              controller:        _searchController,
                              onSearchChanged:   (v) =>
                                  setState(() => _recherche = v),
                              statutSelectionne: _statutFiltre,
                              onStatutChanged:   (s) {
                                setState(() => _statutFiltre = s);
                                _load();
                              },
                              statuts: _statuts,
                              onTunePressed:    _showFiltreAvance,
                              hasActiveFilter:  _vehiculeFiltre != null,
                            ),
                          ),
                          if (filtered.isEmpty)
                            const SliverFillRemaining(
                                hasScrollBody: false, child: _EmptyState())
                          else
                            SliverPadding(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 10, 16, 24),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (_, i) {
                                    if (i >= filtered.length) {
                                      return const PagedListLoadMoreTile();
                                    }
                                    final m = filtered[i];
                                    return _MaintenanceCard(
                                      maintenance: m,
                                      money: money,
                                      onTap: () async {
                                        final result = await Navigator.push<bool>(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => MaintenanceDetailPage(
                                              maintenance: m,
                                            ),
                                          ),
                                        );
                                        if (result == true && mounted) {
                                          _load();
                                          ref.read(operationFinanciereNotifierProvider.notifier).loadAll();
                                        }
                                      },
                                    );
                                  },
                                  childCount:
                                      filtered.length + (state.hasMore ? 1 : 0),
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

// ── Barre filtre date ─────────────────────────────────────────────────────────

class _FiltreBar extends StatelessWidget {
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

  const _FiltreBar({
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
          icon:  Icons.calendar_month_outlined,
          label: 'Toutes les périodes',
          onTap: onFiltrePressed,
        ),
      _FiltreMode.mois => _DatePill(
          icon:  Icons.calendar_month_outlined,
          label: '${kMoisNoms[moisSelectionne - 1]} $anneeSelectionnee',
          onTap: onPickMois,
        ),
      _FiltreMode.semaine => _DatePill(
          icon:  Icons.date_range_outlined,
          label:
              '${DateFormat('dd/MM').format(semaineDebut)} – ${DateFormat('dd/MM/yyyy').format(semaineDebut.add(const Duration(days: 6)))}',
          onTap: onPickSemaine,
        ),
      _FiltreMode.jour => _DatePill(
          icon:  Icons.calendar_today_outlined,
          label: DateFormat('dd/MM/yyyy').format(jourSelectionne),
          onTap: onPickJour,
        ),
      _FiltreMode.periode => _DatePill(
          icon:  Icons.calendar_month_outlined,
          label:
              'Du ${DateFormat('dd/MM/yy').format(periodeDebut)} au ${DateFormat('dd/MM/yy').format(periodeFin)}',
          onTap: onPickPeriode,
        ),
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
              const Icon(Icons.filter_list_rounded, size: 14, color: _kPrimary),
              const SizedBox(width: 5),
              Text(modeLabel,
                  style: const TextStyle(
                      fontSize: 12,
                      color: _kPrimary,
                      fontWeight: FontWeight.w500)),
              const SizedBox(width: 3),
              const Icon(Icons.keyboard_arrow_down_rounded,
                  size: 14, color: _kPrimary),
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
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(10),
        ),
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
}

// ── Barre recherche + statuts ─────────────────────────────────────────────────

class _SearchAndStatutBar extends StatefulWidget {
  final TextEditingController controller;
  final void Function(String) onSearchChanged;
  final String? statutSelectionne;
  final void Function(String?) onStatutChanged;
  final List<String> statuts;
  final VoidCallback? onTunePressed;
  final bool hasActiveFilter;

  const _SearchAndStatutBar({
    required this.controller,
    required this.onSearchChanged,
    required this.statutSelectionne,
    required this.onStatutChanged,
    required this.statuts,
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
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 6),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          // Fond gris (aligné sur les champs de VehiculeFormPage) plutôt qu'un
          // blanc avec ombre portée.
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
              : const Icon(Icons.search, color: Color(0xFF8A8A8E), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              onChanged: widget.onSearchChanged,
              style: const TextStyle(fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Rechercher type, véhicule, prestataire…',
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
            _StatutChip(
              label:    'Tous',
              selected: widget.statutSelectionne == null,
              color:    Colors.grey.shade600,
              onTap:    () => widget.onStatutChanged(null),
            ),
            ...widget.statuts.map((s) => _StatutChip(
                  label:    _labelStatut(s),
                  selected: widget.statutSelectionne == s,
                  color:    _couleurStatut(s),
                  onTap:    () => widget.onStatutChanged(s),
                )),
          ],
        ),
      ),
      const SizedBox(height: 4),
    ]);
  }

  String _labelStatut(String s) => switch (s) {
        'PLANIFIEE' => 'Planifiée',
        'TERMINEE'  => 'Terminée',
        'ANNULEE'   => 'Annulée',
        _           => s,
      };

  Color _couleurStatut(String s) => switch (s) {
        'PLANIFIEE' => Colors.orange,
        'TERMINEE'  => Colors.green,
        'ANNULEE'   => Colors.grey,
        _           => Colors.blueGrey,
      };
}

class _StatutChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _StatutChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color:  selected ? color : Colors.white,
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
}

// ── Carte maintenance ─────────────────────────────────────────────────────────

class _MaintenanceCard extends StatelessWidget {
  final Maintenance maintenance;
  final NumberFormat money;
  final VoidCallback? onTap;
  const _MaintenanceCard(
      {required this.maintenance, required this.money, this.onTap});

  @override
  Widget build(BuildContext context) {
    final m     = maintenance;
    final color = _couleurStatut(m.statut ?? 'PLANIFIEE');

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
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(_iconeType(m.type), color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    m.categorieTypeLibelle?.isNotEmpty == true
                        ? m.categorieTypeLibelle!
                        : _labelType(m.type),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Color(0xFF1A1A1A))),
                const SizedBox(height: 3),
                Row(children: [
                  Flexible(
                    child: Text(
                      m.vehiculeNom ?? 'Véhicule ${m.vehiculeId ?? '—'}',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (m.vehiculeImmatriculation?.isNotEmpty == true) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: _kPrimary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        m.vehiculeImmatriculation!,
                        style: const TextStyle(
                            fontSize: 10,
                            color: _kPrimary,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.calendar_today_outlined,
                      size: 11, color: Colors.grey.shade400),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(_labelDate(m.datePrevue),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500)),
                  ),
                  if (m.dureeHeures != null) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.timer_outlined,
                        size: 11, color: Colors.grey.shade400),
                    const SizedBox(width: 3),
                    Text('${m.dureeHeures}h',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500)),
                  ],
                  if (m.detailMaintenance != null &&
                      m.detailMaintenance!.elements.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: _kAccent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${m.detailMaintenance!.elements.length} élém.',
                        style: const TextStyle(
                            fontSize: 10,
                            color: _kAccent,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ]),
              ],
            ),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_labelStatut(m.statut ?? 'PLANIFIEE'),
                  style: TextStyle(
                      fontSize: 10,
                      color: color,
                      fontWeight: FontWeight.w700)),
            ),
            if (m.cout != null && m.cout! > 0) ...[
              const SizedBox(height: 6),
              Text(money.format(m.cout),
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFB71C1C))),
            ],
          ]),
        ],
      ),
      ),
    );
  }

  String _labelDate(DateTime d) {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date  = DateTime(d.year, d.month, d.day);
    final diff  = date.difference(today).inDays;
    if (diff == 0)  return "Aujourd'hui";
    if (diff == 1)  return 'Demain';
    if (diff == -1) return 'Hier';
    if (diff > 1 && diff <= 7) return 'Dans $diff jours';
    return DateFormat('dd/MM/yyyy').format(d);
  }

  Color _couleurStatut(String s) => switch (s) {
        'PLANIFIEE' => Colors.orange,
        'TERMINEE'  => Colors.green,
        'ANNULEE'   => Colors.grey,
        _           => Colors.blueGrey,
      };

  String _labelStatut(String s) => switch (s) {
        'PLANIFIEE' => 'Planifiée',
        'TERMINEE'  => 'Terminée',
        'ANNULEE'   => 'Annulée',
        _           => s,
      };

  /// Icône dérivée du libellé de catégorie retourné par le backend.
  /// Aucun code de catégorie figé — correspondance sur mots-clés du libellé.
  IconData _iconeType(String t) {
    final u = t.toUpperCase();
    if (u.contains('VIDANGE'))     return Icons.oil_barrel_outlined;
    if (u.contains('REVISION'))    return Icons.settings_outlined;
    if (u.contains('REPARATION'))  return Icons.handyman_outlined;
    if (u.contains('CONTROLE'))    return Icons.fact_check_outlined;
    if (u.contains('PNEUMATIQUE')) return Icons.tire_repair_outlined;
    if (u.contains('FREINAGE'))    return Icons.emergency_outlined;
    if (u.contains('PARALISE') || u.contains('PARALYSIE')) {
      return Icons.car_crash_outlined;
    }
    if (u.contains('TOLERIE') || u.contains('TÔLERIE')) {
      return Icons.car_repair_outlined;
    }
    if (u.contains('PEINTURE'))    return Icons.brush_outlined;
    if (u.contains('ELECTRIC'))    return Icons.electrical_services_outlined;
    return Icons.construction_outlined;
  }

  /// Libellé de repli — utilisé uniquement si `categorieTypeLibelle` est absent.
  /// La valeur principale est toujours `m.categorieTypeLibelle` (données backend).
  String _labelType(String t) {
    final u = t.toUpperCase();
    if (u.contains('VIDANGE'))     return 'Vidange';
    if (u.contains('REVISION'))    return 'Révision';
    if (u.contains('REPARATION'))  return 'Réparation';
    if (u.contains('CONTROLE'))    return 'Contrôle technique';
    if (u.contains('PNEUMATIQUE')) return 'Pneumatiques';
    if (u.contains('FREINAGE'))    return 'Freinage';
    if (u.contains('PARALISE') || u.contains('PARALYSIE')) return 'Paralysie';
    if (u.contains('TOLERIE') || u.contains('TÔLERIE'))    return 'Tôlerie';
    if (u.contains('PEINTURE'))    return 'Peinture';
    if (u.contains('ELECTRIC'))    return 'Électricité';
    return t; // Retourner le libellé brut plutôt que 'Autre'
  }
}

// ── État vide ─────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Stack(alignment: Alignment.center, children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
          ),
          Icon(Icons.handyman_outlined, size: 38, color: Colors.grey.shade300),
        ]),
        const SizedBox(height: 16),
        Text('Aucune maintenance sur cette période',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600)),
        const SizedBox(height: 6),
        Text('Modifiez la période ou les filtres',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
      ]),
    );
  }
}

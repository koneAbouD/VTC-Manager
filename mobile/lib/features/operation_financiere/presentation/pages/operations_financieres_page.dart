import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../chauffeur/domain/entities/chauffeur.dart';
import '../../../vehicule/domain/entities/vehicule.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/filtre_vehicule_chauffeur_dialog.dart';
import '../../domain/entities/operation_financiere.dart';
import '../../domain/enums/statut_operation.dart';
import '../../domain/enums/type_operation.dart';
import '../providers/operations_liste_provider.dart';
import 'operation_financiere_detail_page.dart';
import 'operation_financiere_form_page.dart';
import '../../../../core/widgets/date_filter_dialogs.dart';

enum _FiltreMode { mois, semaine, jour, periode }

// ── Filtres par catégorie ──────────────────────────────────────────────────
// Les codes correspondent aux sous_categories_operation.code et libelle de la BDD.

enum _CategorieFiltre {
  recette,
  cotisation,
  penalite,
  maintenance,
  document;

  String get label => switch (this) {
        recette     => 'Recettes',
        cotisation  => 'Cotisations',
        penalite    => 'Pénalités',
        maintenance => 'Maintenance',
        document    => 'Documents',
      };

  Color get couleur => switch (this) {
        recette     => const Color(0xFF2E7D32),
        cotisation  => const Color(0xFFE65100),
        penalite    => const Color(0xFFB71C1C),
        maintenance => Colors.indigo,
        document    => Colors.blue,
      };

  /// Code catégorie envoyé au backend (encaissements), ou null.
  String? get categorieCodeParam => switch (this) {
        recette     => 'ENCAISSEMENT_RECETTES',
        cotisation  => 'ENCAISSEMENT_COTISATIONS',
        penalite    => 'ENCAISSEMENT_PENALITES',
        _           => null,
      };

  /// Libellé de sous-catégorie envoyé au backend (maintenance / document), ou null.
  String? get sousCategorieLibelleParam => switch (this) {
        maintenance => 'maintenances',
        document    => 'documents',
        _           => null,
      };
}

class OperationsFinancieresPage extends ConsumerStatefulWidget {
  const OperationsFinancieresPage({super.key});

  @override
  ConsumerState<OperationsFinancieresPage> createState() =>
      _OperationsFinancieresPageState();
}

class _OperationsFinancieresPageState
    extends ConsumerState<OperationsFinancieresPage> {
  _FiltreMode _filtreMode = _FiltreMode.mois;
  int _moisSelectionne = DateTime.now().month;
  int _anneeSelectionnee = DateTime.now().year;
  DateTime _jourSelectionne = DateTime.now();
  DateTime _semaineDebut = mondayOf(DateTime.now());
  DateTime _periodeDebut = DateTime.now().subtract(const Duration(days: 30));
  DateTime _periodeFin = DateTime.now();
  String _recherche = '';
  _CategorieFiltre? _categorieFiltre;
  Vehicule? _vehiculeFiltre;
  Chauffeur? _chauffeurFiltre;

  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _searchDebounce;
  OverlayEntry? _overlayEntry;
  final _filtreButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    Future.microtask(_loadWithFilters);
  }

  // Déclenche le chargement de la page suivante à l'approche du bas de liste.
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 300) {
      ref.read(operationsListeProvider.notifier).loadMore();
    }
  }

  // ── Plage de dates active ─────────────────────────────────────────────────

  (DateTime, DateTime) _plageActive() => switch (_filtreMode) {
        _FiltreMode.mois => (
            DateTime(_anneeSelectionnee, _moisSelectionne, 1),
            DateTime(_anneeSelectionnee, _moisSelectionne + 1, 0),
          ),
        _FiltreMode.semaine => (
            _semaineDebut,
            _semaineDebut.add(const Duration(days: 6)),
          ),
        _FiltreMode.jour => (_jourSelectionne, _jourSelectionne),
        _FiltreMode.periode => (_periodeDebut, _periodeFin),
      };

  // ── Rechargement backend avec dates ──────────────────────────────────────

  void _loadWithFilters() {
    final (debut, fin) = _plageActive();
    ref.read(operationsListeProvider.notifier).load(
          debut: DateFormat('yyyy-MM-dd').format(debut),
          fin: DateFormat('yyyy-MM-dd').format(fin),
          categorieCode: _categorieFiltre?.categorieCodeParam,
          sousCategorieLibelle: _categorieFiltre?.sousCategorieLibelleParam,
          vehiculeId: _vehiculeFiltre?.id,
          chauffeurId: _chauffeurFiltre?.id,
          recherche: _recherche.isEmpty ? null : _recherche,
        );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _searchDebounce?.cancel();
    _overlayEntry?.remove();
    super.dispose();
  }

  void _showFiltreOverlay() {
    _removeOverlay();
    final renderBox =
        _filtreButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (ctx) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _removeOverlay,
        child: Stack(
          children: [
            Positioned(
              left: offset.dx,
              top: offset.dy + size.height + 4,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 190,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: _FiltreMode.values.map((mode) {
                      final label = switch (mode) {
                        _FiltreMode.mois => 'Mois',
                        _FiltreMode.semaine => 'Semaine',
                        _FiltreMode.jour => 'Jour',
                        _FiltreMode.periode => 'Période',
                      };
                      final sel = _filtreMode == mode;
                      return InkWell(
                        onTap: () {
                          setState(() => _filtreMode = mode);
                          _removeOverlay();
                          _loadWithFilters();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
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
                              Text(
                                label,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: sel
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: sel
                                      ? const Color(0xFF43A047)
                                      : const Color(0xFF1A1A1A),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  // ── Popup filtre véhicule / chauffeur ─────────────────────────────────────

  Future<void> _showFiltreAvance() async {
    final result = await showFiltreVehiculeChauffeurDialog(
      context,
      vehiculeInitial:  _vehiculeFiltre,
      chauffeurInitial: _chauffeurFiltre,
    );

    if (result != null && mounted) {
      setState(() {
        _vehiculeFiltre  = result.vehicule;
        _chauffeurFiltre = result.chauffeur;
      });
      _loadWithFilters();
    }
  }

  Future<void> _pickPeriode() async {
    final result = await showDialog<DateTimeRange>(
      context: context,
      builder: (_) => PeriodePickerDialog(
        initialStart: _periodeDebut,
        initialEnd: _periodeFin,
      ),
    );
    if (result != null) {
      setState(() {
        _periodeDebut = result.start;
        _periodeFin   = result.end;
      });
      _loadWithFilters();
    }
  }

  Future<void> _pickSemaine() async {
    final result = await showDialog<DateTime>(
      context: context,
      builder: (_) => WeekPickerDialog(initialWeekStart: _semaineDebut),
    );
    if (result != null) {
      setState(() => _semaineDebut = result);
      _loadWithFilters();
    }
  }

  Future<void> _pickMois() async {
    final result = await showDialog<DateTime>(
      context: context,
      builder: (_) => MonthPickerDialog(
        initialYear: _anneeSelectionnee,
        initialMonth: _moisSelectionne,
      ),
    );
    if (result != null) {
      setState(() {
        _moisSelectionne   = result.month;
        _anneeSelectionnee = result.year;
      });
      _loadWithFilters();
    }
  }

  Future<void> _pickJour() async {
    final result = await showDialog<DateTime>(
      context: context,
      builder: (_) =>
          SingleDatePickerDialog(initialDate: _jourSelectionne),
    );
    if (result != null) {
      setState(() => _jourSelectionne = result);
      _loadWithFilters();
    }
  }

  // Recherche : rechargement serveur après une courte temporisation (évite un
  // appel réseau à chaque frappe). Le filtrage (catégorie, véhicule, chauffeur,
  // texte) et le tri sont désormais gérés côté backend, page par page.
  void _onSearchChanged(String v) {
    setState(() => _recherche = v);
    _searchDebounce?.cancel();
    _searchDebounce =
        Timer(const Duration(milliseconds: 400), _loadWithFilters);
  }

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(
        locale: 'fr_FR', symbol: 'XOF', decimalDigits: 0);
    final state = ref.watch(operationsListeProvider);
    final ops = state.items;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppHeader(
        title: 'Opérations',
        action: AppHeaderAction(
          icon: Icons.add_rounded,
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const OperationFinanciereFormPage()),
            );
            if (!mounted) return;
            ref.read(operationsListeProvider.notifier).refresh();
          },
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Corps ─────────────────────────────────────────────────
            Expanded(
              child: state.initialLoading && ops.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: () => ref
                          .read(operationsListeProvider.notifier)
                          .refresh(),
                      child: CustomScrollView(
                        controller: _scrollController,
                        slivers: [
                          // ── Filtre date ────────────────────────────
                          SliverToBoxAdapter(
                            child: _FiltreBar(
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

                          // ── Recherche ──────────────────────────────
                          SliverToBoxAdapter(
                            child: _SearchBarWidget(
                              controller: _searchController,
                              onChanged: _onSearchChanged,
                              onTunePressed: _showFiltreAvance,
                              hasActiveFilter: _vehiculeFiltre != null ||
                                  _chauffeurFiltre != null,
                            ),
                          ),

                          // ── Filtre catégorie ───────────────────────
                          SliverToBoxAdapter(
                            child: _CategorieChipBar(
                              selected: _categorieFiltre,
                              onChanged: (c) {
                                setState(() => _categorieFiltre = c);
                                _loadWithFilters();
                              },
                            ),
                          ),

                          // ── Liste / état vide / loader bas de page ──
                          if (ops.isEmpty)
                            const SliverFillRemaining(child: _EmptyState())
                          else
                            SliverPadding(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 10, 16, 24),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (_, i) {
                                    if (i >= ops.length) {
                                      return const _LoadMoreTile();
                                    }
                                    final op = ops[i];
                                    return _OpCard(
                                      op: op,
                                      money: money,
                                      onTap: () async {
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                OperationFinanciereDetailPage(
                                              operation: op,
                                            ),
                                          ),
                                        );
                                        if (!mounted) return;
                                        ref
                                            .read(operationsListeProvider
                                                .notifier)
                                            .refresh();
                                      },
                                    );
                                  },
                                  childCount:
                                      ops.length + (state.hasMore ? 1 : 0),
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

// ── Barre de filtre ────────────────────────────────────────────────────────

class _FiltreBar extends StatelessWidget {
  final _FiltreMode mode;
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
      _FiltreMode.mois => 'Mois',
      _FiltreMode.semaine => 'Semaine',
      _FiltreMode.jour => 'Jour',
      _FiltreMode.periode => 'Période',
    };

    final datePill = switch (mode) {
      _FiltreMode.mois => _DatePill(
          icon: Icons.calendar_month_outlined,
          label: '${kMoisNoms[moisSelectionne - 1]} $anneeSelectionnee',
          onTap: onPickMois,
        ),
      _FiltreMode.semaine => _DatePill(
          icon: Icons.date_range_outlined,
          label: '${DateFormat('dd/MM').format(semaineDebut)}'
              ' – ${DateFormat('dd/MM/yyyy').format(semaineDebut.add(const Duration(days: 6)))}',
          onTap: onPickSemaine,
        ),
      _FiltreMode.jour => _DatePill(
          icon: Icons.calendar_today_outlined,
          label: DateFormat('dd/MM/yyyy').format(jourSelectionne),
          onTap: onPickJour,
        ),
      _FiltreMode.periode => _DatePill(
          icon: Icons.calendar_month_outlined,
          label: 'Du ${DateFormat('dd/MM/yyyy').format(periodeDebut)}'
              ' au ${DateFormat('dd/MM/yyyy').format(periodeFin)}',
          onTap: onPickPeriode,
        ),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          GestureDetector(
            key: filtreKey,
            onTap: onFiltrePressed,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.filter_list_rounded,
                      size: 14, color: Color(0xFF43A047)),
                  const SizedBox(width: 5),
                  Text(
                    modeLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF43A047),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 3),
                  const Icon(Icons.keyboard_arrow_down_rounded,
                      size: 14, color: Color(0xFF43A047)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: datePill),
        ],
      ),
    );
  }
}

// ── Pill de date (style unifié pour les 3 modes) ──────────────────────────

class _DatePill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DatePill({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 13, color: Colors.grey.shade600),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 5),
            Icon(Icons.keyboard_arrow_down_rounded,
                size: 14, color: Colors.grey.shade600),
          ],
        ),
      ),
    );
  }
}

// ── Barre de recherche ─────────────────────────────────────────────────────

class _SearchBarWidget extends StatelessWidget {
  final TextEditingController controller;
  final void Function(String) onChanged;
  final VoidCallback? onTunePressed;
  final bool hasActiveFilter;

  const _SearchBarWidget({
    required this.controller,
    required this.onChanged,
    this.onTunePressed,
    this.hasActiveFilter = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: Color(0xFF8A8A8E), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: const TextStyle(fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Rechercher une opération...',
                hintStyle:
                    TextStyle(color: Color(0xFF8A8A8E), fontSize: 14),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          TuneFilterButton(
            onTap:  onTunePressed,
            active: hasActiveFilter,
          ),
        ],
      ),
    );
  }
}

// ── Carte opération ────────────────────────────────────────────────────────

class _OpCard extends StatelessWidget {
  final OperationFinanciere op;
  final NumberFormat money;
  final VoidCallback onTap;

  const _OpCard({
    required this.op,
    required this.money,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isRevenu = op.typeOperation == TypeOperation.REVENU;
    final amountColor =
        isRevenu ? const Color(0xFF2E7D32) : const Color(0xFFC62828);
    final sign = isRevenu ? '+' : '-';

    // Ligne 1 : « [Catégorie opération] [d'hier / du JJ/MM/AAAA] »
    // La date relative (recalculée à l'affichage) n'est ajoutée que pour les
    // encaissements ; les autres opérations (ex. Vidange) s'affichent sans date.
    final titre = op.libelleLigne;

    // Ligne 2 : « [imat véhicule - Nom chauffeur] »
    final vehiculeChauffeur = [
      if (op.vehiculeNom != null) op.vehiculeNom!,
      if (op.chauffeurNom != null) op.chauffeurNom!,
    ].join(' - ');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
          children: [
            // ── Icône (revenu / dépense), à l'image de l'accueil ──────────
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: amountColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isRevenu
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
                color: amountColor,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Ligne 1 : catégorie + date · (badge) · montant ──────
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          titre,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Color(0xFF1A1A1A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (op.statut == StatutOperation.ANNULEE)
                  _StatusBadge(label: 'Echec', color: Colors.red.shade400),
                const SizedBox(width: 8),
                Text(
                  '$sign${NumberFormat('#,##0', 'fr_FR').format(op.montant)} XOF',
                  style: TextStyle(
                    color: amountColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            // ── Ligne 2 : véhicule - chauffeur · date ─────────────────────
            Row(
              children: [
                Expanded(
                  child: Text(
                    vehiculeChauffeur,
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  DateFormat('dd/MM', 'fr_FR').format(op.dateAffichee),
                  style: TextStyle(
                      fontSize: 10, color: Colors.grey.shade400),
                ),
              ],
            ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Chips filtre catégorie ─────────────────────────────────────────────────

class _CategorieChipBar extends StatelessWidget {
  final _CategorieFiltre? selected;
  final void Function(_CategorieFiltre?) onChanged;

  const _CategorieChipBar({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _CategoryChip(
            label: 'Tous',
            selected: selected == null,
            color: Colors.grey.shade600,
            onTap: () => onChanged(null),
          ),
          ..._CategorieFiltre.values.map((c) => _CategoryChip(
                label: c.label,
                selected: selected == c,
                color: c.couleur,
                onTap: () => onChanged(c),
              )),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _CategoryChip({
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
          color: selected ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? color : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }
}

// ── Badge statut ───────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ── Popup filtre avancé → voir core/widgets/filtre_vehicule_chauffeur_dialog.dart

// ── Loader bas de liste (scroll infini) ─────────────────────────────────────

class _LoadMoreTile extends StatelessWidget {
  const _LoadMoreTile();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

// ── État vide ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
              ),
              Icon(Icons.description_outlined,
                  size: 38, color: Colors.grey.shade300),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Aucun résultat',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Aucune opération trouvée',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }
}

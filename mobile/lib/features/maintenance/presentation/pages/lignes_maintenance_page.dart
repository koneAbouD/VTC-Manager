import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/date_filter_dialogs.dart';
import '../../../../core/widgets/motif_annulation_dialog.dart';
import '../../../etat_parc/presentation/providers/etat_parc_provider.dart';
import '../../../vehicule/domain/entities/vehicule.dart';
import '../../../vehicule/presentation/pages/vehicule_selector_page.dart';
import '../../domain/entities/maintenance.dart';
import '../../domain/entities/synthese_maintenances.dart';
import '../providers/maintenance_provider.dart';
import '../../../../core/pagination/paged_list_notifier.dart';
import '../widgets/maintenance_visuels.dart';
import '../widgets/terminer_maintenance_dialog.dart';
import 'maintenance_detail_page.dart';
import 'maintenance_form_page.dart';
import '../../../../screens/finance/finance_refresh.dart';
import '../../../../core/widgets/statut_filtre_chip.dart';

// ── Constantes ────────────────────────────────────────────────────────────────

enum _FiltreMode { mois, semaine, jour, periode }

/// Tuiles affichées avant « Tout voir » : trois rangées de deux.
const _kTuilesVisibles = 6;

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

  /// Statut choisi ; exclusif avec [_enRetard], qui en est un sous-ensemble
  /// calculé (planifiée dont la date est passée).
  String?  _statutFiltre;
  bool     _enRetard           = false;
  String   _recherche          = '';
  bool     _rechercheOuverte   = false;

  int?    _vehiculeId;
  String? _vehiculeImmatriculation;

  /// Types cochés dans la mosaïque (identifiants de catégorie).
  final Set<int> _typesCoches = {};

  /// Compteurs de l'écran, calculés par le serveur. Null pendant le premier
  /// chargement ou après un échec : les tuiles se masquent, la liste reste.
  SyntheseMaintenances? _synthese;

  /// Dernier libellé connu de chaque type : un type coché qui n'a plus
  /// d'intervention sur la période garde sa tuile, sinon on ne pourrait plus
  /// le décocher.
  final Map<int, TotalMaintenanceParType> _typesConnus = {};

  /// Écarte les réponses de synthèse arrivées après une demande plus récente.
  int _jetonSynthese = 0;

  /// Hauteur des filtres et de la mosaïque : passée cette distance de
  /// défilement, la mosaïque se replie en une rangée de puces épinglée.
  double _hauteurEntete = 0;
  bool   _grilleRepliee = false;

  final _searchController  = TextEditingController();
  final _searchFocus       = FocusNode();
  final _scrollController  = ScrollController();
  OverlayEntry? _overlayEntry;
  final _filtreButtonKey   = GlobalKey();

  /// La recherche part au serveur : on attend une pause de frappe pour ne pas
  /// lancer une requête par caractère.
  Timer? _debounceRecherche;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    Future.microtask(() => _load());
  }

  @override
  void dispose() {
    _debounceRecherche?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
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
    final repliee = _hauteurEntete > 0 && pos.pixels > _hauteurEntete - 8;
    if (repliee != _grilleRepliee) setState(() => _grilleRepliee = repliee);
  }

  /// Frappe dans la barre de recherche : on laisse retomber la saisie avant
  /// d'interroger le serveur.
  void _onRechercheChanged(String valeur) {
    _debounceRecherche?.cancel();
    _debounceRecherche = Timer(const Duration(milliseconds: 400), () {
      if (!mounted || valeur.trim() == _recherche.trim()) return;
      setState(() => _recherche = valeur);
      _load();
    });
  }

  void _basculerRecherche() {
    if (_rechercheOuverte) {
      // Refermer la barre vide aussi la recherche : un filtre invisible
      // laisserait croire que la liste est complète.
      _searchFocus.unfocus();
      final avaitTexte = _searchController.text.isNotEmpty;
      _searchController.clear();
      _debounceRecherche?.cancel();
      setState(() {
        _rechercheOuverte = false;
        _recherche = '';
      });
      if (avaitTexte) _load();
    } else {
      setState(() => _rechercheOuverte = true);
      _searchFocus.requestFocus();
    }
  }

  // ── Chargement (filtres serveur) ──────────────────────────────────────────

  String? _jour(DateTime? d) =>
      d != null ? DateFormat('yyyy-MM-dd').format(d) : null;

  void _load() {
    final (debut, fin) = _plageActive();
    final repo = ref.read(maintenanceRepositoryProvider);
    final types = _typesCoches.toList();
    ref.read(maintenancesListeProvider.notifier).load(
          (page, size) => repo.getMaintenancesPage(
            page: page,
            size: size,
            dateDebut: _jour(debut),
            dateFin: _jour(fin),
            statut: _statutFiltre,
            vehiculeId: _vehiculeId,
            recherche: _recherche,
            categorieTypeIds: types,
            enRetard: _enRetard,
          ),
        );
    _chargerSynthese();
  }

  Future<void> _chargerSynthese() async {
    final jeton = ++_jetonSynthese;
    final (debut, fin) = _plageActive();
    final result = await ref.read(maintenanceRepositoryProvider).getSynthese(
          dateDebut: _jour(debut),
          dateFin: _jour(fin),
          vehiculeId: _vehiculeId,
          recherche: _recherche,
          categorieTypeIds: _typesCoches.toList(),
        );
    if (!mounted || jeton != _jetonSynthese) return;
    result.fold(
      (_) => setState(() => _synthese = null),
      (synthese) => setState(() {
        _synthese = synthese;
        for (final t in synthese.parType) {
          _typesConnus[t.categorieTypeId] = t;
        }
      }),
    );
  }

  Future<void> _refresh() => Future.wait([
        ref.read(maintenancesListeProvider.notifier).refresh(),
        _chargerSynthese(),
      ]);

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

  // ── Filtres ───────────────────────────────────────────────────────────────

  void _basculerType(int id) {
    setState(() {
      if (!_typesCoches.remove(id)) _typesCoches.add(id);
    });
    _load();
  }

  void _effacerTypes() {
    if (_typesCoches.isEmpty) return;
    setState(_typesCoches.clear);
    _load();
  }

  void _choisirStatut(String? statut, {bool enRetard = false}) {
    setState(() {
      _statutFiltre = enRetard ? null : statut;
      _enRetard = enRetard;
    });
    _load();
  }

  Future<void> _choisirVehicule() async {
    final result = await Navigator.push<Vehicule>(
      context,
      MaterialPageRoute(builder: (_) => const VehiculeSelectorPage()),
    );
    if (result == null || !mounted) return;
    setState(() {
      _vehiculeId = result.id;
      _vehiculeImmatriculation = result.immatriculation;
    });
    _load();
  }

  void _effacerVehicule() {
    setState(() {
      _vehiculeId = null;
      _vehiculeImmatriculation = null;
    });
    _load();
  }

  /// Types présentés en tuiles : ceux de la synthèse, plus les types cochés
  /// qui n'y figurent plus (aucune intervention sur la nouvelle sélection).
  List<TotalMaintenanceParType> _typesAffiches() {
    final synthese = _synthese;
    if (synthese == null) return const [];
    final presents = {for (final t in synthese.parType) t.categorieTypeId};
    return [
      ...synthese.parType,
      for (final id in _typesCoches)
        if (!presents.contains(id) && _typesConnus[id] != null)
          TotalMaintenanceParType(
            categorieTypeId: id,
            code: _typesConnus[id]!.code,
            libelle: _typesConnus[id]!.libelle,
            nombre: 0,
            coutRealise: 0,
          ),
    ];
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
                  color: AppColors.blanc,
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
                            color: sel ? AppColors.primary : AppColors.grey400,
                          ),
                          const SizedBox(width: 10),
                          Text(label,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: sel
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: sel
                                    ? AppColors.primary
                                    : AppColors.dark,
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

  // ── Navigation et actions rapides ─────────────────────────────────────────

  Future<void> _nouvelle({int? categorieTypeId}) async {
    final cree = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => MaintenanceFormPage(
              categorieTypeInitialeId: categorieTypeId)),
    );
    if (cree == true && mounted) _load();
  }

  Future<void> _ouvrirFiche(Maintenance m) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => MaintenanceDetailPage(maintenance: m),
      ),
    );
    if (result == true && mounted) {
      _load();
      refreshFinances(ref);
    }
  }

  void _toast(String message, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Row(children: [
          Icon(
            error
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white)),
          ),
        ]),
        backgroundColor: error ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        duration:
            error ? const Duration(seconds: 4) : const Duration(seconds: 2),
      ));
  }

  /// Après une action rapide : la liste, ses compteurs et l'état du véhicule
  /// (immobilisation, retour en service) ont pu changer.
  void _apresAction(String message) {
    _toast(message);
    _load();
    ref.invalidate(etatParcSummaryProvider);
  }

  Future<void> _actionsRapides(Maintenance m) async {
    HapticFeedback.mediumImpact();
    final action = await showModalBottomSheet<_ActionRapide>(
      context: context,
      useSafeArea: true,
      backgroundColor: AppColors.scaffold,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ActionsRapidesSheet(maintenance: m),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case _ActionRapide.terminer:
        await _terminer(m);
      case _ActionRapide.reporter:
        await _reporter(m);
      case _ActionRapide.annuler:
        await _annuler(m);
      case _ActionRapide.fiche:
        await _ouvrirFiche(m);
    }
  }

  String _libelleType(Maintenance m) =>
      m.categorieTypeLibelle?.isNotEmpty == true
          ? m.categorieTypeLibelle!
          : m.type;

  Future<void> _terminer(Maintenance m) async {
    final choix = await showTerminerMaintenanceDialog(
      context,
      titre: 'Terminer la maintenance',
      message: 'Renseignez le coût réel des travaux pour clôturer cette '
          'maintenance.',
      typeLabel: _libelleType(m),
      partenaireNom: m.partenaireNom,
      elements: m.detailMaintenance?.elements ?? const [],
    );
    if (choix == null || !mounted) return;
    final result = await ref.read(maintenanceRepositoryProvider)
        .completeMaintenance(m.id!, choix.cout,
            aCredit: choix.aCredit, dateEcheance: choix.echeance);
    if (!mounted) return;
    result.fold(
      (failure) => _toast(failure.message, error: true),
      (_) {
        // Une clôture produit une dépense, ou une dette envers le
        // prestataire : les écrans Finances doivent la montrer sans attendre.
        refreshFinances(ref);
        _apresAction('Maintenance terminée');
      },
    );
  }

  Future<void> _reporter(Maintenance m) async {
    final now = DateTime.now();
    final aujourdhui = DateTime(now.year, now.month, now.day);
    // Reporter, c'est repousser : la nouvelle date part d'aujourd'hui. Une
    // date passée ferait passer l'intervention pour déjà réalisée.
    final nouvelle = await showDialog<DateTime>(
      context: context,
      builder: (_) => SingleDatePickerDialog(
        initialDate:
            m.datePrevue.isBefore(aujourdhui) ? aujourdhui : m.datePrevue,
        firstDate: aujourdhui,
        lastDate: DateTime(2100),
      ),
    );
    if (nouvelle == null || !mounted) return;
    final result = await ref.read(maintenanceRepositoryProvider)
        .updateMaintenance(m.id!, m.copyWith(datePrevue: nouvelle));
    if (!mounted) return;
    result.fold(
      (failure) => _toast(failure.message, error: true),
      (_) => _apresAction(
          'Reportée au ${DateFormat('dd/MM/yyyy').format(nouvelle)}'),
    );
  }

  Future<void> _annuler(Maintenance m) async {
    // Même popup que la fiche : le motif est obligatoire, il reste attaché à
    // l'intervention abandonnée.
    final motif = await showMotifAnnulationDialog(
      context,
      titre: 'Annuler la maintenance ?',
      message: 'L\'intervention quittera le programme du véhicule mais restera '
          'à son historique. Indiquez le motif de l\'annulation.',
    );
    if (motif == null || !mounted) return;
    final result = await ref.read(maintenanceRepositoryProvider)
        .annulerMaintenance(m.id!, motif);
    if (!mounted) return;
    result.fold(
      (failure) => _toast(failure.message, error: true),
      (_) => _apresAction('Maintenance annulée'),
    );
  }

  // ── Feuille « Tout voir » ─────────────────────────────────────────────────

  Future<void> _toutVoir(NumberFormat money) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.scaffold,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) => _TousTypesSheet(
          types: _typesAffiches(),
          coches: _typesCoches,
          money: money,
          onToggle: (id) {
            _basculerType(id);
            setSheet(() {});
          },
          onEffacer: () {
            _effacerTypes();
            setSheet(() {});
          },
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(
        locale: 'fr_FR', symbol: 'XOF', decimalDigits: 0);
    final state = ref.watch(maintenancesListeProvider);
    final items = state.items;
    final types = _typesAffiches();

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
                _BoutonEntete(
                  icon: Icons.arrow_back_rounded,
                  onTap: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Text(
                    'Maintenances',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.dark,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                _BoutonEntete(
                  icon: _rechercheOuverte
                      ? Icons.search_off_rounded
                      : Icons.search_rounded,
                  compact: true,
                  actif: _rechercheOuverte,
                  onTap: _basculerRecherche,
                ),
                const SizedBox(width: 8),
                _BoutonEntete(
                  icon: Icons.add_rounded,
                  compact: true,
                  onTap: () => _nouvelle(),
                ),
              ]),
            ),

            if (_rechercheOuverte)
              _SearchBar(
                controller: _searchController,
                focusNode: _searchFocus,
                onSearchChanged: _onRechercheChanged,
              ),

            // ── Corps ──────────────────────────────────────────────────
            Expanded(
              child: Stack(children: [
                RefreshIndicator(
                  onRefresh: _refresh,
                  child: CustomScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: _MesureTaille(
                          onChange: (taille) =>
                              _hauteurEntete = taille.height,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _FiltreBar(
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
                                vehiculeImmatriculation:
                                    _vehiculeImmatriculation,
                                onPickVehicule:    _choisirVehicule,
                                onEffacerVehicule: _effacerVehicule,
                              ),
                              if (types.isNotEmpty)
                                _MosaiqueTypes(
                                  types: types,
                                  coches: _typesCoches,
                                  money: money,
                                  onToggle: _basculerType,
                                  onNouvelle: (t) => _nouvelle(
                                      categorieTypeId: t.categorieTypeId),
                                  onToutVoir: () => _toutVoir(money),
                                ),
                            ],
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: _PastillesStatut(
                          synthese: _synthese,
                          statut: _statutFiltre,
                          enRetard: _enRetard,
                          onChoisir: _choisirStatut,
                        ),
                      ),
                      if (state.initialLoading && items.isEmpty)
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (items.isEmpty)
                        const SliverFillRemaining(
                            hasScrollBody: false, child: _EmptyState())
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (_, i) {
                                if (i >= items.length) {
                                  return const PagedListLoadMoreTile();
                                }
                                final m = items[i];
                                return _MaintenanceCard(
                                  maintenance: m,
                                  money: money,
                                  onTap: () => _ouvrirFiche(m),
                                  onLongPress: m.estModifiable
                                      ? () => _actionsRapides(m)
                                      : null,
                                );
                              },
                              childCount:
                                  items.length + (state.hasMore ? 1 : 0),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // ── Mosaïque repliée, épinglée au défilement ─────────────
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: IgnorePointer(
                    ignoring: !_grilleRepliee || types.isEmpty,
                    child: AnimatedSlide(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      offset: _grilleRepliee && types.isNotEmpty
                          ? Offset.zero
                          : const Offset(0, -1),
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: _grilleRepliee && types.isNotEmpty ? 1 : 0,
                        child: _RangeeTypes(
                          types: types,
                          coches: _typesCoches,
                          onToggle: _basculerType,
                        ),
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Mesure de la hauteur de l'en-tête défilant ───────────────────────────────

/// Signale la taille de son enfant après chaque mise en page où elle change :
/// la page en déduit le seuil où la mosaïque se replie.
class _MesureTaille extends SingleChildRenderObjectWidget {
  final ValueChanged<Size> onChange;

  const _MesureTaille({required this.onChange, required Widget super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMesureTaille(onChange);

  @override
  void updateRenderObject(
      BuildContext context, _RenderMesureTaille renderObject) {
    renderObject.onChange = onChange;
  }
}

class _RenderMesureTaille extends RenderProxyBox {
  ValueChanged<Size> onChange;
  Size? _derniere;

  _RenderMesureTaille(this.onChange);

  @override
  void performLayout() {
    super.performLayout();
    final taille = size;
    if (taille == _derniere) return;
    _derniere = taille;
    WidgetsBinding.instance.addPostFrameCallback((_) => onChange(taille));
  }
}

// ── En-tête ───────────────────────────────────────────────────────────────────

class _BoutonEntete extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool compact;
  final bool actif;

  const _BoutonEntete({
    required this.icon,
    required this.onTap,
    this.compact = false,
    this.actif = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: compact ? 40 : 56,
        height: 38,
        decoration: BoxDecoration(
          color: actif
              ? AppColors.primary.withValues(alpha: 0.12)
              : AppColors.headerButton,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(icon,
            size: compact ? 19 : 18,
            color: actif ? AppColors.primary : AppColors.dark),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final void Function(String) onSearchChanged;

  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        // Fond gris (aligné sur les champs de VehiculeFormPage) plutôt qu'un
        // blanc avec ombre portée ; contour à l'accent pendant la saisie.
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary, width: 1.5),
      ),
      child: Row(children: [
        Icon(Icons.search, color: AppColors.hint, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            onChanged: onSearchChanged,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Type, immatriculation, prestataire…',
              hintStyle: TextStyle(color: AppColors.hint, fontSize: 14),
              border: InputBorder.none,
              // Le cadre est porté par la boîte grise : sans cela, le thème
              // dessinerait son propre fond et son contour à l'intérieur.
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        // Croix d'effacement : la recherche partant au serveur, il faut
        // pouvoir revenir à la liste complète sans effacer au clavier.
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (_, value, __) => value.text.isEmpty
              ? const SizedBox.shrink()
              : GestureDetector(
                  onTap: () {
                    controller.clear();
                    onSearchChanged('');
                  },
                  child: Icon(Icons.close_rounded,
                      size: 18, color: AppColors.hint),
                ),
        ),
      ]),
    );
  }
}

// ── Barre filtre date + véhicule ──────────────────────────────────────────────

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
  final String? vehiculeImmatriculation;
  final VoidCallback onPickVehicule;
  final VoidCallback onEffacerVehicule;

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
    required this.vehiculeImmatriculation,
    required this.onPickVehicule,
    required this.onEffacerVehicule,
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
              color: AppColors.blanc,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.grey300),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.filter_list_rounded, size: 14, color: AppColors.primary),
              const SizedBox(width: 5),
              Text(modeLabel,
                  style: TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500)),
              const SizedBox(width: 3),
              Icon(Icons.keyboard_arrow_down_rounded,
                  size: 14, color: AppColors.primary),
            ]),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(flex: 3, child: datePill),
        const SizedBox(width: 8),
        Flexible(
          flex: 2,
          child: _VehiculePill(
            immatriculation: vehiculeImmatriculation,
            onTap: onPickVehicule,
            onEffacer: onEffacerVehicule,
          ),
        ),
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
          color: AppColors.grey200,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          Icon(icon, size: 13, color: AppColors.grey600),
          const SizedBox(width: 6),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.grey700,
                    fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 5),
          Icon(Icons.keyboard_arrow_down_rounded,
              size: 14, color: AppColors.grey600),
        ]),
      ),
    );
  }
}

/// Filtre véhicule : le sélecteur de véhicules existant, et une croix pour
/// revenir à toute la flotte.
class _VehiculePill extends StatelessWidget {
  final String? immatriculation;
  final VoidCallback onTap;
  final VoidCallback onEffacer;

  const _VehiculePill({
    required this.immatriculation,
    required this.onTap,
    required this.onEffacer,
  });

  @override
  Widget build(BuildContext context) {
    final actif = immatriculation != null;
    final couleur = actif ? AppColors.primary : AppColors.grey600;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: actif
              ? AppColors.primary.withValues(alpha: 0.12)
              : AppColors.grey200,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          Icon(Icons.directions_car_outlined, size: 13, color: couleur),
          const SizedBox(width: 6),
          Expanded(
            child: Text(immatriculation ?? 'Véhicule',
                style: TextStyle(
                    fontSize: 12,
                    color: actif ? AppColors.primary : AppColors.grey700,
                    fontWeight: actif ? FontWeight.w700 : FontWeight.w500),
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 4),
          if (actif)
            GestureDetector(
              onTap: onEffacer,
              child: Icon(Icons.close_rounded, size: 14, color: couleur),
            )
          else
            Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: couleur),
        ]),
      ),
    );
  }
}

// ── Mosaïque des types ────────────────────────────────────────────────────────

class _MosaiqueTypes extends StatelessWidget {
  final List<TotalMaintenanceParType> types;
  final Set<int> coches;
  final NumberFormat money;
  final void Function(int) onToggle;
  final void Function(TotalMaintenanceParType) onNouvelle;
  final VoidCallback onToutVoir;

  const _MosaiqueTypes({
    required this.types,
    required this.coches,
    required this.money,
    required this.onToggle,
    required this.onNouvelle,
    required this.onToutVoir,
  });

  @override
  Widget build(BuildContext context) {
    // Les six plus fréquents, plus tout type coché au-delà : une sélection
    // active doit rester visible pour pouvoir être défaite.
    final visibles = [
      for (var i = 0; i < types.length; i++)
        if (i < _kTuilesVisibles || coches.contains(types[i].categorieTypeId))
          types[i],
    ];
    final coutTotal = types.fold(0.0, (s, t) => s + t.coutRealise);

    final rangees = <Widget>[];
    for (var i = 0; i < visibles.length; i += 2) {
      rangees.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Expanded(child: _tuile(visibles[i], coutTotal)),
          const SizedBox(width: 8),
          Expanded(
            child: i + 1 < visibles.length
                ? _tuile(visibles[i + 1], coutTotal)
                : const SizedBox.shrink(),
          ),
        ]),
      ));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Expanded(
                child: Text(
                  'TYPES DE MAINTENANCE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.hint,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              if (types.length > _kTuilesVisibles)
                GestureDetector(
                  onTap: onToutVoir,
                  child: Text(
                    'Tout voir (${types.length})',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
            ]),
          ),
          ...rangees,
        ],
      ),
    );
  }

  Widget _tuile(TotalMaintenanceParType t, double coutTotal) => _TuileType(
        type: t,
        coche: coches.contains(t.categorieTypeId),
        part: coutTotal > 0 ? t.coutRealise / coutTotal : 0,
        money: money,
        onTap: () => onToggle(t.categorieTypeId),
        onLongPress: () => onNouvelle(t),
      );
}

class _TuileType extends StatelessWidget {
  final TotalMaintenanceParType type;
  final bool coche;

  /// Part du type dans le coût réalisé de toute la sélection (0 à 1).
  final double part;
  final NumberFormat money;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _TuileType({
    required this.type,
    required this.coche,
    required this.part,
    required this.money,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final visuel = TypeMaintenanceVisuel.de(
        code: type.code, libelle: type.libelle, id: type.categorieTypeId);
    final couleur = visuel.couleur;

    return Semantics(
      button: true,
      selected: coche,
      label: '${type.libelle}, ${type.nombre} interventions',
      child: GestureDetector(
        onTap: onTap,
        onLongPress: () {
          HapticFeedback.mediumImpact();
          onLongPress();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
          decoration: BoxDecoration(
            color: coche
                ? Color.alphaBlend(
                    couleur.withValues(alpha: 0.08), AppColors.blanc)
                : AppColors.blanc,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: coche ? couleur : Colors.transparent,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: couleur.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(visuel.icone, size: 16, color: couleur),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text(
                            type.libelle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.dark,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${type.nombre}',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: couleur,
                          ),
                        ),
                      ]),
                      const SizedBox(height: 1),
                      Text(
                        money.format(type.coutRealise),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10.5, color: AppColors.hint),
                      ),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 7),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: part.clamp(0.0, 1.0),
                  minHeight: 3,
                  backgroundColor: AppColors.fieldFill,
                  valueColor: AlwaysStoppedAnimation(couleur),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mosaïque repliée : une rangée de puces colorées qui garde la sélection de
/// types sous la main pendant qu'on parcourt la liste.
class _RangeeTypes extends StatelessWidget {
  final List<TotalMaintenanceParType> types;
  final Set<int> coches;
  final void Function(int) onToggle;

  const _RangeeTypes({
    required this.types,
    required this.coches,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.scaffold,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ],
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: types.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final t = types[i];
          final coche = coches.contains(t.categorieTypeId);
          final couleur = TypeMaintenanceVisuel.de(
                  code: t.code, libelle: t.libelle, id: t.categorieTypeId)
              .couleur;
          return GestureDetector(
            onTap: () => onToggle(t.categorieTypeId),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: coche
                    ? Color.alphaBlend(
                        couleur.withValues(alpha: 0.12), AppColors.surface)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: coche ? couleur : AppColors.border),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration:
                      BoxDecoration(color: couleur, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(
                  '${t.libelle} ${t.nombre}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: coche ? FontWeight.w700 : FontWeight.w500,
                    color: coche ? couleur : AppColors.label,
                  ),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }
}

class _TousTypesSheet extends StatelessWidget {
  final List<TotalMaintenanceParType> types;
  final Set<int> coches;
  final NumberFormat money;
  final void Function(int) onToggle;
  final VoidCallback onEffacer;

  const _TousTypesSheet({
    required this.types,
    required this.coches,
    required this.money,
    required this.onToggle,
    required this.onEffacer,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.grey300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 16, 8),
            child: Row(children: [
              Expanded(
                child: Text(
                  'Types de maintenance',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.dark,
                  ),
                ),
              ),
              if (coches.isNotEmpty)
                TextButton(
                  onPressed: onEffacer,
                  child: Text('Effacer',
                      style: TextStyle(color: AppColors.primary)),
                ),
            ]),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.fromLTRB(
                  16, 0, 16, 16 + MediaQuery.of(context).padding.bottom),
              itemCount: types.length,
              itemBuilder: (_, i) {
                final t = types[i];
                final coche = coches.contains(t.categorieTypeId);
                final visuel = TypeMaintenanceVisuel.de(
                    code: t.code, libelle: t.libelle, id: t.categorieTypeId);
                return GestureDetector(
                  onTap: () => onToggle(t.categorieTypeId),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.blanc,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: coche ? visuel.couleur : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Row(children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: visuel.couleur.withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(visuel.icone,
                            size: 18, color: visuel.couleur),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.libelle,
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.dark)),
                            Text(
                              '${t.nombre} intervention${t.nombre > 1 ? 's' : ''}'
                              ' · ${money.format(t.coutRealise)}',
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.hint),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        coche
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: coche ? visuel.couleur : AppColors.grey400,
                        size: 22,
                      ),
                    ]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pastilles de statut ───────────────────────────────────────────────────────

class _PastillesStatut extends StatelessWidget {
  final SyntheseMaintenances? synthese;
  final String? statut;
  final bool enRetard;
  final void Function(String? statut, {bool enRetard}) onChoisir;

  const _PastillesStatut({
    required this.synthese,
    required this.statut,
    required this.enRetard,
    required this.onChoisir,
  });

  @override
  Widget build(BuildContext context) {
    final s = synthese;
    // Compteurs serveur ; sans synthèse (chargement, échec), les libellés
    // restent seuls plutôt que d'afficher un nombre faux.
    String avec(String libelle, int? n) => n == null ? libelle : '$libelle $n';
    final enCours = s?.nombre('EN_COURS') ?? 0;

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            StatutFiltreChip(
              label: avec('Tous', s?.total),
              selected: statut == null && !enRetard,
              color: AppColors.hint,
              onTap: () => onChoisir(null),
            ),
            StatutFiltreChip(
              label: avec(StatutMaintenanceVisuel.libellePluriel('PLANIFIEE'),
                  s?.nombre('PLANIFIEE')),
              selected: statut == 'PLANIFIEE',
              color: StatutMaintenanceVisuel.couleur('PLANIFIEE'),
              onTap: () => onChoisir('PLANIFIEE'),
            ),
            _PastilleRetard(
              label: avec('En retard', s?.enRetard),
              selected: enRetard,
              onTap: () => onChoisir(null, enRetard: true),
            ),
            if (enCours > 0 || statut == 'EN_COURS')
              StatutFiltreChip(
                label: avec(StatutMaintenanceVisuel.libellePluriel('EN_COURS'),
                    s?.nombre('EN_COURS')),
                selected: statut == 'EN_COURS',
                color: StatutMaintenanceVisuel.couleur('EN_COURS'),
                onTap: () => onChoisir('EN_COURS'),
              ),
            StatutFiltreChip(
              label: avec(StatutMaintenanceVisuel.libellePluriel('TERMINEE'),
                  s?.nombre('TERMINEE')),
              selected: statut == 'TERMINEE',
              color: StatutMaintenanceVisuel.couleur('TERMINEE'),
              onTap: () => onChoisir('TERMINEE'),
            ),
            StatutFiltreChip(
              label: avec(StatutMaintenanceVisuel.libellePluriel('ANNULEE'),
                  s?.nombre('ANNULEE')),
              selected: statut == 'ANNULEE',
              color: StatutMaintenanceVisuel.couleur('ANNULEE'),
              onTap: () => onChoisir('ANNULEE'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pastille du retard : rouge même au repos, c'est ce qui demande une action.
class _PastilleRetard extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PastilleRetard({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final rouge = StatutMaintenanceVisuel.retard;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.only(right: 8),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? rouge.withValues(alpha: 0.12) : AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? rouge.withValues(alpha: 0.6)
                  : rouge.withValues(alpha: 0.35),
            ),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.schedule_rounded, size: 13, color: rouge),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: rouge,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Carte maintenance ─────────────────────────────────────────────────────────

class _MaintenanceCard extends StatelessWidget {
  final Maintenance maintenance;
  final NumberFormat money;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  const _MaintenanceCard({
    required this.maintenance,
    required this.money,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final m      = maintenance;
    final statut = m.statut ?? 'PLANIFIEE';
    final visuel = TypeMaintenanceVisuel.de(
        code: m.type, libelle: m.categorieTypeLibelle, id: m.categorieTypeId);
    final couleurStatut = StatutMaintenanceVisuel.couleur(statut);
    final retard = StatutMaintenanceVisuel.joursDeRetard(statut, m.datePrevue);

    // Une intervention au programme n'a pas encore de coût : on montre ce que
    // ses éléments annoncent, en retrait, pour ne pas le confondre avec un
    // montant payé.
    final estime = (m.detailMaintenance?.elements ?? const [])
        .fold(0.0, (s, e) => s + e.montant);
    final aCout = m.cout != null && m.cout! > 0;
    final aEstime = !aCout && m.isPending && estime > 0;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.blanc,
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
          // La pastille d'icône porte la couleur du type : c'est elle qui se
          // repère d'un coup d'œil dans la liste, le statut a son badge.
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: visuel.couleur.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(visuel.icone, color: visuel.couleur, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    m.categorieTypeLibelle?.isNotEmpty == true
                        ? m.categorieTypeLibelle!
                        : m.type,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.dark)),
                const SizedBox(height: 3),
                // Immatriculation seule : elle suffit à désigner le véhicule.
                // Repli sur l'identifiant tant qu'elle n'est pas renseignée,
                // pour que la carte ne reste jamais muette sur le véhicule.
                Text(
                  m.vehiculeImmatriculation?.isNotEmpty == true
                      ? m.vehiculeImmatriculation!
                      : 'Véhicule ${m.vehiculeId ?? '—'}',
                  style: TextStyle(
                      fontSize: 10,
                      color: AppColors.grey600,
                      fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                if (retard > 0)
                  Row(children: [
                    Icon(Icons.schedule_rounded,
                        size: 12, color: StatutMaintenanceVisuel.retard),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'En retard · $retard j',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: StatutMaintenanceVisuel.retard),
                      ),
                    ),
                  ])
                else
                  Row(children: [
                    Icon(Icons.calendar_today_outlined,
                        size: 11, color: AppColors.grey400),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                          [
                            _labelDate(m.datePrevue),
                            if (m.partenaireNom?.isNotEmpty == true)
                              m.partenaireNom!,
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11, color: AppColors.grey500)),
                    ),
                    if (m.dureeHeures != null) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.timer_outlined,
                          size: 11, color: AppColors.grey400),
                      const SizedBox(width: 3),
                      Text('${m.dureeHeures}h',
                          style: TextStyle(
                              fontSize: 11, color: AppColors.grey500)),
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
                color: couleurStatut.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(StatutMaintenanceVisuel.libelle(statut),
                  style: TextStyle(
                      fontSize: 10,
                      color: couleurStatut,
                      fontWeight: FontWeight.w700)),
            ),
            if (aCout) ...[
              const SizedBox(height: 6),
              Text(money.format(m.cout),
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.dark)),
            ] else if (aEstime) ...[
              const SizedBox(height: 6),
              Text('≈ ${money.format(estime)}',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.hint)),
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
}

// ── Actions rapides (appui long) ──────────────────────────────────────────────

enum _ActionRapide { terminer, reporter, annuler, fiche }

class _ActionsRapidesSheet extends StatelessWidget {
  final Maintenance maintenance;

  const _ActionsRapidesSheet({required this.maintenance});

  @override
  Widget build(BuildContext context) {
    final m = maintenance;
    final visuel = TypeMaintenanceVisuel.de(
        code: m.type, libelle: m.categorieTypeLibelle, id: m.categorieTypeId);
    final retard =
        StatutMaintenanceVisuel.joursDeRetard(m.statut, m.datePrevue);
    final libelle = m.categorieTypeLibelle?.isNotEmpty == true
        ? m.categorieTypeLibelle!
        : m.type;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 10, 16, 16 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.grey300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: visuel.couleur.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(visuel.icone, size: 20, color: visuel.couleur),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(libelle,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.dark)),
                  Text(
                    [
                      if (m.vehiculeImmatriculation?.isNotEmpty == true)
                        m.vehiculeImmatriculation!,
                      retard > 0
                          ? 'en retard de $retard j'
                          : 'prévue le ${DateFormat('dd/MM/yyyy').format(m.datePrevue)}',
                    ].join(' · '),
                    style: TextStyle(
                        fontSize: 12,
                        color: retard > 0
                            ? StatutMaintenanceVisuel.retard
                            : AppColors.hint),
                  ),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 14),
          _LigneAction(
            icon: Icons.check_circle_outline_rounded,
            label: 'Terminer',
            couleur: AppColors.positive,
            onTap: () => Navigator.pop(context, _ActionRapide.terminer),
          ),
          _LigneAction(
            icon: Icons.event_outlined,
            label: 'Reporter',
            couleur: AppColors.dark,
            onTap: () => Navigator.pop(context, _ActionRapide.reporter),
          ),
          _LigneAction(
            icon: Icons.cancel_outlined,
            label: 'Annuler',
            couleur: AppColors.error,
            onTap: () => Navigator.pop(context, _ActionRapide.annuler),
          ),
          _LigneAction(
            icon: Icons.open_in_new_rounded,
            label: 'Voir la fiche',
            couleur: AppColors.label,
            onTap: () => Navigator.pop(context, _ActionRapide.fiche),
          ),
        ],
      ),
    );
  }
}

class _LigneAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color couleur;
  final VoidCallback onTap;

  const _LigneAction({
    required this.icon,
    required this.label,
    required this.couleur,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.blanc,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Icon(icon, size: 20, color: couleur),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: couleur)),
          ),
          Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.hint),
        ]),
      ),
    );
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
              color: AppColors.grey100,
              shape: BoxShape.circle,
            ),
          ),
          Icon(Icons.handyman_outlined, size: 38, color: AppColors.grey300),
        ]),
        const SizedBox(height: 16),
        Text('Aucune maintenance',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.grey600)),
        const SizedBox(height: 6),
        Text('Modifiez la période ou les filtres',
            style: TextStyle(fontSize: 13, color: AppColors.grey400)),
      ]),
    );
  }
}

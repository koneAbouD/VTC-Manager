import 'dart:async';

import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/encaissement.dart';
import '../../domain/entities/ligne_recette.dart';
import '../providers/ligne_recette_provider.dart';
import '../../../../core/pagination/paged_list_notifier.dart';
import '../../../../core/widgets/encaissement_ligne_dialog.dart';
import '../../../../features/operation_financiere/presentation/providers/operation_financiere_provider.dart';
import 'ligne_recette_detail_page.dart';
import '../../../../core/widgets/date_filter_dialogs.dart';
import '../../../../core/widgets/long_press_info_bubble.dart';

// ── Constantes partagées ───────────────────────────────────────────────────

enum _FiltreMode { mois, semaine, jour, periode }

/// Libellé d'une ligne : « Immatriculation - Nom chauffeur »
/// (immatriculation seule si le nom du chauffeur est absent).
String _libelleVehiculeChauffeur(LigneRecette ligne) {
  final immat = ligne.vehiculeImmatriculation ?? 'Véhicule ${ligne.vehiculeId}';
  final nom = ligne.chauffeurNom;
  return (nom != null && nom.isNotEmpty) ? '$immat - $nom' : immat;
}

// ── Page principale ────────────────────────────────────────────────────────

class LignesRecettePage extends ConsumerStatefulWidget {
  const LignesRecettePage({super.key});

  @override
  ConsumerState<LignesRecettePage> createState() => _LignesRecettePageState();
}

class _LignesRecettePageState extends ConsumerState<LignesRecettePage> {
  // null = aucun filtre par date (toutes périodes) — comportement par défaut.
  _FiltreMode? _filtreMode;
  int _moisSelectionne = DateTime.now().month;
  int _anneeSelectionnee = DateTime.now().year;
  // J-1 par défaut : les recettes du jour sont généralement encaissées et
  // consultées le lendemain (clôture de la veille).
  DateTime _jourSelectionne = DateTime.now().subtract(const Duration(days: 1));
  DateTime _semaineDebut = mondayOf(DateTime.now());
  DateTime _periodeDebut = DateTime.now().subtract(const Duration(days: 30));
  DateTime _periodeFin = DateTime.now();
  StatutLigneRecette? _statutFiltre;
  String _recherche = '';

  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  OverlayEntry? _overlayEntry;
  final _filtreButtonKey = GlobalKey();

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
    _scrollController.dispose();
    _overlayEntry?.remove();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 300) {
      ref.read(lignesRecetteListeProvider.notifier).loadMore();
    }
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

  // Filtres serveur (date + statut + recherche), page par page.
  void _load() {
    final (dateDebut, dateFin) = _plageActive();
    final repo = ref.read(ligneRecetteRepositoryProvider);
    ref.read(lignesRecetteListeProvider.notifier).load(
          (page, size) => repo.getLignesPage(
            page: page,
            size: size,
            statut: _statutFiltre,
            dateDebut: dateDebut,
            dateFin: dateFin,
            recherche: _recherche,
          ),
        );
  }

  // (null, null) quand aucun filtre par date n'est actif.
  (DateTime?, DateTime?) _plageActive() {
    return switch (_filtreMode) {
      null => (null, null),
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
                        null => 'Tous',
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
                          _load();
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
        _moisSelectionne = result.month;
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
        initialEnd: _periodeFin,
      ),
    );
    if (result != null) {
      setState(() {
        _periodeDebut = result.start;
        _periodeFin = result.end;
      });
      _load();
    }
  }

  Future<void> _openEncaisserDialog(LigneRecette ligne) async {
    final repo   = ref.read(ligneRecetteRepositoryProvider);
    final result = await showEncaissementLigneDialog(
      context,
      titre:          'Recette',
      sousTitre:      _libelleVehiculeChauffeur(ligne),
      montantRestant: ligne.montantRestant,
      couleur:        const Color(0xFF2E7D32),
      icone:          Icons.account_balance_wallet_outlined,
      onEncaisser: (saisie) async {
        final enc = Encaissement(
          ligneRecetteId:   ligne.id!,
          montant:          saisie.montant,
          modeEncaissement: saisie.mode == ModeEncaissementSaisie.mobileMoney
              ? ModeEncaissement.mobileMoney
              : ModeEncaissement.especes,
          dateEncaissement: saisie.date,
          reference:        saisie.reference,
          commentaire:      saisie.commentaire,
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
        await ref.read(ligneRecetteRepositoryProvider).generer();
    final error = result.fold((f) => f.message, (_) => null);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lignes d'hier générées avec succès.")),
      );
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final money =
        NumberFormat.currency(locale: 'fr_FR', symbol: 'XOF', decimalDigits: 0);
    final state = ref.watch(lignesRecetteListeProvider);
    final filtered = state.items;

    // Montant (attendu) par statut sur les lignes chargées, null = total.
    double sommeRec(bool Function(LigneRecette) test) => filtered
        .where(test)
        .fold(0.0, (s, l) => s + (l.montantAttendu ?? l.montantEncaisse));
    final montantsStatut = <StatutLigneRecette?, double>{
      null: sommeRec((_) => true),
      for (final s in StatutLigneRecette.values) s: sommeRec((l) => l.statut == s),
    };

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
                      width: 56,
                      height: 38,
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
                      'Recettes',
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
                    onTap: _generer,
                    child: Container(
                      width: 56,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F2F8),
                        borderRadius: BorderRadius.circular(20),
                      ),
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
                  : RefreshIndicator(
                      onRefresh: () =>
                          ref.read(lignesRecetteListeProvider.notifier).refresh(),
                      child: CustomScrollView(
                        controller: _scrollController,
                        slivers: [
                          // ── Filtre date ──────────────────────────────
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

                          // ── Filtre statut + recherche ────────────────
                          SliverToBoxAdapter(
                            child: _SearchAndStatutBar(
                              controller: _searchController,
                              onSearchChanged: _onRechercheChanged,
                              statutSelectionne: _statutFiltre,
                              onStatutChanged: (s) {
                                setState(() => _statutFiltre = s);
                                _load();
                              },
                              montantsStatut: montantsStatut,
                              money: money,
                            ),
                          ),

                          // ── Liste / état vide / loader bas de page ───
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
                                    final ligne = filtered[i];
                                    return _LigneCard(
                                      ligne: ligne,
                                      money: money,
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => LigneRecetteDetailPage(
                                            ligneId: ligne.id!,
                                          ),
                                        ),
                                      ).then((_) => _load()),
                                      onEncaisser: ligne.estActive
                                          ? () => _openEncaisserDialog(ligne)
                                          : null,
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

// ── Barre filtre date ──────────────────────────────────────────────────────

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
      null => 'Tous',
      _FiltreMode.mois => 'Mois',
      _FiltreMode.semaine => 'Semaine',
      _FiltreMode.jour => 'Jour',
      _FiltreMode.periode => 'Période',
    };

    final Widget datePill = switch (mode) {
      // Carte de valeur statique quand aucun filtre par date n'est actif.
      null => _DatePill(
          icon: Icons.calendar_month_outlined,
          label: 'Toutes les périodes',
          onTap: onFiltrePressed,
        ),
      _FiltreMode.mois => _DatePill(
          icon: Icons.calendar_month_outlined,
          label: '${kMoisNoms[moisSelectionne - 1]} $anneeSelectionnee',
          onTap: onPickMois,
        ),
      _FiltreMode.semaine => _DatePill(
          icon: Icons.date_range_outlined,
          label:
              '${DateFormat('dd/MM').format(semaineDebut)} – ${DateFormat('dd/MM/yyyy').format(semaineDebut.add(const Duration(days: 6)))}',
          onTap: onPickSemaine,
        ),
      _FiltreMode.jour => _DatePill(
          icon: Icons.calendar_today_outlined,
          label: DateFormat('dd/MM/yyyy').format(jourSelectionne),
          onTap: onPickJour,
        ),
      _FiltreMode.periode => _DatePill(
          icon: Icons.calendar_month_outlined,
          label:
              'Du ${DateFormat('dd/MM/yyyy').format(periodeDebut)} au ${DateFormat('dd/MM/yyyy').format(periodeFin)}',
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

class _DatePill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DatePill({required this.icon, required this.label, required this.onTap});

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

// ── Barre recherche + filtre statut ───────────────────────────────────────

class _SearchAndStatutBar extends StatefulWidget {
  final TextEditingController controller;
  final void Function(String) onSearchChanged;
  final StatutLigneRecette? statutSelectionne;
  final void Function(StatutLigneRecette?) onStatutChanged;
  final Map<StatutLigneRecette?, double> montantsStatut;
  final NumberFormat money;

  const _SearchAndStatutBar({
    required this.controller,
    required this.onSearchChanged,
    required this.statutSelectionne,
    required this.onStatutChanged,
    required this.montantsStatut,
    required this.money,
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
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 6),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            // Fond gris (aligné sur les champs de VehiculeFormPage) plutôt
            // qu'un blanc avec ombre portée.
            color: const Color(0xFFF2F3F5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
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
                    hintText: 'Immatriculation, chauffeur…',
                    hintStyle:
                        TextStyle(color: Color(0xFF8A8A8E), fontSize: 14),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              // Croix d'effacement : la recherche partant au serveur, il faut
              // pouvoir revenir à la liste complète sans effacer au clavier.
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: widget.controller,
                builder: (_, value, __) => value.text.isEmpty
                    ? const SizedBox.shrink()
                    : GestureDetector(
                        onTap: () {
                          widget.controller.clear();
                          widget.onSearchChanged('');
                        },
                        child: const Icon(Icons.close_rounded,
                            size: 18, color: Color(0xFF8A8A8E)),
                      ),
              ),
            ],
          ),
        ),
        // Chips de filtre statut
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _StatutChip(
                label: 'Tous',
                selected: widget.statutSelectionne == null,
                color: _hint,
                onTap: () => widget.onStatutChanged(null),
                infoText: widget.money.format(widget.montantsStatut[null] ?? 0),
              ),
              ...StatutLigneRecette.values.map((s) => _StatutChip(
                    label: s.label,
                    selected: widget.statutSelectionne == s,
                    color: _couleurStatut(s),
                    onTap: () => widget.onStatutChanged(s),
                    infoText:
                        widget.money.format(widget.montantsStatut[s] ?? 0),
                  )),
            ],
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  /// Palette des chips de statut : trois teintes seulement — gris pour
  /// l'attente et les fins de course neutres, bleu pour l'encaissement
  /// commencé mais pas terminé, vert pour ce qui est soldé.
  static const _bleu = Color(0xFF1565C0);
  static const _vert = Color(0xFF2E7D32);
  static const _hint = Color(0xFF8A94A6);

  Color _couleurStatut(StatutLigneRecette s) => switch (s) {
        StatutLigneRecette.enAttente => _hint,
        StatutLigneRecette.partiellementEncaisse => _bleu,
        StatutLigneRecette.encaisse => _vert,
        StatutLigneRecette.annulee => _hint,
      };
}

class _StatutChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  /// Montant à afficher dans l'info-bulle au long-press (montant du statut).
  final String? infoText;

  const _StatutChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
    this.infoText,
  });

  @override
  Widget build(BuildContext context) {
    // Fond, bordure et texte repris des chips de statut de ContraventionsPage :
    // le chip sélectionné se teinte de sa couleur au lieu de s'en remplir.
    final chip = Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? color.withValues(alpha: 0.12) : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? color.withValues(alpha: 0.5) : AppColors.border,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? color : AppColors.label,
        ),
      ),
    );

    if (infoText == null) {
      return GestureDetector(onTap: onTap, child: chip);
    }
    return LongPressInfoBubble(
      onTap: onTap,
      infoText: infoText!,
      color: color,
      child: chip,
    );
  }
}

// ── Carte ligne de recette ────────────────────────────────────────────────

class _LigneCard extends StatelessWidget {
  final LigneRecette ligne;
  final NumberFormat money;
  final VoidCallback  onTap;
  final VoidCallback? onEncaisser;

  const _LigneCard({
    required this.ligne,
    required this.money,
    required this.onTap,
    this.onEncaisser,
  });

  String _labelDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    final diff = today.difference(d).inDays;

    if (diff == 0) return "Aujourd'hui";
    if (diff == 1) return 'Hier';
    if (diff < 7) {
      const jours = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
      return jours[date.weekday - 1];
    }
    return DateFormat('dd/MM/yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final color = _couleurStatut(ligne.statut);
    final montantRestant = ligne.montantAttendu != null
        ? (ligne.montantAttendu! - ligne.montantEncaisse).clamp(0, double.infinity)
        : null;
    // Toujours ce qui manque, encaissement partiel compris : c'est le reste à
    // recouvrer qui appelle une action. Le total est rappelé juste en dessous.
    final montantPrincipal = montantRestant;
    final montantAttenduDifferent = montantPrincipal != null &&
        montantPrincipal != ligne.montantAttendu;

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
            // Icône statut
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(_iconeStatut(ligne.statut), color: color, size: 19),
            ),
            const SizedBox(width: 12),

            // Infos gauche
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _libelleVehiculeChauffeur(ligne),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _labelDate(ligne.dateRecette),
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Montants + bouton encaisser (droite)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Montant toujours en noir : l'état de l'encaissement se lit
                // déjà sur l'icône et la pastille de statut.
                if (montantPrincipal != null)
                  Text(
                    '${NumberFormat('#,##0', 'fr_FR').format(montantPrincipal)} XOF',
                    style: const TextStyle(
                      color: AppColors.dark,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  )
                else
                  Text(
                    '+${NumberFormat('#,##0', 'fr_FR').format(ligne.montantEncaisse)} XOF',
                    style: const TextStyle(
                      color: AppColors.dark,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                if (montantAttenduDifferent)
                  Text(
                    'sur ${NumberFormat('#,##0', 'fr_FR').format(ligne.montantAttendu)} XOF',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                  ),
                if (onEncaisser != null) ...[
                  const SizedBox(height: 6),
                  EncaisserChip(onTap: onEncaisser!),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Même palette que les chips de filtre : la pastille d'icône reprend la
  /// couleur du statut telle qu'elle est présentée en haut de page.
  Color _couleurStatut(StatutLigneRecette s) => switch (s) {
        StatutLigneRecette.enAttente => const Color(0xFF8A94A6),
        StatutLigneRecette.partiellementEncaisse => const Color(0xFF1565C0),
        StatutLigneRecette.encaisse => const Color(0xFF2E7D32),
        StatutLigneRecette.annulee => const Color(0xFF8A94A6),
      };

  IconData _iconeStatut(StatutLigneRecette s) => switch (s) {
        StatutLigneRecette.enAttente => Icons.hourglass_empty_rounded,
        StatutLigneRecette.partiellementEncaisse => Icons.hourglass_top_rounded,
        StatutLigneRecette.encaisse => Icons.check_circle_rounded,
        StatutLigneRecette.annulee => Icons.cancel_rounded,
      };
}


// ── État vide ─────────────────────────────────────────────────────────────

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
              Icon(Icons.receipt_long_outlined,
                  size: 38, color: Colors.grey.shade300),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Aucune ligne de recette',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Appuyez sur ✨ pour générer les lignes du jour',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}


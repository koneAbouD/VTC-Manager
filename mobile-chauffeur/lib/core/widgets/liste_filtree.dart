import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../error/exception.dart';

const _kMois = [
  'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
  'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
];

enum _Mode { tous, jour, semaine, mois, periode }

String _modeLabel(_Mode m) => switch (m) {
      _Mode.tous => 'Tous',
      _Mode.jour => 'Jour',
      _Mode.semaine => 'Semaine',
      _Mode.mois => 'Mois',
      _Mode.periode => 'Période',
    };

/// Option de filtre par statut (chip).
class StatutOption {
  final String? value; // null = « Tous »
  final String label;
  final Color color;
  const StatutOption({required this.value, required this.label, required this.color});
}

/// Liste filtrable réutilisable (charte app gestionnaire) : barre de filtre par
/// date (Tous/Jour/Semaine/Mois/Période), barre de recherche, chips de statut,
/// puis la liste filtrée. Corps seul (sans Scaffold/AppBar).
class ListeFiltree<T> extends StatefulWidget {
  final AsyncValue<List<T>> valeur;
  final Future<void> Function() onRefresh;
  final Widget Function(T item) itemBuilder;
  final DateTime? Function(T item) dateOf;
  final String Function(T item) rechercheOf;
  final String? Function(T item)? statutOf;
  final List<StatutOption> statuts;
  final String messageVide;
  final String hintRecherche;

  const ListeFiltree({
    super.key,
    required this.valeur,
    required this.onRefresh,
    required this.itemBuilder,
    required this.dateOf,
    required this.rechercheOf,
    this.statutOf,
    this.statuts = const [],
    this.messageVide = 'Aucun élément.',
    this.hintRecherche = 'Rechercher...',
  });

  @override
  State<ListeFiltree<T>> createState() => _ListeFiltreeState<T>();
}

class _ListeFiltreeState<T> extends State<ListeFiltree<T>> {
  _Mode _mode = _Mode.tous;
  DateTime _jour = DateUtils.dateOnly(DateTime.now());
  DateTime _semaineDebut = _lundiDe(DateTime.now());
  int _mois = DateTime.now().month;
  int _annee = DateTime.now().year;
  DateTime? _periodeDebut;
  DateTime? _periodeFin;

  final _searchCtrl = TextEditingController();
  String _recherche = '';
  String? _statut;

  final GlobalKey _modeKey = GlobalKey();
  OverlayEntry? _overlay;

  static DateTime _lundiDe(DateTime d) =>
      DateUtils.dateOnly(d).subtract(Duration(days: d.weekday - 1));

  @override
  void dispose() {
    _searchCtrl.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  // ── Filtrage ────────────────────────────────────────────────────────────
  List<T> _filtrer(List<T> items) {
    return items.where((it) {
      // Date
      if (_mode != _Mode.tous) {
        final d = widget.dateOf(it);
        if (d == null) return false;
        final jour = DateUtils.dateOnly(d);
        final ok = switch (_mode) {
          _Mode.jour => jour == _jour,
          _Mode.semaine => !jour.isBefore(_semaineDebut) &&
              !jour.isAfter(_semaineDebut.add(const Duration(days: 6))),
          _Mode.mois => jour.month == _mois && jour.year == _annee,
          _Mode.periode => _periodeDebut != null &&
              _periodeFin != null &&
              !jour.isBefore(_periodeDebut!) &&
              !jour.isAfter(_periodeFin!),
          _Mode.tous => true,
        };
        if (!ok) return false;
      }
      // Statut
      if (_statut != null && widget.statutOf != null) {
        if ((widget.statutOf!(it) ?? '').toUpperCase() != _statut!.toUpperCase()) {
          return false;
        }
      }
      // Recherche
      if (_recherche.isNotEmpty) {
        if (!widget.rechercheOf(it).toLowerCase().contains(_recherche.toLowerCase())) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  // ── Pickers ─────────────────────────────────────────────────────────────
  Future<void> _pickJour() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _jour,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _jour = DateUtils.dateOnly(d));
  }

  Future<void> _pickSemaine() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _semaineDebut,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Choisir un jour de la semaine',
    );
    if (d != null) setState(() => _semaineDebut = _lundiDe(d));
  }

  Future<void> _pickMois() async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime(_annee, _mois),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Choisir un mois',
    );
    if (d != null) {
      setState(() {
        _mois = d.month;
        _annee = d.year;
      });
    }
  }

  Future<void> _pickPeriode() async {
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: (_periodeDebut != null && _periodeFin != null)
          ? DateTimeRange(start: _periodeDebut!, end: _periodeFin!)
          : null,
    );
    if (r != null) {
      setState(() {
        _periodeDebut = DateUtils.dateOnly(r.start);
        _periodeFin = DateUtils.dateOnly(r.end);
      });
    }
  }

  void _onModeChoisi(_Mode m) {
    _removeOverlay();
    setState(() => _mode = m);
    switch (m) {
      case _Mode.jour:
        _pickJour();
      case _Mode.semaine:
        _pickSemaine();
      case _Mode.mois:
        _pickMois();
      case _Mode.periode:
        _pickPeriode();
      case _Mode.tous:
        break;
    }
  }

  void _showModeOverlay() {
    _removeOverlay();
    final box = _modeKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final offset = box.localToGlobal(Offset.zero);
    _overlay = OverlayEntry(
      builder: (_) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _removeOverlay,
        child: Stack(
          children: [
            Positioned(
              left: offset.dx,
              top: offset.dy + box.size.height + 4,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 150,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: _Mode.values.map((m) {
                      final sel = _mode == m;
                      return InkWell(
                        onTap: () => _onModeChoisi(m),
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
                              Text(_modeLabel(m),
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: sel
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      color: sel
                                          ? const Color(0xFF43A047)
                                          : const Color(0xFF1A1A1A))),
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
    Overlay.of(context).insert(_overlay!);
  }

  String get _dateLabel => switch (_mode) {
        _Mode.tous => 'Toutes les périodes',
        _Mode.jour => DateFormat('dd/MM/yyyy').format(_jour),
        _Mode.semaine =>
          '${DateFormat('dd/MM').format(_semaineDebut)} – ${DateFormat('dd/MM/yyyy').format(_semaineDebut.add(const Duration(days: 6)))}',
        _Mode.mois => '${_kMois[_mois - 1]} $_annee',
        _Mode.periode => (_periodeDebut != null && _periodeFin != null)
            ? 'Du ${DateFormat('dd/MM/yyyy').format(_periodeDebut!)} au ${DateFormat('dd/MM/yyyy').format(_periodeFin!)}'
            : 'Choisir une période',
      };

  void _onDatePillTap() {
    switch (_mode) {
      case _Mode.jour:
        _pickJour();
      case _Mode.semaine:
        _pickSemaine();
      case _Mode.mois:
        _pickMois();
      case _Mode.periode:
        _pickPeriode();
      case _Mode.tous:
        _showModeOverlay();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _filtreBar(),
        _searchBar(),
        if (widget.statuts.isNotEmpty) _statutChips(),
        const SizedBox(height: 4),
        Expanded(
          child: RefreshIndicator(
            onRefresh: widget.onRefresh,
            child: widget.valeur.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _message(Icons.error_outline_rounded, messageFromError(e)),
              data: (items) {
                final filtered = _filtrer(items);
                if (filtered.isEmpty) {
                  return _message(Icons.inbox_rounded, widget.messageVide);
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => widget.itemBuilder(filtered[i]),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // ── Barre de filtre date ────────────────────────────────────────────────
  Widget _filtreBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          GestureDetector(
            key: _modeKey,
            onTap: _showModeOverlay,
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
                  Text(_modeLabel(_mode),
                      style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF43A047),
                          fontWeight: FontWeight.w500)),
                  const SizedBox(width: 3),
                  const Icon(Icons.keyboard_arrow_down_rounded,
                      size: 14, color: Color(0xFF43A047)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: _onDatePillTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_month_outlined,
                        size: 13, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(_dateLabel,
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 5),
                    Icon(Icons.keyboard_arrow_down_rounded,
                        size: 14, color: Colors.grey.shade600),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Barre de recherche ──────────────────────────────────────────────────
  Widget _searchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 1)),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: Color(0xFF8A8A8E), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _recherche = v),
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: widget.hintRecherche,
                hintStyle:
                    const TextStyle(color: Color(0xFF8A8A8E), fontSize: 14),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          if (_recherche.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchCtrl.clear();
                setState(() => _recherche = '');
              },
              child: const Icon(Icons.close, color: Color(0xFF8A8A8E), size: 18),
            ),
        ],
      ),
    );
  }

  // ── Chips de statut ─────────────────────────────────────────────────────
  Widget _statutChips() {
    final options = [
      const StatutOption(value: null, label: 'Tous', color: Colors.grey),
      ...widget.statuts,
    ];
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: options.map((o) {
          final sel = _statut == o.value;
          return GestureDetector(
            onTap: () => setState(() => _statut = o.value),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: sel ? o.color : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: sel ? o.color : Colors.grey.shade300),
              ),
              child: Text(o.label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: sel ? Colors.white : Colors.grey.shade600)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _message(IconData icone, String texte) => ListView(
        children: [
          const SizedBox(height: 100),
          Icon(icone, size: 56, color: Colors.black26),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(texte,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54)),
          ),
        ],
      );
}

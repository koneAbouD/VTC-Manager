import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

// ── Constantes partagées ──────────────────────────────────────────────────────

const kMoisNoms = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
  'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
];

DateTime mondayOf(DateTime d) => d.subtract(Duration(days: d.weekday - 1));

// ── Chrome premium partagé (feuille ancrée en bas + molette) ──────────────────

/// Style de texte commun aux molettes Cupertino de ce fichier.
const _kWheelTheme = CupertinoThemeData(
  textTheme: CupertinoTextThemeData(
    dateTimePickerTextStyle: TextStyle(fontSize: 20, color: AppColors.dark),
  ),
);

/// Feuille ancrée en bas (poignée + contenu), sans titre ni boutons — à l'image
/// du sélecteur de date. Le [entete] optionnel s'insère entre la poignée et la
/// molette (ex. libellé de semaine, bascule Début/Fin).
///
/// Comme le bottom sheet « marque », on peut la refermer :
/// - en **tapant la poignée** ;
/// - en la **faisant glisser vers le bas** ;
/// - en tapant en dehors (barrière).
/// Dans tous les cas la valeur courante est appliquée (via `Navigator.maybePop`
/// → le `PopScope` de chaque dialog renvoie la valeur).
class _WheelSheet extends StatefulWidget {
  final Widget child;
  final Widget? entete;

  const _WheelSheet({required this.child, this.entete});

  @override
  State<_WheelSheet> createState() => _WheelSheetState();
}

class _WheelSheetState extends State<_WheelSheet> {
  double _drag = 0; // déplacement vertical courant pendant le glisser

  void _onDragUpdate(DragUpdateDetails d) {
    setState(() => _drag = (_drag + d.delta.dy).clamp(0.0, 500.0));
  }

  void _onDragEnd(DragEndDetails d) {
    final vitesse = d.velocity.pixelsPerSecond.dy;
    if (_drag > 90 || vitesse > 700) {
      Navigator.maybePop(context); // applique la valeur puis ferme
    } else {
      setState(() => _drag = 0); // pas assez : on revient en place
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.paddingOf(context).bottom;

    // Chrome glissable/tapable (poignée + en-tête éventuel + marge basse) : tout
    // sauf la molette elle-même, qui doit garder l'exclusivité du glisser
    // vertical pour faire défiler ses valeurs.
    final chromeHaut = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.maybePop(context),
      onVerticalDragUpdate: _onDragUpdate,
      onVerticalDragEnd: _onDragEnd,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            alignment: Alignment.center,
            padding: const EdgeInsets.only(top: 8, bottom: 6),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          if (widget.entete != null) widget.entete!,
        ],
      ),
    );
    final chromeBas = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.maybePop(context),
      onVerticalDragUpdate: _onDragUpdate,
      onVerticalDragEnd: _onDragEnd,
      child: SizedBox(width: double.infinity, height: 10 + bottomSafe),
    );

    return Align(
      alignment: Alignment.bottomCenter,
      child: Transform.translate(
        offset: Offset(0, _drag),
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                chromeHaut,
                SizedBox(height: 216, child: widget.child),
                chromeBas,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Dialog sélection semaine ──────────────────────────────────────────────────

class WeekPickerDialog extends StatefulWidget {
  final DateTime initialWeekStart;
  const WeekPickerDialog({super.key, required this.initialWeekStart});

  @override
  State<WeekPickerDialog> createState() => _WeekPickerDialogState();
}

class _WeekPickerDialogState extends State<WeekPickerDialog> {
  // Chaque cran de la molette = une semaine entière. On indexe les semaines à
  // partir d'un lundi de référence, si bien que le défilement avance semaine
  // par semaine (bien plus intuitif qu'une molette de jour).
  static final DateTime _anchor = mondayOf(DateTime(2000, 1, 1));

  late final int _totalWeeks;
  late final FixedExtentScrollController _controller;
  late DateTime _weekStart;

  int _indexFor(DateTime monday) => monday.difference(_anchor).inDays ~/ 7;
  DateTime _mondayForIndex(int i) => _anchor.add(Duration(days: i * 7));

  @override
  void initState() {
    super.initState();
    final maxMonday = mondayOf(DateTime(DateTime.now().year + 5, 12, 31));
    _totalWeeks = _indexFor(maxMonday) + 1;

    var idx = _indexFor(mondayOf(widget.initialWeekStart))
        .clamp(0, _totalWeeks - 1);
    _weekStart = _mondayForIndex(idx);
    _controller = FixedExtentScrollController(initialItem: idx);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// « 14 – 20 juillet 2026 », en gérant le débordement de mois / d'année.
  String _label(DateTime m) {
    final f = m.add(const Duration(days: 6));
    final mm = kMoisNoms[m.month - 1];
    final ff = kMoisNoms[f.month - 1];
    if (m.month == f.month) return '${m.day} – ${f.day} $mm ${m.year}';
    if (m.year == f.year) return '${m.day} $mm – ${f.day} $ff ${f.year}';
    return '${m.day} $mm ${m.year} – ${f.day} $ff ${f.year}';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<DateTime>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.pop(context, _weekStart);
      },
      child: _WheelSheet(
        child: CupertinoPicker.builder(
          scrollController: _controller,
          itemExtent: 44,
          useMagnifier: true,
          magnification: 1.05,
          squeeze: 1.1,
          onSelectedItemChanged: (i) => _weekStart = _mondayForIndex(i),
          childCount: _totalWeeks,
          itemBuilder: (context, i) => Center(
            child: Text(_label(_mondayForIndex(i)),
                style: const TextStyle(fontSize: 18, color: AppColors.dark)),
          ),
        ),
      ),
    );
  }
}

// ── Dialog sélection mois ─────────────────────────────────────────────────────

class MonthPickerDialog extends StatefulWidget {
  final int initialYear;
  final int initialMonth;
  const MonthPickerDialog(
      {super.key, required this.initialYear, required this.initialMonth});

  @override
  State<MonthPickerDialog> createState() => _MonthPickerDialogState();
}

class _MonthPickerDialogState extends State<MonthPickerDialog> {
  late int _year;
  late int _month;

  @override
  void initState() {
    super.initState();
    _year  = widget.initialYear;
    _month = widget.initialMonth;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<DateTime>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.pop(context, DateTime(_year, _month));
      },
      child: _WheelSheet(
        child: CupertinoTheme(
          data: _kWheelTheme,
          child: CupertinoDatePicker(
            mode: CupertinoDatePickerMode.monthYear,
            initialDateTime: DateTime(_year, _month),
            minimumDate: DateTime(2000),
            maximumDate: DateTime(DateTime.now().year + 5, 12),
            onDateTimeChanged: (d) => setState(() {
              _year = d.year;
              _month = d.month;
            }),
          ),
        ),
      ),
    );
  }
}

// ── Dialog sélection jour ─────────────────────────────────────────────────────

class SingleDatePickerDialog extends StatefulWidget {
  final DateTime initialDate;
  final DateTime? firstDate;
  final DateTime? lastDate;

  const SingleDatePickerDialog({
    super.key,
    required this.initialDate,
    this.firstDate,
    this.lastDate,
  });

  @override
  State<SingleDatePickerDialog> createState() =>
      _SingleDatePickerDialogState();
}

class _SingleDatePickerDialogState
    extends State<SingleDatePickerDialog> {
  late DateTime _selected;

  // Bornes normalisées au jour (sans composante horaire) pour éviter les
  // assertions de CupertinoDatePicker (initiale hors intervalle à la minute près).
  DateTime get _firstDate {
    final d = widget.firstDate ?? DateTime(1900);
    return DateTime(d.year, d.month, d.day);
  }

  DateTime get _lastDate {
    final d = widget.lastDate ?? DateTime(2100);
    return DateTime(d.year, d.month, d.day);
  }

  @override
  void initState() {
    super.initState();
    var d = DateTime(widget.initialDate.year, widget.initialDate.month,
        widget.initialDate.day);
    if (d.isBefore(_firstDate)) d = _firstDate;
    if (d.isAfter(_lastDate)) d = _lastDate;
    _selected = d;
  }

  @override
  Widget build(BuildContext context) {
    // Sans boutons ni titre : la date choisie est renvoyée à la fermeture de la
    // feuille (tap poignée, glisser vers le bas, tap extérieur), via PopScope.
    return PopScope<DateTime?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.pop(context, _selected);
      },
      child: _WheelSheet(
        child: CupertinoTheme(
          data: _kWheelTheme,
          child: CupertinoDatePicker(
            mode: CupertinoDatePickerMode.date,
            initialDateTime: _selected,
            minimumDate: _firstDate,
            maximumDate: _lastDate,
            dateOrder: DatePickerDateOrder.dmy,
            onDateTimeChanged: (d) =>
                _selected = DateTime(d.year, d.month, d.day),
          ),
        ),
      ),
    );
  }
}

// ── Dialog sélection heure ────────────────────────────────────────────────────

/// Sélecteur d'heure premium (molette Cupertino 24h), même chrome que les
/// sélecteurs de date. Renvoie un [TimeOfDay] via `showDialog`, appliqué à la
/// fermeture de la feuille (tap extérieur / retour).
class HeurePickerDialog extends StatefulWidget {
  final TimeOfDay initialTime;
  const HeurePickerDialog({super.key, required this.initialTime});

  @override
  State<HeurePickerDialog> createState() => _HeurePickerDialogState();
}

class _HeurePickerDialogState extends State<HeurePickerDialog> {
  late TimeOfDay _heure;

  @override
  void initState() {
    super.initState();
    _heure = widget.initialTime;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final initial =
        DateTime(now.year, now.month, now.day, _heure.hour, _heure.minute);
    return PopScope<TimeOfDay>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.pop(context, _heure);
      },
      child: _WheelSheet(
        child: CupertinoTheme(
          data: _kWheelTheme,
          child: CupertinoDatePicker(
            mode: CupertinoDatePickerMode.time,
            use24hFormat: true,
            initialDateTime: initial,
            onDateTimeChanged: (d) =>
                _heure = TimeOfDay(hour: d.hour, minute: d.minute),
          ),
        ),
      ),
    );
  }
}

// ── Dialog sélection période ──────────────────────────────────────────────────

class PeriodePickerDialog extends StatefulWidget {
  final DateTime initialStart;
  final DateTime initialEnd;

  /// Si défini, les jours antérieurs à cette date sont désactivés.
  final DateTime? firstDate;

  const PeriodePickerDialog(
      {super.key,
      required this.initialStart,
      required this.initialEnd,
      this.firstDate});

  @override
  State<PeriodePickerDialog> createState() =>
      _DateRangePickerDialogState();
}

class _DateRangePickerDialogState extends State<PeriodePickerDialog> {
  late DateTime _start;
  late DateTime _end;
  int _active = 0; // 0 = début, 1 = fin

  @override
  void initState() {
    super.initState();
    _start = DateTime(widget.initialStart.year, widget.initialStart.month,
        widget.initialStart.day);
    _end = DateTime(
        widget.initialEnd.year, widget.initialEnd.month, widget.initialEnd.day);
  }

  DateTime get _min {
    final f = widget.firstDate;
    return f != null ? DateTime(f.year, f.month, f.day) : DateTime(2000);
  }

  DateTime get _max => DateTime(DateTime.now().year + 5, 12, 31);

  @override
  Widget build(BuildContext context) {
    var initial = _active == 0 ? _start : _end;
    if (initial.isBefore(_min)) initial = _min;
    if (initial.isAfter(_max)) initial = _max;

    return PopScope<DateTimeRange>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final s = _start.isBefore(_end) ? _start : _end;
        final e = _start.isBefore(_end) ? _end : _start;
        Navigator.pop(context, DateTimeRange(start: s, end: e));
      },
      child: _WheelSheet(
        entete: _BasculeDebutFin(
          active: _active,
          debut: _start,
          fin: _end,
          onChange: (i) => setState(() => _active = i),
        ),
        child: CupertinoTheme(
          data: _kWheelTheme,
          child: CupertinoDatePicker(
            // Recharge la molette sur la borne active lors du changement d'onglet.
            key: ValueKey(_active),
            mode: CupertinoDatePickerMode.date,
            initialDateTime: initial,
            minimumDate: _min,
            maximumDate: _max,
            dateOrder: DatePickerDateOrder.dmy,
            onDateTimeChanged: (d) {
              final picked = DateTime(d.year, d.month, d.day);
              setState(() {
                if (_active == 0) {
                  _start = picked;
                } else {
                  _end = picked;
                }
              });
            },
          ),
        ),
      ),
    );
  }
}

/// Bascule segmentée « Début / Fin » affichant les deux bornes de la période.
class _BasculeDebutFin extends StatelessWidget {
  final int active;
  final DateTime debut;
  final DateTime fin;
  final ValueChanged<int> onChange;

  const _BasculeDebutFin({
    required this.active,
    required this.debut,
    required this.fin,
    required this.onChange,
  });

  String _fmt(DateTime d) =>
      '${d.day} ${kMoisNoms[d.month - 1].substring(0, 3)}';

  @override
  Widget build(BuildContext context) {
    Widget seg(int i, String label, DateTime d) {
      final actif = active == i;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChange(i),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 7),
            decoration: BoxDecoration(
              color: actif ? AppColors.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
              boxShadow: actif
                  ? [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 4,
                          offset: const Offset(0, 1))
                    ]
                  : null,
            ),
            child: Column(
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 11,
                        color: actif ? AppColors.primaryDark : AppColors.hint,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 1),
                Text(_fmt(d),
                    style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.dark,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.fieldFill,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            seg(0, 'Début', debut),
            const SizedBox(width: 4),
            seg(1, 'Fin', fin),
          ],
        ),
      ),
    );
  }
}

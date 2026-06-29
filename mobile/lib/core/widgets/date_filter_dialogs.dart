import 'package:flutter/material.dart';

// ── Constantes partagées ──────────────────────────────────────────────────────

const kMoisNoms = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
  'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
];

DateTime mondayOf(DateTime d) => d.subtract(Duration(days: d.weekday - 1));

// ── Dialog sélection semaine ──────────────────────────────────────────────────

class WeekPickerDialog extends StatefulWidget {
  final DateTime initialWeekStart;
  const WeekPickerDialog({super.key, required this.initialWeekStart});

  @override
  State<WeekPickerDialog> createState() => _WeekPickerDialogState();
}

class _WeekPickerDialogState extends State<WeekPickerDialog> {
  late DateTime _weekStart;
  late DateTime _viewMonth;
  static const _weekLabels = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  @override
  void initState() {
    super.initState();
    _weekStart = widget.initialWeekStart;
    _viewMonth = DateTime(_weekStart.year, _weekStart.month);
  }

  @override
  Widget build(BuildContext context) {
    final today   = DateTime.now();
    final weekEnd = _weekStart.add(const Duration(days: 6));
    final firstDay     = DateTime(_viewMonth.year, _viewMonth.month, 1);
    final lastDay      = DateTime(_viewMonth.year, _viewMonth.month + 1, 0);
    final startOffset  = firstDay.weekday - 1;
    final rows         = ((startOffset + lastDay.day) / 7).ceil();
    final monthLabel   =
        '${kMoisNoms[_viewMonth.month - 1]} ${_viewMonth.year}';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 16),
        _CalendarHeader(
          monthLabel: monthLabel,
          onPrev: () => setState(() =>
              _viewMonth = DateTime(_viewMonth.year, _viewMonth.month - 1)),
          onNext: () => setState(() =>
              _viewMonth = DateTime(_viewMonth.year, _viewMonth.month + 1)),
          onPickMonthYear: () =>
              showMonthYearPicker(context, _viewMonth, (d) {
            setState(() => _viewMonth = d);
          }),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: _weekLabels
                  .map((d) => SizedBox(
                        width: 34,
                        child: Text(d,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.w500)),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 4),
            ...List.generate(rows, (row) => Row(
                  children: List.generate(7, (col) {
                    final dayNum = row * 7 + col - startOffset + 1;
                    if (dayNum < 1 || dayNum > lastDay.day) {
                      return const Expanded(child: SizedBox(height: 40));
                    }
                    final date = DateTime(
                        _viewMonth.year, _viewMonth.month, dayNum);
                    final inWeek = !date.isBefore(_weekStart) &&
                        !date.isAfter(weekEnd);
                    final isFirst = date.day == _weekStart.day &&
                        date.month == _weekStart.month &&
                        date.year == _weekStart.year;
                    final isLast = date.day == weekEnd.day &&
                        date.month == weekEnd.month &&
                        date.year == weekEnd.year;
                    final isToday = date.day == today.day &&
                        date.month == today.month &&
                        date.year == today.year;

                    return Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _weekStart = mondayOf(date)),
                        child: SizedBox(
                          height: 40,
                          child: Stack(children: [
                            if (inWeek)
                              Positioned.fill(
                                child: Container(
                                  margin: EdgeInsets.only(
                                      left: isFirst ? 4 : 0,
                                      right: isLast ? 4 : 0),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1565C0)
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.horizontal(
                                      left: isFirst
                                          ? const Radius.circular(20)
                                          : Radius.zero,
                                      right: isLast
                                          ? const Radius.circular(20)
                                          : Radius.zero,
                                    ),
                                  ),
                                ),
                              ),
                            if (inWeek && (isFirst || isLast))
                              Center(
                                child: Container(
                                  width: 32, height: 32,
                                  decoration: const BoxDecoration(
                                      color: Color(0xFF1565C0),
                                      shape: BoxShape.circle),
                                ),
                              ),
                            if (isToday && !inWeek)
                              Center(
                                child: Container(
                                  width: 32, height: 32,
                                  decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: const Color(0xFF1565C0),
                                          width: 1.5)),
                                ),
                              ),
                            Center(
                              child: Text('$dayNum',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: (inWeek && (isFirst || isLast))
                                        ? Colors.white
                                        : isToday
                                            ? const Color(0xFF1565C0)
                                            : Colors.black87,
                                    fontWeight:
                                        (inWeek && (isFirst || isLast)) ||
                                                isToday
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                  )),
                            ),
                          ]),
                        ),
                      ),
                    );
                  }),
                )),
          ]),
        ),
        const SizedBox(height: 16),
        _DialogActions(
          onCancel: () => Navigator.pop(context),
          onOk:     () => Navigator.pop(context, _weekStart),
        ),
      ])),
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
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          GestureDetector(
              onTap: () => setState(() => _year--),
              child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.chevron_left, size: 24))),
          const SizedBox(width: 24),
          Text('$_year',
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 17)),
          const SizedBox(width: 24),
          GestureDetector(
              onTap: () => setState(() => _year++),
              child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.chevron_right, size: 24))),
        ]),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.4,
            children: List.generate(12, (i) {
              final sel = _month == i + 1;
              return GestureDetector(
                onTap: () => setState(() => _month = i + 1),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: sel
                        ? const Color(0xFF1565C0)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(kMoisNoms[i],
                      style: TextStyle(
                        fontSize: 12,
                        color: sel ? Colors.white : Colors.black87,
                        fontWeight:
                            sel ? FontWeight.w600 : FontWeight.w400,
                      )),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 16),
        _DialogActions(
          onCancel: () => Navigator.pop(context),
          onOk:     () => Navigator.pop(context, DateTime(_year, _month)),
        ),
      ]),
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
  late DateTime _viewMonth;
  static const _weekLabels = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  DateTime get _firstDate => widget.firstDate ?? DateTime(1900);
  DateTime get _lastDate => widget.lastDate ?? DateTime(2100);

  @override
  void initState() {
    super.initState();
    _selected  = widget.initialDate;
    _viewMonth = DateTime(_selected.year, _selected.month);
  }

  @override
  Widget build(BuildContext context) {
    final today       = DateTime.now();
    final firstDay    = DateTime(_viewMonth.year, _viewMonth.month, 1);
    final lastDay     = DateTime(_viewMonth.year, _viewMonth.month + 1, 0);
    final startOffset = firstDay.weekday - 1;
    final rows        = ((startOffset + lastDay.day) / 7).ceil();
    final monthLabel  =
        '${kMoisNoms[_viewMonth.month - 1]} ${_viewMonth.year}';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 16),
        _CalendarHeader(
          monthLabel: monthLabel,
          onPrev: () => setState(() =>
              _viewMonth = DateTime(_viewMonth.year, _viewMonth.month - 1)),
          onNext: () => setState(() =>
              _viewMonth = DateTime(_viewMonth.year, _viewMonth.month + 1)),
          onPickMonthYear: () =>
              showMonthYearPicker(context, _viewMonth, (d) {
            setState(() => _viewMonth = d);
          }),
        ),
        const SizedBox(height: 10),
        _CalendarGrid(
          viewMonth:   _viewMonth,
          weekLabels:  _weekLabels,
          startOffset: startOffset,
          lastDay:     lastDay,
          rows:        rows,
          today:       today,
          isSelected:  (d) =>
              d.year == _selected.year &&
              d.month == _selected.month &&
              d.day == _selected.day,
          isDisabled: (d) =>
              d.isBefore(DateTime(_firstDate.year, _firstDate.month, _firstDate.day)) ||
              d.isAfter(DateTime(_lastDate.year, _lastDate.month, _lastDate.day)),
          onDayTap: (d) {
            if (!d.isBefore(DateTime(_firstDate.year, _firstDate.month, _firstDate.day)) &&
                !d.isAfter(DateTime(_lastDate.year, _lastDate.month, _lastDate.day))) {
              setState(() => _selected = d);
            }
          },
        ),
        const SizedBox(height: 16),
        _DialogActions(
          onCancel: () => Navigator.pop(context),
          onOk:     () => Navigator.pop(context, _selected),
        ),
      ])),
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

class _DateRangePickerDialogState extends State<PeriodePickerDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late DateTime _start;
  late DateTime _end;
  late DateTime _viewMonth;
  static const _weekLabels = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  @override
  void initState() {
    super.initState();
    _start     = widget.initialStart;
    _end       = widget.initialEnd;
    _viewMonth = DateTime(_start.year, _start.month);
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _viewMonth = _tabController.index == 0
              ? DateTime(_start.year, _start.month)
              : DateTime(_end.year, _end.month);
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onDayTap(DateTime date) {
    if (widget.firstDate != null && date.isBefore(widget.firstDate!)) return;
    setState(() {
      if (_tabController.index == 0) {
        _start = date;
        _tabController.animateTo(1);
        _viewMonth = DateTime(_end.year, _end.month);
      } else {
        _end = date;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final today        = DateTime.now();
    final selectedDate = _tabController.index == 0 ? _start : _end;
    final firstDay     = DateTime(_viewMonth.year, _viewMonth.month, 1);
    final lastDay      = DateTime(_viewMonth.year, _viewMonth.month + 1, 0);
    final startOffset  = firstDay.weekday - 1;
    final rows         = ((startOffset + lastDay.day) / 7).ceil();
    final monthLabel   =
        '${kMoisNoms[_viewMonth.month - 1]} ${_viewMonth.year}';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
        TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Date de début'), Tab(text: 'Date de fin')],
          indicatorColor:     const Color(0xFF1565C0),
          labelColor:         Colors.black87,
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(
              fontWeight: FontWeight.w600, fontSize: 14),
          unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w400, fontSize: 14),
          dividerColor: Colors.transparent,
        ),
        const SizedBox(height: 12),
        _CalendarHeader(
          monthLabel: monthLabel,
          onPrev: () => setState(() =>
              _viewMonth = DateTime(_viewMonth.year, _viewMonth.month - 1)),
          onNext: () => setState(() =>
              _viewMonth = DateTime(_viewMonth.year, _viewMonth.month + 1)),
          onPickMonthYear: () =>
              showMonthYearPicker(context, _viewMonth, (d) {
            setState(() => _viewMonth = d);
          }),
        ),
        const SizedBox(height: 10),
        _CalendarGrid(
          viewMonth:   _viewMonth,
          weekLabels:  _weekLabels,
          startOffset: startOffset,
          lastDay:     lastDay,
          rows:        rows,
          today:       today,
          isSelected:  (d) =>
              d.year == selectedDate.year &&
              d.month == selectedDate.month &&
              d.day == selectedDate.day,
          isDisabled: widget.firstDate != null
              ? (d) => d.isBefore(widget.firstDate!)
              : null,
          onDayTap: _onDayTap,
        ),
        const SizedBox(height: 16),
        _DialogActions(
          onCancel: () => Navigator.pop(context),
          onOk: () {
            final s = _start.isBefore(_end) ? _start : _end;
            final e = _start.isBefore(_end) ? _end : _start;
            Navigator.pop(context, DateTimeRange(start: s, end: e));
          },
        ),
      ])),
    );
  }
}

// ── Composants internes ───────────────────────────────────────────────────────

class _CalendarHeader extends StatelessWidget {
  final String monthLabel;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onPickMonthYear;

  const _CalendarHeader({
    required this.monthLabel,
    required this.onPrev,
    required this.onNext,
    required this.onPickMonthYear,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        GestureDetector(
          onTap: onPickMonthYear,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(monthLabel,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(width: 2),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
          ]),
        ),
        const Spacer(),
        GestureDetector(
            onTap: onPrev,
            child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.chevron_left, size: 22))),
        const SizedBox(width: 12),
        GestureDetector(
            onTap: onNext,
            child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.chevron_right, size: 22))),
      ]),
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  final DateTime viewMonth;
  final List<String> weekLabels;
  final int startOffset;
  final DateTime lastDay;
  final int rows;
  final DateTime today;
  final bool Function(DateTime) isSelected;
  final bool Function(DateTime)? isDisabled;
  final void Function(DateTime) onDayTap;

  const _CalendarGrid({
    required this.viewMonth,
    required this.weekLabels,
    required this.startOffset,
    required this.lastDay,
    required this.rows,
    required this.today,
    required this.isSelected,
    required this.onDayTap,
    this.isDisabled,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: weekLabels
              .map((d) => SizedBox(
                    width: 34,
                    child: Text(d,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500)),
                  ))
              .toList(),
        ),
        const SizedBox(height: 4),
        ...List.generate(rows, (row) => Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(7, (col) {
                final dayNum = row * 7 + col - startOffset + 1;
                if (dayNum < 1 || dayNum > lastDay.day) {
                  return const SizedBox(width: 34, height: 40);
                }
                final date =
                    DateTime(viewMonth.year, viewMonth.month, dayNum);
                final isSel      = isSelected(date);
                final isDis      = isDisabled?.call(date) ?? false;
                final isToday    = date.year == today.year &&
                    date.month == today.month &&
                    date.day == today.day;

                return GestureDetector(
                  onTap: isDis ? null : () => onDayTap(date),
                  child: Opacity(
                    opacity: isDis ? 0.3 : 1.0,
                    child: SizedBox(
                      width: 34, height: 40,
                      child: Center(
                        child: Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: isSel && !isDis
                                ? const Color(0xFF1565C0)
                                : Colors.transparent,
                            shape: BoxShape.circle,
                            border: isToday && !isSel && !isDis
                                ? Border.all(
                                    color: const Color(0xFF1565C0),
                                    width: 1.5)
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Text('$dayNum',
                              style: TextStyle(
                                fontSize: 14,
                                color: isSel && !isDis
                                    ? Colors.white
                                    : isToday && !isDis
                                        ? const Color(0xFF1565C0)
                                        : Colors.black87,
                                fontWeight: (isSel || isToday) && !isDis
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              )),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            )),
      ]),
    );
  }
}

class _DialogActions extends StatelessWidget {
  final VoidCallback onCancel;
  final VoidCallback onOk;
  const _DialogActions({required this.onCancel, required this.onOk});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
      child: Row(children: [
        Expanded(
          child: TextButton(
            onPressed: onCancel,
            child: const Text('Annuler',
                style: TextStyle(
                    color: Color(0xFF1565C0),
                    fontWeight: FontWeight.w600,
                    fontSize: 15)),
          ),
        ),
        Container(width: 1, height: 24, color: Colors.grey.shade300),
        Expanded(
          child: TextButton(
            onPressed: onOk,
            child: const Text('OK',
                style: TextStyle(
                    color: Color(0xFF1565C0),
                    fontWeight: FontWeight.w600,
                    fontSize: 15)),
          ),
        ),
      ]),
    );
  }
}

// ── Sélecteur mois/année (bottom sheet) ──────────────────────────────────────

void showMonthYearPicker(
  BuildContext context,
  DateTime current,
  void Function(DateTime) onSelected,
) {
  final currentYear = DateTime.now().year;
  final years       = List.generate(6, (i) => currentYear - 2 + i);
  int tempYear      = current.year;

  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => SafeArea(
        top: false,
        child: SizedBox(
        height: 380,
        child: Column(children: [
          const Padding(
            padding: EdgeInsets.all(14),
            child: Text('Choisir mois et année',
                style: TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 15)),
          ),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: years.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final y   = years[i];
                final sel = tempYear == y;
                return GestureDetector(
                  onTap: () => setLocal(() => tempYear = y),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel
                          ? const Color(0xFF1565C0)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('$y',
                        style: TextStyle(
                          fontSize: 13,
                          color: sel ? Colors.white : Colors.black87,
                          fontWeight: sel
                              ? FontWeight.w600
                              : FontWeight.w400,
                        )),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: GridView.count(
              crossAxisCount: 3,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.5,
              children: List.generate(12, (i) {
                final sel =
                    current.month == i + 1 && current.year == tempYear;
                return GestureDetector(
                  onTap: () {
                    onSelected(DateTime(tempYear, i + 1));
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: sel
                          ? const Color(0xFF1565C0)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(kMoisNoms[i],
                        style: TextStyle(
                          fontSize: 12,
                          color: sel ? Colors.white : Colors.black87,
                          fontWeight: sel
                              ? FontWeight.w600
                              : FontWeight.w400,
                        )),
                  ),
                );
              }),
            ),
          ),
        ]),
      ),
      ),
    ),
  );
}

import 'package:flutter/material.dart';

import 'date_filter_dialogs.dart';

/// Pastille de sélection de mois, dans le style du filtre par date
/// d'`operations_financieres_page` (`_DatePill`).
///
/// Affiche « mois année » (ex. « juillet 2026 ») et ouvre un [MonthPickerDialog]
/// au tap. Destinée à être placée dans un `Expanded` (le libellé occupe la
/// largeur disponible, le chevron reste à droite).
class MonthFilterPill extends StatelessWidget {
  final int mois;
  final int annee;
  final void Function(int mois, int annee) onChanged;

  const MonthFilterPill({
    super.key,
    required this.mois,
    required this.annee,
    required this.onChanged,
  });

  Future<void> _pick(BuildContext context) async {
    final res = await showDialog<DateTime>(
      context: context,
      builder: (_) =>
          MonthPickerDialog(initialYear: annee, initialMonth: mois),
    );
    if (res != null) onChanged(res.month, res.year);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _pick(context),
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
              child: Text(
                '${kMoisNoms[mois - 1]} $annee',
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

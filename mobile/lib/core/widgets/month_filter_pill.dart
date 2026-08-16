import 'package:flutter/material.dart';

import 'date_filter_dialogs.dart';

/// Pastille de sélection de mois, dans le style du filtre par date
/// d'`operations_financieres_page` (`_DatePill`).
///
/// Affiche « mois année » (ex. « juillet 2026 ») et ouvre un [MonthPickerDialog]
/// au tap. Destinée à être placée dans un `Expanded` (le libellé occupe la
/// largeur disponible, le chevron reste à droite).
///
/// [mois]/[annee] nuls = aucun filtre : la pastille affiche [libelleVide] et la
/// molette s'ouvre sur le mois courant. Fournir [onEfface] ajoute une croix qui
/// permet de revenir à cet état « sans filtre ».
class MonthFilterPill extends StatelessWidget {
  final int? mois;
  final int? annee;
  final void Function(int mois, int annee) onChanged;
  final VoidCallback? onEfface;
  final String libelleVide;

  const MonthFilterPill({
    super.key,
    required this.mois,
    required this.annee,
    required this.onChanged,
    this.onEfface,
    this.libelleVide = 'Tous les mois',
  });

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final res = await showDialog<DateTime>(
      context: context,
      builder: (_) => MonthPickerDialog(
          initialYear: annee ?? now.year, initialMonth: mois ?? now.month),
    );
    if (res != null) onChanged(res.month, res.year);
  }

  @override
  Widget build(BuildContext context) {
    final m = mois;
    final libelle = m == null ? libelleVide : '${kMoisNoms[m - 1]} $annee';
    final effacable = m != null && onEfface != null;

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
                libelle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 5),
            if (effacable)
              GestureDetector(
                onTap: onEfface,
                behavior: HitTestBehavior.opaque,
                child: Icon(Icons.close_rounded,
                    size: 15, color: Colors.grey.shade600),
              )
            else
              Icon(Icons.keyboard_arrow_down_rounded,
                  size: 14, color: Colors.grey.shade600),
          ],
        ),
      ),
    );
  }
}

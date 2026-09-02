import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_colors.dart';

/// Barre du mode sélection multiple, ouvert par un appui long sur une ligne :
/// elle totalise ce qui est coché et déclenche l'encaissement du lot.
///
/// Les lignes se cochent une à une, volontairement : un encaissement en masse
/// engage de l'argent réellement reçu, et une sélection globale d'un seul geste
/// invite à envoyer plus que ce que le chauffeur a versé.

final _money = NumberFormat('#,##0', 'fr_FR');

class SelectionActionBar extends StatelessWidget {
  final int    count;
  final double total;
  final bool   busy;
  final VoidCallback onEncaisser;

  /// Quitte le mode sélection sans rien encaisser. La croix est ici, près du
  /// pouce, parce que c'est là que se porte le regard une fois des lignes
  /// cochées — l'en-tête et le retour système font la même chose.
  final VoidCallback onAnnuler;

  const SelectionActionBar({
    super.key,
    required this.count,
    required this.total,
    required this.busy,
    required this.onEncaisser,
    required this.onAnnuler,
  });

  @override
  Widget build(BuildContext context) {
    final actif = count > 0 && !busy;
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(children: [
          IconButton(
            onPressed: busy ? null : onAnnuler,
            icon: const Icon(Icons.close_rounded, size: 20),
            color: AppColors.label,
            tooltip: 'Quitter la sélection',
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Total à encaisser',
                    style: TextStyle(fontSize: 11.5, color: AppColors.label)),
                const SizedBox(height: 2),
                Text('${_money.format(total)} XOF',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.dark)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: actif ? onEncaisser : null,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            icon: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.payments_outlined, size: 18),
            label: Text('Encaisser${count > 0 ? ' ($count)' : ''}'),
          ),
        ]),
      ),
    );
  }
}

/// Case posée sur une carte de liste pendant le mode sélection.
class SelectionCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?> onChanged;
  final Color couleur;

  const SelectionCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.couleur = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 22,
      child: Checkbox(
        value: value,
        onChanged: onChanged,
        activeColor: couleur,
        side: const BorderSide(color: AppColors.border, width: 1.6),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
    );
  }
}

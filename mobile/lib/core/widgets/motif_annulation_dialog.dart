import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Ce que l'utilisateur a répondu au dialog d'annulation : le motif, toujours
/// renseigné, et l'état de la case optionnelle proposée sous le champ.
class SaisieAnnulation {
  final String motif;

  /// Case cochée à la validation. Faux quand aucune option n'était proposée.
  final bool optionCochee;

  const SaisieAnnulation(this.motif, {this.optionCochee = false});
}

/// Dialog **premium** d'annulation d'une ligne (recette / cotisation /
/// pénalité) : le motif est **obligatoire** (le bouton de confirmation reste
/// désactivé tant que le champ est vide). Retourne le motif saisi, ou null si
/// l'utilisateur renonce.
Future<String?> showMotifAnnulationDialog(
  BuildContext context, {
  String titre = 'Annuler la ligne ?',
  String message = 'Cette action est irréversible. '
      'Indiquez le motif de l\'annulation.',
}) async =>
    (await showSaisieAnnulationDialog(context, titre: titre, message: message))
        ?.motif;

/// Même dialog, avec une **case à cocher optionnelle** sous le champ : elle
/// porte une annulation qui en entraîne une autre (la recette et les
/// cotisations de sa journée, par exemple).
///
/// L'option n'apparaît que si [optionLabel] est fourni ; sans elle, ce dialog
/// est exactement celui de [showMotifAnnulationDialog].
Future<SaisieAnnulation?> showSaisieAnnulationDialog(
  BuildContext context, {
  String titre = 'Annuler la ligne ?',
  String message = 'Cette action est irréversible. '
      'Indiquez le motif de l\'annulation.',
  String? optionLabel,
  String? optionDetail,
  bool optionInitiale = true,
}) {
  final ctrl = TextEditingController();
  var optionCochee = optionInitiale;
  return showDialog<SaisieAnnulation>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final motif = ctrl.text.trim();
        final valide = motif.isNotEmpty;
        return Dialog(
          backgroundColor: AppColors.surface,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Icône dans une pastille teintée « erreur ».
                Center(
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.cancel_outlined,
                        size: 28, color: AppColors.error),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  titre,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.dark,
                      letterSpacing: -0.4),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 13.5, height: 1.4, color: AppColors.label),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  maxLines: 3,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(fontSize: 14, color: AppColors.dark),
                  decoration: InputDecoration(
                    labelText: 'Motif de l\'annulation *',
                    labelStyle:
                        const TextStyle(fontSize: 13, color: AppColors.label),
                    hintText: 'Ex. Erreur de saisie, doublon…',
                    hintStyle:
                        const TextStyle(fontSize: 13.5, color: AppColors.hint),
                    filled: true,
                    fillColor: AppColors.fieldFill,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 13),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppColors.error, width: 1.4)),
                  ),
                ),
                if (optionLabel != null) ...[
                  const SizedBox(height: 14),
                  _CaseOption(
                    label: optionLabel,
                    detail: optionDetail,
                    valeur: optionCochee,
                    onChanged: (v) => setState(() => optionCochee = v),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.label,
                            side: const BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text('Retour',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: FilledButton(
                          onPressed: valide
                              ? () => Navigator.pop(ctx,
                                  SaisieAnnulation(motif,
                                      optionCochee:
                                          optionLabel != null && optionCochee))
                              : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.error,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                                AppColors.error.withValues(alpha: 0.35),
                            disabledForegroundColor: Colors.white70,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text('Confirmer',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

/// Case à cocher du dialog d'annulation : toute la carte est cliquable, et la
/// bordure teintée dit d'un coup d'œil ce que la validation emportera en plus.
class _CaseOption extends StatelessWidget {
  final String label;
  final String? detail;
  final bool valeur;
  final ValueChanged<bool> onChanged;

  const _CaseOption({
    required this.label,
    required this.detail,
    required this.valeur,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!valeur),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 10, 14, 10),
        decoration: BoxDecoration(
          color: valeur
              ? AppColors.error.withValues(alpha: 0.06)
              : AppColors.fieldFill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: valeur
                  ? AppColors.error.withValues(alpha: 0.35)
                  : AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: Checkbox(
                value: valeur,
                onChanged: (v) => onChanged(v ?? false),
                activeColor: AppColors.error,
                side: const BorderSide(color: AppColors.hint, width: 1.6),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: valeur ? AppColors.dark : AppColors.label,
                          letterSpacing: -0.2)),
                  if (detail != null) ...[
                    const SizedBox(height: 2),
                    Text(detail!,
                        style: const TextStyle(
                            fontSize: 12, height: 1.3, color: AppColors.label)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

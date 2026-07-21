import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Dialog **premium** d'annulation d'une ligne (recette / cotisation /
/// pénalité) : le motif est **obligatoire** (le bouton de confirmation reste
/// désactivé tant que le champ est vide). Retourne le motif saisi, ou null si
/// l'utilisateur renonce.
Future<String?> showMotifAnnulationDialog(
  BuildContext context, {
  String titre = 'Annuler la ligne ?',
  String message = 'Cette action est irréversible. '
      'Indiquez le motif de l\'annulation.',
}) {
  final ctrl = TextEditingController();
  return showDialog<String>(
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
                          onPressed:
                              valide ? () => Navigator.pop(ctx, motif) : null,
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

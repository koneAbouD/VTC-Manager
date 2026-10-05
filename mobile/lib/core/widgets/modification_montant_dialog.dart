import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'montant_field.dart';

/// Dialog de correction du montant dû d'une créance (recette attendue,
/// amende) : le nouveau montant et un motif, tous deux obligatoires.
///
/// [onValider] envoie la correction et rend le message de refus du serveur,
/// ou null si elle est passée : le refus s'affiche dans le dialog, qui reste
/// ouvert pour qu'on corrige la saisie. Rend vrai si la correction a abouti.
///
/// Le plancher est [dejaVerse] : descendre en dessous ferait de l'argent déjà
/// reçu un trop-perçu que rien ne rembourse — le serveur le refuserait.
Future<bool?> showModificationMontantDialog(
  BuildContext context, {
  required String titre,
  String? sousTitre,
  required double montantActuel,
  double dejaVerse = 0,
  required Future<String?> Function(double montant, String motif) onValider,
}) {
  final montantCtrl =
      TextEditingController(text: formatMontantSaisie(montantActuel));
  final motifCtrl = TextEditingController();
  String? erreur;
  var envoi = false;

  String? validerNouveau(String? v) {
    final base = validerMontant(v, plafond: null);
    if (base != null) return base;
    final m = parseMontant(v)!;
    if (m < dejaVerse) {
      return 'Inférieur au déjà versé (${formatMontantCourt(dejaVerse)})';
    }
    return null;
  }

  return showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
      final nouveau = parseMontant(montantCtrl.text);
      final valide = validerNouveau(montantCtrl.text) == null &&
          nouveau != montantActuel &&
          motifCtrl.text.trim().isNotEmpty &&
          !envoi;

      InputDecoration deco(String label, {String? hint}) => InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(fontSize: 13, color: AppColors.label),
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 13.5, color: AppColors.hint),
            filled: true,
            fillColor: AppColors.fieldFill,
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.primaryDark, width: 1.4)),
          );

      Future<void> valider() async {
        setState(() {
          envoi = true;
          erreur = null;
        });
        final refus = await onValider(nouveau!, motifCtrl.text.trim());
        if (!ctx.mounted) return;
        if (refus == null) {
          Navigator.pop(ctx, true);
        } else {
          setState(() {
            envoi = false;
            erreur = refus;
          });
        }
      }

      return Dialog(
        backgroundColor: AppColors.surface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.primaryDark.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.edit_outlined,
                      size: 26, color: AppColors.primaryDark),
                ),
              ),
              const SizedBox(height: 14),
              Text(titre,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.dark,
                      letterSpacing: -0.4)),
              if (sousTitre != null) ...[
                const SizedBox(height: 6),
                Text(sousTitre,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 13, height: 1.4, color: AppColors.label)),
              ],
              const SizedBox(height: 8),
              Text(
                  'Montant actuel ${formatMontantCourt(montantActuel)}'
                  '${dejaVerse > 0 ? ' · déjà versé ${formatMontantCourt(dejaVerse)}' : ''}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12.5, color: AppColors.hint)),
              const SizedBox(height: 16),
              TextFormField(
                controller: montantCtrl,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: montantInputFormatters,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: validerNouveau,
                onChanged: (_) => setState(() => erreur = null),
                style: const TextStyle(fontSize: 15, color: AppColors.dark),
                decoration: deco('Nouveau montant *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: motifCtrl,
                maxLines: 3,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() => erreur = null),
                style: const TextStyle(fontSize: 14, color: AppColors.dark),
                decoration: deco('Motif de la correction *',
                    hint: 'Ex. Tarif négocié, erreur de saisie…'),
              ),
              if (erreur != null) ...[
                const SizedBox(height: 12),
                Text(erreur!,
                    style: const TextStyle(
                        fontSize: 12.5, height: 1.35, color: AppColors.error)),
              ],
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: envoi ? null : () => Navigator.pop(ctx),
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
                      onPressed: valide ? valider : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryDark,
                        disabledBackgroundColor:
                            AppColors.primaryDark.withValues(alpha: 0.35),
                        disabledForegroundColor: Colors.white70,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: envoi
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Corriger',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ]),
            ],
          ),
        ),
      );
    }),
  );
}

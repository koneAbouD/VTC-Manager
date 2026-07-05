import 'package:flutter/material.dart';

/// Dialog d'annulation d'une ligne (recette / cotisation / pénalité) : le motif
/// est **obligatoire** (le bouton de confirmation reste désactivé tant que le
/// champ est vide). Retourne le motif saisi, ou null si l'utilisateur renonce.
Future<String?> showMotifAnnulationDialog(
  BuildContext context, {
  String titre = 'Annuler la ligne ?',
  String message = 'Cette action est irréversible. '
      'Indiquez le motif de l\'annulation.',
}) {
  final ctrl = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final motif = ctrl.text.trim();
        final valide = motif.isNotEmpty;
        return AlertDialog(
          title: Text(titre,
              style:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
              const SizedBox(height: 14),
              TextField(
                controller: ctrl,
                autofocus: true,
                maxLines: 2,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Motif de l\'annulation *',
                  hintText: 'Ex. Erreur de saisie, doublon…',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Retour'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: valide ? () => Navigator.pop(ctx, motif) : null,
              child: const Text('Confirmer l\'annulation'),
            ),
          ],
        );
      },
    ),
  );
}

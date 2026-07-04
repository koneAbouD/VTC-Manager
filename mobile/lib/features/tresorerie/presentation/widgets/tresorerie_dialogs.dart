import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/compte_tresorerie.dart';
import '../providers/tresorerie_providers.dart';

/// Dialog de transfert entre deux comptes de trésorerie.
Future<void> showTransfertDialog(
  BuildContext context,
  WidgetRef ref,
  List<CompteTresorerie> comptes,
) async {
  if (comptes.length < 2) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Il faut au moins deux comptes pour transférer')));
    return;
  }

  CompteTresorerie source = comptes.first;
  CompteTresorerie destination = comptes[1];
  final montantCtrl = TextEditingController();
  final commentaireCtrl = TextEditingController();

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Transfert entre comptes',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CompteDropdown(
              label: 'Depuis',
              comptes: comptes,
              value: source,
              onChanged: (c) => setState(() => source = c),
            ),
            const SizedBox(height: 12),
            _CompteDropdown(
              label: 'Vers',
              comptes: comptes,
              value: destination,
              onChanged: (c) => setState(() => destination = c),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: montantCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Montant', suffixText: 'XOF'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: commentaireCtrl,
              decoration: const InputDecoration(
                  labelText: 'Commentaire (optionnel)'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Transférer')),
        ],
      ),
    ),
  );

  if (ok != true) return;
  final montant = double.tryParse(montantCtrl.text.replaceAll(' ', ''));
  if (montant == null || montant <= 0 || source.id == destination.id) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Transfert invalide : vérifiez comptes et montant')));
    }
    return;
  }

  try {
    await ref.read(tresorerieDatasourceProvider).createTransfert(
          compteSourceId: source.id,
          compteDestinationId: destination.id,
          montant: montant,
          commentaire: commentaireCtrl.text,
        );
    ref.invalidate(tresorerieSummaryProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Transfert de ${CurrencyFormatter.format(montant)} effectué')));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Échec du transfert : $e')));
    }
  }
}

/// Dialog de clôture de caisse en 2 étapes : le solde théorique est affiché,
/// le comptage est saisi, le motif devient obligatoire si un écart apparaît.
Future<void> showClotureCaisseDialog(
  BuildContext context,
  WidgetRef ref,
  List<CompteAvecSoldeVue> comptes,
) async {
  if (comptes.isEmpty) return;

  CompteAvecSoldeVue selection = comptes.first;
  final comptageCtrl = TextEditingController();
  final motifCtrl = TextEditingController();

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final comptage =
            double.tryParse(comptageCtrl.text.replaceAll(' ', ''));
        final ecart = comptage != null ? comptage - selection.solde : null;
        final motifRequis = ecart != null && ecart != 0;

        return AlertDialog(
          title: const Text('Clôturer la caisse',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<CompteAvecSoldeVue>(
                initialValue: selection,
                decoration: const InputDecoration(labelText: 'Compte'),
                items: [
                  for (final c in comptes)
                    DropdownMenuItem(value: c, child: Text(c.libelle)),
                ],
                onChanged: (c) => setState(() => selection = c ?? selection),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Solde théorique',
                      style:
                          TextStyle(fontSize: 13, color: AppColors.label)),
                  Text(CurrencyFormatter.format(selection.solde),
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: comptageCtrl,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                    labelText: 'Montant compté', suffixText: 'XOF'),
              ),
              if (ecart != null && ecart != 0) ...[
                const SizedBox(height: 10),
                Text(
                  'Écart : ${CurrencyFormatter.format(ecart)}',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: ecart < 0
                          ? Colors.red.shade900
                          : Colors.orange.shade900),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: motifCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Motif de l\'écart (obligatoire)'),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annuler')),
            FilledButton(
              onPressed: comptage == null ||
                      (motifRequis && motifCtrl.text.trim().isEmpty)
                  ? null
                  : () => Navigator.pop(ctx, true),
              child: const Text('Clôturer'),
            ),
          ],
        );
      },
    ),
  );

  if (ok != true) return;
  final comptage = double.tryParse(comptageCtrl.text.replaceAll(' ', ''));
  if (comptage == null) return;

  try {
    final cloture = await ref.read(tresorerieDatasourceProvider).cloturerCaisse(
          compteId: selection.id,
          soldeCompte: comptage,
          motifEcart: motifCtrl.text.trim(),
        );
    ref.invalidate(tresorerieSummaryProvider);
    if (context.mounted) {
      final msg = cloture.ecart == 0
          ? 'Caisse clôturée sans écart'
          : 'Caisse clôturée — écart de ${CurrencyFormatter.format(cloture.ecart)} enregistré';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Échec de la clôture : $e')));
    }
  }
}

/// Vue minimale (id, libellé, solde) passée au dialog de clôture.
class CompteAvecSoldeVue {
  final int id;
  final String libelle;
  final double solde;
  const CompteAvecSoldeVue(
      {required this.id, required this.libelle, required this.solde});
}

class _CompteDropdown extends StatelessWidget {
  final String label;
  final List<CompteTresorerie> comptes;
  final CompteTresorerie value;
  final ValueChanged<CompteTresorerie> onChanged;

  const _CompteDropdown({
    required this.label,
    required this.comptes,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<CompteTresorerie>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final c in comptes)
          DropdownMenuItem(value: c, child: Text(c.libelle)),
      ],
      onChanged: (c) {
        if (c != null) onChanged(c);
      },
    );
  }
}

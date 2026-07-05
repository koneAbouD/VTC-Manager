import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/encaissement_cotisation.dart';
import '../../domain/entities/ligne_cotisation.dart';
import '../providers/ligne_cotisation_provider.dart';
import 'encaissement_cotisation_form_page.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/motif_annulation_dialog.dart';
import '../../../tresorerie/presentation/providers/tresorerie_providers.dart';

class LigneCotisationDetailPage extends ConsumerWidget {
  final int ligneId;
  const LigneCotisationDetailPage({super.key, required this.ligneId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncLigne = ref.watch(ligneCotisationDetailProvider(ligneId));
    return Scaffold(
      appBar: AppHeader(
        title: 'Détail cotisation',
        action: AppHeaderAction(
          icon: Icons.refresh,
          onTap: () => ref.invalidate(ligneCotisationDetailProvider(ligneId)),
        ),
      ),
      body: asyncLigne.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString().replaceFirst('Exception: ', ''),
            style: const TextStyle(color: Colors.red))),
        data: (ligne) => _Body(ligne: ligne, ligneId: ligneId),
      ),
      floatingActionButton: asyncLigne.valueOrNull?.estActive == true
          ? FloatingActionButton.extended(
              onPressed: () => _encaisser(context, ref, asyncLigne.value!),
              icon: const Icon(Icons.add), label: const Text('Encaisser'))
          : null,
    );
  }

  Future<void> _encaisser(BuildContext context, WidgetRef ref, LigneCotisation ligne) async {
    final ok = await Navigator.push<bool>(context,
        MaterialPageRoute(builder: (_) => EncaissementCotisationFormPage(ligne: ligne)));
    if (ok == true) ref.invalidate(ligneCotisationDetailProvider(ligneId));
  }
}

class _Body extends ConsumerWidget {
  final LigneCotisation ligne;
  final int ligneId;
  const _Body({required this.ligne, required this.ligneId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = NumberFormat.currency(locale: 'fr_FR', symbol: 'XOF', decimalDigits: 0);
    final dateFmt = DateFormat('dd/MM/yyyy');
    final restant = ligne.montantRestant ?? (ligne.montantDu - ligne.montantEncaisse);

    return ListView(padding: const EdgeInsets.all(16), children: [
      Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Row('Cotisation', ligne.nomCotisation),
        _Row('Date', dateFmt.format(ligne.dateCotisation)),
        _Row('Statut', ligne.statut.label),
        if (ligne.motifAnnulation != null && ligne.motifAnnulation!.isNotEmpty)
          _Row('Motif annulation', ligne.motifAnnulation!,
              valueColor: Colors.red),
        _Row('Dû', fmt.format(ligne.montantDu)),
        _Row('Encaissé', fmt.format(ligne.montantEncaisse)),
        _Row('Restant', fmt.format(restant), valueColor: restant > 0 ? Colors.orange : Colors.green),
      ]))),
      const SizedBox(height: 16),
      if (ligne.estActive)
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
          onPressed: () => _annuler(context, ref),
          icon: const Icon(Icons.cancel_outlined), label: const Text('Annuler la ligne'),
        ),
      const SizedBox(height: 20),
      Text('Encaissements (${ligne.encaissements.length})',
          style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      if (ligne.encaissements.isEmpty)
        const Text('Aucun encaissement enregistré.')
      else
        ...ligne.encaissements.map((e) => Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(e.modeEncaissement == ModePaiementCotisation.especes ? Icons.money : Icons.phone_android, color: Colors.green),
            title: Text(fmt.format(e.montant)),
            subtitle: Text('${e.modeEncaissement.label} · ${dateFmt.format(e.dateEncaissement)}'
                '${e.reference != null ? ' · ${e.reference}' : ''}'),
          ),
        )),
    ]);
  }

  Future<void> _annuler(BuildContext context, WidgetRef ref) async {
    final motif = await showMotifAnnulationDialog(context);
    if (motif == null || !context.mounted) return;
    final error = await ref
        .read(ligneCotisationNotifierProvider.notifier)
        .annuler(ligneId, motif);
    if (!context.mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
    } else {
      ref.invalidate(ligneCotisationDetailProvider(ligneId));
      ref.invalidate(balanceAgeeProvider);
      ref.invalidate(balanceAgeeVehiculeProvider);
      ref.invalidate(compteResultatProvider);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ligne annulée')));
    }
  }
}

class _Row extends StatelessWidget {
  final String label; final String value; final Color? valueColor;
  const _Row(this.label, this.value, {this.valueColor});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(color: Colors.grey)),
      Text(value, style: TextStyle(fontWeight: FontWeight.w500, color: valueColor)),
    ]),
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/encaissement.dart';
import '../../domain/entities/ligne_recette.dart';
import '../providers/ligne_recette_provider.dart';
import 'encaissement_form_page.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/motif_annulation_dialog.dart';
import '../../../tresorerie/presentation/providers/tresorerie_providers.dart';

class LigneRecetteDetailPage extends ConsumerWidget {
  final int ligneId;

  const LigneRecetteDetailPage({super.key, required this.ligneId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncLigne = ref.watch(ligneRecetteDetailProvider(ligneId));

    return Scaffold(
      appBar: AppHeader(
        title: 'Détail recette',
        action: AppHeaderAction(
          icon: Icons.refresh,
          onTap: () => ref.invalidate(ligneRecetteDetailProvider(ligneId)),
        ),
      ),
      body: asyncLigne.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(e.toString().replaceFirst('Exception: ', ''),
              style: const TextStyle(color: Colors.red)),
        ),
        data: (ligne) => _DetailBody(ligne: ligne, ligneId: ligneId),
      ),
      floatingActionButton: asyncLigne.valueOrNull?.estActive == true
          ? FloatingActionButton.extended(
              onPressed: () => _openEncaissementForm(context, ref, asyncLigne.value!),
              icon: const Icon(Icons.add),
              label: const Text('Encaisser'),
            )
          : null,
    );
  }

  Future<void> _openEncaissementForm(
      BuildContext context, WidgetRef ref, LigneRecette ligne) async {
    final refreshed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => EncaissementFormPage(ligne: ligne)),
    );
    if (refreshed == true) ref.invalidate(ligneRecetteDetailProvider(ligneId));
  }
}

// ── Corps du détail ────────────────────────────────────────────────────────

class _DetailBody extends ConsumerWidget {
  final LigneRecette ligne;
  final int ligneId;

  const _DetailBody({required this.ligne, required this.ligneId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = NumberFormat.currency(locale: 'fr_FR', symbol: 'XOF', decimalDigits: 0);
    final dateFmt = DateFormat('dd/MM/yyyy');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _InfoCard(
          children: [
            _Row('Date', dateFmt.format(ligne.dateRecette)),
            _Row('Statut', ligne.statut.label),
            if (ligne.motifAnnulation != null &&
                ligne.motifAnnulation!.isNotEmpty)
              _Row('Motif annulation', ligne.motifAnnulation!,
                  valueColor: Colors.red),
            _Row('Encaissé', fmt.format(ligne.montantEncaisse)),
            if (ligne.montantAttendu != null)
              _Row('Attendu', fmt.format(ligne.montantAttendu!)),
            if (ligne.montantRestant != null)
              _Row(
                'Restant',
                fmt.format(ligne.montantRestant!),
                valueColor: ligne.montantRestant! > 0 ? Colors.orange : Colors.green,
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (ligne.estActive && ligne.montantAttendu == null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: FilledButton.icon(
              onPressed: () => _confirmerVersement(context, ref),
              icon: const Icon(Icons.check),
              label: const Text('Confirmer le versement'),
            ),
          ),
        if (ligne.estActive)
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => _annuler(context, ref),
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Annuler la ligne'),
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
                  leading: Icon(
                    e.modeEncaissement == ModeEncaissement.especes
                        ? Icons.money
                        : Icons.phone_android,
                    color: Colors.green,
                  ),
                  title: Text(fmt.format(e.montant)),
                  subtitle: Text(
                    '${e.modeEncaissement.label} · ${dateFmt.format(e.dateEncaissement)}'
                    '${e.reference != null ? ' · ${e.reference}' : ''}',
                  ),
                ),
              )),
      ],
    );
  }

  Future<void> _confirmerVersement(BuildContext context, WidgetRef ref) async {
    final error = await ref
        .read(ligneRecetteNotifierProvider.notifier)
        .confirmerVersement(ligneId);
    if (!context.mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
    } else {
      ref.invalidate(ligneRecetteDetailProvider(ligneId));
    }
  }

  Future<void> _annuler(BuildContext context, WidgetRef ref) async {
    final motif = await showMotifAnnulationDialog(context);
    if (motif == null || !context.mounted) return;

    final error = await ref
        .read(ligneRecetteNotifierProvider.notifier)
        .annuler(ligneId, motif);
    if (!context.mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
    } else {
      // Actualise immédiatement le détail + les écrans finance impactés
      // (la ligne annulée sort des créances et du compte de résultat).
      ref.invalidate(ligneRecetteDetailProvider(ligneId));
      ref.invalidate(balanceAgeeProvider);
      ref.invalidate(balanceAgeeVehiculeProvider);
      ref.invalidate(compteResultatProvider);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ligne annulée')));
    }
  }
}

// ── Widgets utilitaires ───────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _Row(this.label, this.value, {this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value,
              style: TextStyle(fontWeight: FontWeight.w500, color: valueColor)),
        ],
      ),
    );
  }
}

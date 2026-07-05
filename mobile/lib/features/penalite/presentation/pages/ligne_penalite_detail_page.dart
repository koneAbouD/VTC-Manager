import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/ligne_penalite.dart';
import '../providers/penalite_provider.dart';
import 'encaissement_penalite_form_page.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/motif_annulation_dialog.dart';
import '../../../tresorerie/presentation/providers/tresorerie_providers.dart';

class LignePenaliteDetailPage extends ConsumerWidget {
  final int ligneId;
  const LignePenaliteDetailPage({super.key, required this.ligneId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncLigne = ref.watch(lignePenaliteDetailProvider(ligneId));

    return Scaffold(
      appBar: AppHeader(
        title: 'Détail pénalité',
        action: AppHeaderAction(
          icon: Icons.refresh,
          onTap: () => ref.invalidate(lignePenaliteDetailProvider(ligneId)),
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
    );
  }
}

// ── Corps ──────────────────────────────────────────────────────────────────────

class _DetailBody extends ConsumerWidget {
  final LignePenalite ligne;
  final int ligneId;
  const _DetailBody({required this.ligne, required this.ligneId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = NumberFormat.currency(locale: 'fr_FR', symbol: 'XOF', decimalDigits: 0);
    final dateFmt = DateFormat('dd/MM/yyyy');
    final dtFmt = DateFormat('dd/MM/yyyy HH:mm');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Infos générales ────────────────────────────────────────────
        _InfoCard(children: [
          _Row('Type', ligne.typeSanction.label),
          _Row('Pénalité', _typePenaliteLabel(ligne.typePenalite)),
          _Row('Statut', ligne.statut.label),
          if (ligne.motifAnnulation != null && ligne.motifAnnulation!.isNotEmpty)
            _Row('Motif annulation', ligne.motifAnnulation!,
                valueColor: Colors.red),
          _Row('Véhicule',
              ligne.vehiculeImmatriculation ?? '#${ligne.vehiculeId}'),
          if (ligne.chauffeurNomComplet != null)
            _Row('Chauffeur', ligne.chauffeurNomComplet!),
          if (ligne.dateFaute != null)
            _Row('Date de faute', dateFmt.format(ligne.dateFaute!)),
          _Row('Généré le', dateFmt.format(ligne.dateGeneration)),
          if (ligne.commentaire != null)
            _Row('Commentaire', ligne.commentaire!),
        ]),
        const SizedBox(height: 12),

        // ── Infos spécifiques selon le type ────────────────────────────
        if (ligne.typeSanction == TypeSanctionLigne.amende) ...[
          _InfoCard(children: [
            _Row('Montant total', fmt.format(ligne.montant)),
            _Row('Encaissé', fmt.format(ligne.montantEncaisse),
                valueColor: Colors.green),
            if (ligne.montantRestant != null && ligne.montantRestant! > 0)
              _Row('Restant', fmt.format(ligne.montantRestant!),
                  valueColor: Colors.orange),
          ]),
          const SizedBox(height: 12),
        ],
        if (ligne.typeSanction == TypeSanctionLigne.buzzer &&
            ligne.dureeSanctionSecondes != null)
          _InfoCard(children: [
            _Row('Durée buzzer', '${ligne.dureeSanctionSecondes}s'),
          ]),
        if (ligne.typeSanction == TypeSanctionLigne.immobilisation) ...[
          _InfoCard(children: [
            if (ligne.dureeImmobilisationMinutes != null)
              _Row('Durée prévue', '${ligne.dureeImmobilisationMinutes} min'),
            if (ligne.dateDebutImmobilisation != null)
              _Row('Début', dtFmt.format(ligne.dateDebutImmobilisation!)),
            if (ligne.dateFinImmobilisation != null)
              _Row('Fin', dtFmt.format(ligne.dateFinImmobilisation!)),
          ]),
          const SizedBox(height: 12),
        ],

        // ── Boutons d'action ───────────────────────────────────────────
        if (ligne.isEncaissable)
          _ActionButton(
            label: 'Encaisser',
            icon: Icons.payments,
            color: Colors.green,
            onPressed: () => _openEncaissement(context, ref, ligne),
          ),
        if (ligne.isExecutable)
          _ActionButton(
            label: 'Marquer comme exécuté',
            icon: Icons.volume_up,
            color: Colors.orange,
            onPressed: () => _executer(context, ref),
          ),
        if (ligne.isNotifiable)
          _ActionButton(
            label: 'Marquer comme notifié',
            icon: Icons.warning_amber,
            color: Colors.amber.shade700,
            onPressed: () => _notifier(context, ref),
          ),
        if (ligne.isDemarrable)
          _ActionButton(
            label: 'Démarrer l\'immobilisation',
            icon: Icons.block,
            color: Colors.red,
            onPressed: () => _demarrer(context, ref),
          ),
        if (ligne.isLevable)
          _ActionButton(
            label: 'Lever l\'immobilisation',
            icon: Icons.lock_open,
            color: Colors.purple,
            onPressed: () => _lever(context, ref),
          ),
        if (!ligne.statut.isTerminal) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => _annuler(context, ref),
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Annuler la pénalité'),
          ),
        ],

        // ── Historique encaissements (AMENDE) ──────────────────────────
        if (ligne.typeSanction == TypeSanctionLigne.amende) ...[
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
                      e.modeEncaissement == 'ESPECES'
                          ? Icons.money
                          : Icons.phone_android,
                      color: Colors.green,
                    ),
                    title: Text(fmt.format(e.montant)),
                    subtitle: Text(
                      '${e.modeEncaissement} · ${dateFmt.format(e.dateEncaissement)}'
                      '${e.reference != null ? ' · ${e.reference}' : ''}',
                    ),
                  ),
                )),
        ],
      ],
    );
  }

  String _typePenaliteLabel(String type) => switch (type) {
        'RECETTE_NON_VERSEE'      => 'Recette non versée',
        'HEURE_FIN_SERVICE_PASSE' => 'Fin de service dépassée',
        'EXCES_VITESSE'           => 'Excès de vitesse',
        _                         => type,
      };

  Future<void> _openEncaissement(
      BuildContext context, WidgetRef ref, LignePenalite l) async {
    final refreshed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => EncaissementPenaliteFormPage(ligne: l)),
    );
    if (refreshed == true) ref.invalidate(lignePenaliteDetailProvider(ligneId));
  }

  Future<void> _executer(BuildContext context, WidgetRef ref) =>
      _executeAction(context, ref,
          () => ref.read(lignePenaliteNotifierProvider.notifier).executerDetail(ligneId));

  Future<void> _notifier(BuildContext context, WidgetRef ref) =>
      _executeAction(context, ref,
          () => ref.read(lignePenaliteNotifierProvider.notifier).notifierDetail(ligneId));

  Future<void> _demarrer(BuildContext context, WidgetRef ref) =>
      _executeAction(context, ref,
          () => ref.read(lignePenaliteNotifierProvider.notifier).demarrerDetail(ligneId));

  Future<void> _lever(BuildContext context, WidgetRef ref) =>
      _executeAction(context, ref,
          () => ref.read(lignePenaliteNotifierProvider.notifier).leverDetail(ligneId));

  Future<void> _annuler(BuildContext context, WidgetRef ref) async {
    final motif = await showMotifAnnulationDialog(context,
        titre: 'Annuler la pénalité ?');
    if (motif == null || !context.mounted) return;
    final error = await ref
        .read(lignePenaliteNotifierProvider.notifier)
        .annulerDetail(ligneId, motif);
    if (!context.mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red));
    } else {
      // Actualise immédiatement le détail + les écrans finance impactés.
      ref.invalidate(lignePenaliteDetailProvider(ligneId));
      ref.invalidate(balanceAgeeProvider);
      ref.invalidate(balanceAgeeVehiculeProvider);
      ref.invalidate(compteResultatProvider);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pénalité annulée')));
    }
  }

  Future<void> _executeAction(BuildContext context, WidgetRef ref,
      Future<String?> Function() action) async {
    final error = await action();
    if (!context.mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
    } else {
      ref.invalidate(lignePenaliteDetailProvider(ligneId));
    }
  }
}

// ── Widgets utilitaires ───────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: children),
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
              style: TextStyle(
                  fontWeight: FontWeight.w500, color: valueColor)),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  const _ActionButton(
      {required this.label,
      required this.icon,
      required this.color,
      required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: FilledButton.icon(
        style: FilledButton.styleFrom(backgroundColor: color),
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }
}

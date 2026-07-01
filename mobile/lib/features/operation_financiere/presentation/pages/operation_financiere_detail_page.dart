import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/app_header.dart';
import '../../domain/entities/operation_financiere.dart';
import '../../domain/enums/mode_paiement.dart';
import '../../domain/enums/statut_operation.dart';
import '../../domain/enums/type_operation.dart';
import '../providers/operation_financiere_provider.dart';
import '../providers/operation_financiere_state.dart';
import 'operation_financiere_form_page.dart';

/// Page de détail d'une opération financière.
///
/// Reçoit l'opération sélectionnée et relit en continu la liste partagée du
/// provider : ainsi, après une modification via le formulaire, le détail
/// reflète automatiquement les nouvelles valeurs.
class OperationFinanciereDetailPage extends ConsumerWidget {
  final OperationFinanciere operation;
  const OperationFinanciereDetailPage({super.key, required this.operation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(operationFinanciereNotifierProvider);
    final ops = switch (state) {
      OperationFinanciereLoaded(:final operations) => operations,
      OperationFinanciereActionSuccess(:final operations) => operations,
      _ => const <OperationFinanciere>[],
    };
    // NB : on n'utilise pas `firstWhere(orElse:)` car `ops` peut contenir à
    // l'exécution des sous-types (OperationFinanciereModel) ; la covariance
    // ferait alors échouer le closure `orElse` typé OperationFinanciere.
    final match = ops.where((o) => o.id == operation.id);
    final op = match.isEmpty ? operation : match.first;

    return Scaffold(
      appBar: const AppHeader(title: 'Détail opération'),
      body: _DetailBody(op: op),
    );
  }
}

// ── Corps ──────────────────────────────────────────────────────────────────

class _DetailBody extends ConsumerWidget {
  final OperationFinanciere op;
  const _DetailBody({required this.op});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final money =
        NumberFormat.currency(locale: 'fr_FR', symbol: 'XOF', decimalDigits: 0);
    final dateFmt = DateFormat('dd/MM/yyyy', 'fr_FR');

    final isRevenu = op.typeOperation == TypeOperation.REVENU;
    final color =
        isRevenu ? const Color(0xFF2E7D32) : const Color(0xFFC62828);
    final sign = isRevenu ? '+' : '-';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Bandeau montant ───────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Icon(
                isRevenu
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
                color: color,
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                '$sign${money.format(op.montant)}',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 26,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                op.typeOperation.libelle,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 10),
              _StatutBadge(statut: op.statut),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Informations générales ────────────────────────────────────────
        _InfoCard(children: [
          if (op.categorieLibelle != null)
            _Row('Catégorie', op.categorieLibelle!),
          if (op.sousCategorieLibelle != null)
            _Row('Sous-catégorie', op.sousCategorieLibelle!),
          _Row('Date', dateFmt.format(op.dateOperation)),
          if (op.modePaiement != null)
            _Row('Mode de paiement', op.modePaiement!.libelle),
          if (op.vehiculeNom != null) _Row('Véhicule', op.vehiculeNom!),
          if (op.chauffeurNom != null) _Row('Chauffeur', op.chauffeurNom!),
          if (op.reference != null) _Row('Référence', op.reference!),
          if (op.commentaire != null && op.commentaire!.isNotEmpty)
            _Row('Commentaire', op.commentaire!),
        ]),

        // ── Détail maintenance (si présent) ──────────────────────────────
        if (op.detailMaintenance != null) ...[
          const SizedBox(height: 16),
          Text('Détail maintenance',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _InfoCard(children: [
            if (op.detailMaintenance!.dureeMaintenance != null)
              _Row('Durée',
                  '${op.detailMaintenance!.dureeMaintenance} min'),
            for (final el in op.detailMaintenance!.elements)
              _Row(el.effectiveLibelle, money.format(el.montant)),
          ]),
        ],

        const SizedBox(height: 24),

        // ── Actions (masquées si l'opération est déjà annulée) ────────────
        if (op.statut != StatutOperation.ANNULEE) ...[
          FilledButton.icon(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32)),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => OperationFinanciereFormPage(
                  initialType: op.typeOperation,
                  initial: op,
                ),
              ),
            ),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Modifier'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => _supprimer(context, ref),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Annuler'),
          ),
        ],
      ],
    );
  }

  Future<void> _supprimer(BuildContext context, WidgetRef ref) async {
    final id = op.id;
    if (id == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Annuler l\'opération ?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Non')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Oui, Annuler'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (!context.mounted) return;

    final error = await ref
        .read(operationFinanciereNotifierProvider.notifier)
        .annuler(id);
    if (!context.mounted) return;

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Opération annulée')),
      );
      Navigator.pop(context);
    }
  }
}

// ── Widgets utilitaires ─────────────────────────────────────────────────────

class _StatutBadge extends StatelessWidget {
  final StatutOperation statut;
  const _StatutBadge({required this.statut});

  @override
  Widget build(BuildContext context) {
    final color = switch (statut) {
      StatutOperation.ENCAISSE => Colors.green.shade600,
      StatutOperation.PAYE => Colors.green.shade600,
      StatutOperation.ANNULEE => Colors.red.shade400,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        statut.libelle,
        style: TextStyle(
            color: color, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                  fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

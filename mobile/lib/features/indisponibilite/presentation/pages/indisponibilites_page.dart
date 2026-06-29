import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_header.dart';
import '../../domain/entities/indisponibilite.dart';
import '../providers/indisponibilite_provider.dart';
import '../providers/indisponibilite_state.dart';
import 'indisponibilite_detail_page.dart';
import 'indisponibilite_form_page.dart';

class IndisponibilitesPage  extends ConsumerStatefulWidget {
  const IndisponibilitesPage({super.key});

  @override
  ConsumerState<IndisponibilitesPage> createState() => _State();
}

class _State extends ConsumerState<IndisponibilitesPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(indisponibiliteNotifierProvider.notifier).load());
  }

  void _openForm([Indisponibilite? i]) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => IndisponibiliteFormPage(initial: i)),
    );
  }

  void _openDetail(Indisponibilite i) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => IndisponibiliteDetailPage(indisponibilite: i)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(indisponibiliteNotifierProvider);

    return Scaffold(
      appBar: AppHeader(
        title: 'Indisponibilités',
        action: AppHeaderAction(icon: Icons.add_rounded, onTap: _openForm),
      ),
      body: switch (state) {
        IndisponibiliteLoading() =>
          const Center(child: CircularProgressIndicator()),
        IndisponibiliteError(:final message) => _ErrorView(
            message: message,
            onRetry: () =>
                ref.read(indisponibiliteNotifierProvider.notifier).load(),
          ),
        IndisponibiliteLoaded(:final indisponibilites) =>
          indisponibilites.isEmpty
              ? _EmptyView(onAdd: _openForm)
              : RefreshIndicator(
                  onRefresh: () =>
                      ref.read(indisponibiliteNotifierProvider.notifier).load(),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: indisponibilites.length,
                    itemBuilder: (_, idx) => _IndispoCard(
                      indispo: indisponibilites[idx],
                      onView: () => _openDetail(indisponibilites[idx]),
                      onEdit: () => _openForm(indisponibilites[idx]),
                    ),
                  ),
                ),
        _ => const SizedBox.shrink(),
      },
    );
  }
}

// ── Carte ─────────────────────────────────────────────────────────────────────

class _IndispoCard extends ConsumerWidget {
  final Indisponibilite indispo;
  final VoidCallback onView;
  final VoidCallback onEdit;
  const _IndispoCard(
      {required this.indispo, required this.onView, required this.onEdit});

  (Color, String) _statut(String? s) => switch (s) {
        'EN_COURS' => (const Color(0xFFE65100), 'En cours'),
        'PLANIFIEE' => (const Color(0xFF1565C0), 'Planifiée'),
        'TERMINEE' => (AppColors.primaryDark, 'Terminée'),
        'ANNULEE' => (const Color(0xFF616161), 'Annulée'),
        _ => (const Color(0xFF616161), s ?? '—'),
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = DateFormat('dd MMM', 'fr_FR');
    final (color, label) = _statut(indispo.statut);
    final fmtLong = DateFormat('dd MMM yyyy', 'fr_FR');
    final bool unJour = indispo.dateFin != null &&
        indispo.dateFin!.year == indispo.dateDebut.year &&
        indispo.dateFin!.month == indispo.dateDebut.month &&
        indispo.dateFin!.day == indispo.dateDebut.day;
    final periode = unJour
        ? 'Le ${fmtLong.format(indispo.dateDebut)}'
        : indispo.dateFin == null
            ? 'Depuis le ${fmtLong.format(indispo.dateDebut)}'
            : '${fmt.format(indispo.dateDebut)} → ${fmtLong.format(indispo.dateFin!)}';

    return GestureDetector(
      onTap: onView,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    indispo.chauffeurNom ?? 'Chauffeur',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.dark),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(label,
                      style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
                _menu(context, ref),
              ],
            ),
            const SizedBox(height: 8),
            _row(Icons.event_outlined, periode),
            if (indispo.motif != null && indispo.motif!.isNotEmpty) ...[
              const SizedBox(height: 4),
              _row(Icons.label_outline_rounded, indispo.motif!),
            ],
            if (indispo.chauffeurRemplacantNom != null) ...[
              const SizedBox(height: 4),
              _row(Icons.switch_account_outlined,
                  'Remplacé par ${indispo.chauffeurRemplacantNom}'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, String text) => Row(
        children: [
          Icon(icon, size: 15, color: AppColors.hint),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 13, color: AppColors.label)),
          ),
        ],
      );

  Widget _menu(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(indisponibiliteNotifierProvider.notifier);
    // Une indispo terminée ou annulée est figée : aucune action de modification.
    final estFigee = indispo.statut == 'TERMINEE' || indispo.statut == 'ANNULEE';
    final items = <PopupMenuEntry<String>>[
      if (!estFigee)
        const PopupMenuItem(value: 'modifier', child: Text('Modifier')),
      if (indispo.statut == 'EN_COURS')
        const PopupMenuItem(value: 'terminer', child: Text('Terminer')),
      if (indispo.statut == 'PLANIFIEE')
        const PopupMenuItem(value: 'supprimer', child: Text('Supprimer')),
    ];
    // Aucune action disponible (ex. terminée) → pas de bouton menu.
    if (items.isEmpty) return const SizedBox.shrink();

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 18, color: AppColors.hint),
      onSelected: (v) async {
        if (v == 'modifier') {
          onEdit();
          return;
        }

        String? err;
        if (v == 'terminer') {
          err = await notifier.terminer(indispo.id!);
        } else if (v == 'supprimer') {
          if (!await _confirmSuppression(context)) return;
          err = await notifier.delete(indispo.id!);
        }
        if (context.mounted && err != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(err), backgroundColor: AppColors.error));
        }
      },
      itemBuilder: (_) => items,
    );
  }

  Future<bool> _confirmSuppression(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer l\'indisponibilité ?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Non')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Oui, supprimer'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }
}

// ── Vues d'état ────────────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyView({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy_rounded, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          const Text('Aucune indisponibilité',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 4),
          Text('Déclarez l\'indisponibilité d\'un chauffeur.',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 56, color: Colors.red.shade300),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }
}

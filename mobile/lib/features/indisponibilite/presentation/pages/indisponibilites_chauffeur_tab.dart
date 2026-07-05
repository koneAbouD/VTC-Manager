import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:intl/intl.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/pagination/paged_list_notifier.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/indisponibilite.dart';
import '../providers/indisponibilite_provider.dart';
import 'indisponibilite_detail_page.dart';
import 'indisponibilite_form_page.dart';

/// Onglet « Chauffeurs » de la page Indisponibilités : liste (scroll infini) des
/// indisponibilités chauffeur. N'a pas de Scaffold : il est hébergé par
/// [IndisponibilitesPage].
class IndisponibilitesChauffeurTab extends ConsumerStatefulWidget {
  const IndisponibilitesChauffeurTab({super.key});

  @override
  ConsumerState<IndisponibilitesChauffeurTab> createState() => _State();
}

class _State extends ConsumerState<IndisponibilitesChauffeurTab> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 300) {
      ref.read(indisponibilitesListeProvider.notifier).loadMore();
    }
  }

  void _load() {
    final ds = ref.read(indisponibiliteDatasourceProvider);
    ref.read(indisponibilitesListeProvider.notifier).load((page, size) async {
      try {
        return Right(await ds.getIndisponibilitesPage(page: page, size: size));
      } on ApiException catch (e) {
        return Left(ServerFailure(e.message, statusCode: e.statusCode));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(e.message));
      } catch (e) {
        return Left(UnknownFailure(e.toString()));
      }
    });
  }

  Future<void> _openForm([Indisponibilite? i]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => IndisponibiliteFormPage(initial: i)),
    );
    if (mounted) ref.read(indisponibilitesListeProvider.notifier).refresh();
  }

  Future<void> _openDetail(Indisponibilite i) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => IndisponibiliteDetailPage(indisponibilite: i)),
    );
    if (mounted) ref.read(indisponibilitesListeProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(indisponibilitesListeProvider);
    final items = state.items;

    if (state.initialLoading && items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && items.isEmpty) {
      return _ErrorView(message: state.error!, onRetry: _load);
    }
    if (items.isEmpty) {
      return _EmptyView(onAdd: _openForm);
    }
    return RefreshIndicator(
      onRefresh: () =>
          ref.read(indisponibilitesListeProvider.notifier).refresh(),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: items.length + (state.hasMore ? 1 : 0),
        itemBuilder: (_, idx) {
          if (idx >= items.length) {
            return const PagedListLoadMoreTile();
          }
          return _IndispoCard(
            indispo: items[idx],
            onView: () => _openDetail(items[idx]),
            onEdit: () => _openForm(items[idx]),
          );
        },
      ),
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
    final estFigee = indispo.statut == 'TERMINEE' || indispo.statut == 'ANNULEE';
    final items = <PopupMenuEntry<String>>[
      if (!estFigee)
        const PopupMenuItem(value: 'modifier', child: Text('Modifier')),
      if (indispo.statut == 'EN_COURS')
        const PopupMenuItem(value: 'terminer', child: Text('Terminer')),
      if (indispo.statut == 'PLANIFIEE')
        const PopupMenuItem(value: 'supprimer', child: Text('Supprimer')),
    ];
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
        if (err != null) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(err), backgroundColor: AppColors.error));
          }
        } else {
          ref.read(indisponibilitesListeProvider.notifier).refresh();
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/recette_provider.dart';
import '../providers/recette_state.dart';
import '../widgets/recette_card.dart';
import 'recette_form_page.dart';

enum _ToastType { success, error, warning, info }

void _appToast(
  BuildContext context,
  String message, {
  _ToastType type = _ToastType.success,
  Duration? duration,
}) {
  final (Color bg, IconData icon) = switch (type) {
    _ToastType.success => (const Color(0xFF1B5E20), Icons.check_circle_outline_rounded),
    _ToastType.error   => (const Color(0xFFB71C1C), Icons.error_outline_rounded),
    _ToastType.warning => (const Color(0xFFE65100), Icons.warning_amber_rounded),
    _ToastType.info    => (const Color(0xFF1A237E), Icons.info_outline_rounded),
  };
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(message,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white)),
        ),
      ]),
      backgroundColor: bg,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      duration: duration ??
          (type == _ToastType.error || type == _ToastType.warning
              ? const Duration(seconds: 4)
              : const Duration(seconds: 2)),
    ));
}

class RecettesPage extends ConsumerStatefulWidget {
  const RecettesPage({super.key});

  @override
  ConsumerState<RecettesPage> createState() => _RecettesPageState();
}

class _RecettesPageState extends ConsumerState<RecettesPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(recetteNotifierProvider.notifier).loadRecettes(),
    );
  }

  Future<void> _confirmDelete(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la recette'),
        content: const Text('Confirmer la suppression de cette recette ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final error =
        await ref.read(recetteNotifierProvider.notifier).deleteRecette(id);
    if (mounted && error != null) {
      _appToast(context, error, type: _ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recetteNotifierProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: switch (state) {
        RecetteLoading() => const Center(child: CircularProgressIndicator()),
        RecetteError(:final message) => _ErrorView(
            message: message,
            onRetry: () =>
                ref.read(recetteNotifierProvider.notifier).loadRecettes(),
          ),
        RecetteLoaded(:final recettes) ||
        RecetteActionSuccess(:final recettes) =>
          recettes.isEmpty
              ? _EmptyView(
                  onRetry: () =>
                      ref.read(recetteNotifierProvider.notifier).loadRecettes(),
                )
              : RefreshIndicator(
                  onRefresh: () =>
                      ref.read(recetteNotifierProvider.notifier).loadRecettes(),
                  child: Column(
                    children: [
                      // Total banner
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.green.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Total recettes',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.green[700],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatTotal(recettes.fold(
                                  0.0,
                                  (sum, r) => sum + r.montant)),
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: recettes.length,
                          itemBuilder: (ctx, i) {
                            final r = recettes[i];
                            return RecetteCard(
                              recette: r,
                              onEdit: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        RecetteFormPage(initial: r),
                                  ),
                                );
                              },
                              onDelete: () => _confirmDelete(r.id!),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
        _ => const Center(child: CircularProgressIndicator()),
      },
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RecetteFormPage()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
    );
  }

  String _formatTotal(double total) =>
      '${total.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ')} FCFA';
}

class _EmptyView extends StatelessWidget {
  final VoidCallback onRetry;
  const _EmptyView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.attach_money, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('Aucune recette',
              style: TextStyle(fontSize: 16, color: Colors.grey)),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Rafraîchir'),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}

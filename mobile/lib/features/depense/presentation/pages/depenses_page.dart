import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/depense_provider.dart';
import '../providers/depense_state.dart';
import '../widgets/depense_card.dart';
import 'depense_form_page.dart';

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

class DepensesPage extends ConsumerStatefulWidget {
  const DepensesPage({super.key});

  @override
  ConsumerState<DepensesPage> createState() => _DepensesPageState();
}

class _DepensesPageState extends ConsumerState<DepensesPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(depenseNotifierProvider.notifier).loadDepenses(),
    );
  }

  Future<void> _confirmDelete(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la dépense'),
        content: const Text('Confirmer la suppression de cette dépense ?'),
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
        await ref.read(depenseNotifierProvider.notifier).deleteDepense(id);
    if (mounted && error != null) {
      _appToast(context, error, type: _ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(depenseNotifierProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: switch (state) {
        DepenseLoading() => const Center(child: CircularProgressIndicator()),
        DepenseError(:final message) => _ErrorView(
            message: message,
            onRetry: () =>
                ref.read(depenseNotifierProvider.notifier).loadDepenses(),
          ),
        DepenseLoaded(:final depenses) ||
        DepenseActionSuccess(:final depenses) =>
          depenses.isEmpty
              ? _EmptyView(
                  onRetry: () =>
                      ref.read(depenseNotifierProvider.notifier).loadDepenses(),
                )
              : RefreshIndicator(
                  onRefresh: () =>
                      ref.read(depenseNotifierProvider.notifier).loadDepenses(),
                  child: Column(
                    children: [
                      // Total banner
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.red.withOpacity(0.25)),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Total dépenses',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.red[700],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatTotal(depenses.fold(
                                  0.0, (sum, d) => sum + d.montant)),
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.red[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: depenses.length,
                          itemBuilder: (ctx, i) {
                            final d = depenses[i];
                            return DepenseCard(
                              depense: d,
                              onEdit: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        DepenseFormPage(initial: d),
                                  ),
                                );
                              },
                              onDelete: () => _confirmDelete(d.id!),
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
            MaterialPageRoute(builder: (_) => const DepenseFormPage()),
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
          const Icon(Icons.money_off, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('Aucune dépense',
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

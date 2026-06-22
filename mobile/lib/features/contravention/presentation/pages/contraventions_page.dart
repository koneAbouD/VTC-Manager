import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/contravention_provider.dart';
import '../providers/contravention_state.dart';
import '../widgets/contravention_card.dart';
import 'contravention_form_page.dart';

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

class ContraventionsPage extends ConsumerStatefulWidget {
  const ContraventionsPage({super.key});

  @override
  ConsumerState<ContraventionsPage> createState() => _ContraventionsPageState();
}

class _ContraventionsPageState extends ConsumerState<ContraventionsPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () =>
          ref.read(contraventionNotifierProvider.notifier).loadContraventions(),
    );
  }

  Future<void> _confirmDelete(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la contravention'),
        content: const Text('Confirmer la suppression ?'),
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

    final error = await ref
        .read(contraventionNotifierProvider.notifier)
        .deleteContravention(id);
    if (mounted && error != null) {
      _appToast(context, error, type: _ToastType.error);
    }
  }

  Future<void> _showPayDialog(int id) async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enregistrer un paiement'),
        content: TextFormField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Montant payé',
            prefixIcon: Icon(Icons.attach_money),
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final montant = double.tryParse(ctrl.text.replaceAll(',', '.'));
    if (montant == null || montant <= 0) {
      if (mounted) {
        _appToast(context, 'Montant invalide', type: _ToastType.warning);
      }
      return;
    }

    final error = await ref
        .read(contraventionNotifierProvider.notifier)
        .payContravention(id, montant);
    if (mounted && error != null) {
      _appToast(context, error, type: _ToastType.error);
    } else if (mounted) {
      _appToast(context, 'Paiement enregistré !');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(contraventionNotifierProvider);

    return Scaffold(
      body: switch (state) {
        ContraventionLoading() =>
          const Center(child: CircularProgressIndicator()),
        ContraventionError(:final message) => _ErrorView(
            message: message,
            onRetry: () => ref
                .read(contraventionNotifierProvider.notifier)
                .loadContraventions(),
          ),
        ContraventionLoaded(:final contraventions) ||
        ContraventionActionSuccess(:final contraventions) =>
          contraventions.isEmpty
              ? _EmptyView(
                  onRetry: () => ref
                      .read(contraventionNotifierProvider.notifier)
                      .loadContraventions(),
                )
              : RefreshIndicator(
                  onRefresh: () => ref
                      .read(contraventionNotifierProvider.notifier)
                      .loadContraventions(),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: contraventions.length,
                    itemBuilder: (ctx, i) {
                      final c = contraventions[i];
                      return ContraventionCard(
                        contravention: c,
                        onEdit: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ContraventionFormPage(initial: c),
                            ),
                          );
                        },
                        onDelete: () => _confirmDelete(c.id!),
                        onPay: c.isPaid ? null : () => _showPayDialog(c.id!),
                      );
                    },
                  ),
                ),
        _ => const Center(child: CircularProgressIndicator()),
      },
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const ContraventionFormPage()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
    );
  }
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
          const Icon(Icons.gavel, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('Aucune contravention',
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

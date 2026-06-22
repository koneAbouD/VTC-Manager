import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/maintenance_provider.dart';
import '../providers/maintenance_state.dart';
import '../widgets/maintenance_card.dart';
import 'maintenance_detail_page.dart';
import 'maintenance_form_page.dart';

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

class MaintenancesPage extends ConsumerStatefulWidget {
  const MaintenancesPage({super.key});

  @override
  ConsumerState<MaintenancesPage> createState() => _MaintenancesPageState();
}

class _MaintenancesPageState extends ConsumerState<MaintenancesPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(maintenanceNotifierProvider.notifier).loadMaintenances(),
    );
  }

  Future<void> _confirmDelete(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la maintenance'),
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
        .read(maintenanceNotifierProvider.notifier)
        .deleteMaintenance(id);
    if (mounted && error != null) {
      _appToast(context, error, type: _ToastType.error);
    }
  }

  Future<void> _showCompleteDialog(int id) async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Terminer la maintenance'),
        content: TextFormField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Coût (FCFA)',
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
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final cout = double.tryParse(ctrl.text.replaceAll(',', '.')) ?? 0.0;

    final error = await ref
        .read(maintenanceNotifierProvider.notifier)
        .completeMaintenance(id, cout);
    if (mounted && error != null) {
      _appToast(context, error, type: _ToastType.error);
    } else if (mounted) {
      _appToast(context, 'Maintenance terminée !');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(maintenanceNotifierProvider);

    return Scaffold(
      body: switch (state) {
        MaintenanceLoading() =>
          const Center(child: CircularProgressIndicator()),
        MaintenanceError(:final message) => _ErrorView(
            message: message,
            onRetry: () => ref
                .read(maintenanceNotifierProvider.notifier)
                .loadMaintenances(),
          ),
        MaintenanceLoaded(:final maintenances) ||
        MaintenanceActionSuccess(:final maintenances) =>
          maintenances.isEmpty
              ? _EmptyView(
                  onRetry: () => ref
                      .read(maintenanceNotifierProvider.notifier)
                      .loadMaintenances(),
                )
              : RefreshIndicator(
                  onRefresh: () => ref
                      .read(maintenanceNotifierProvider.notifier)
                      .loadMaintenances(),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: maintenances.length,
                    itemBuilder: (ctx, i) {
                      final m = maintenances[i];
                      return MaintenanceCard(
                        maintenance: m,
                        onTap: () async {
                          final result = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  MaintenanceDetailPage(maintenance: m),
                            ),
                          );
                          if (result == true && mounted) {
                            ref
                                .read(maintenanceNotifierProvider.notifier)
                                .loadMaintenances();
                          }
                        },
                        onEdit: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  MaintenanceFormPage(initial: m),
                            ),
                          );
                        },
                        onDelete: () => _confirmDelete(m.id!),
                        onComplete: m.isDone
                            ? null
                            : () => _showCompleteDialog(m.id!),
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
            MaterialPageRoute(builder: (_) => const MaintenanceFormPage()),
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
          const Icon(Icons.build_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('Aucune maintenance',
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

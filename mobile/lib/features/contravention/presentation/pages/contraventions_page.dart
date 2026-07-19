import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/pagination/paged_list_notifier.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/contravention.dart';
import '../providers/contravention_provider.dart';
import '../widgets/contravention_card.dart';
import 'contravention_detail_page.dart';
import 'contravention_form_page.dart';
import 'contravention_import_page.dart';

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

final _money = NumberFormat('#,##0', 'fr_FR');

class ContraventionsPage extends ConsumerStatefulWidget {
  /// Encastré dans le hub Contraventions : masque son FAB propre
  /// (les actions import/saisie sont fournies par le hub).
  final bool embedded;

  /// Recherche pilotée par le hub (numéro, véhicule, chauffeur, infraction).
  final String? externalSearch;

  const ContraventionsPage({
    super.key,
    this.embedded = false,
    this.externalSearch,
  });

  @override
  ConsumerState<ContraventionsPage> createState() => _ContraventionsPageState();
}

class _ContraventionsPageState extends ConsumerState<ContraventionsPage> {
  final _scrollController = ScrollController();

  // ── Sélection multiple (activée par appui long sur une ligne) ──────────
  final Set<int> _selectedIds = {};

  /// Mode sélection actif : déclenché par un appui long, affiche la barre
  /// « Tout sélectionner / Annuler » et fait du tap une (dé)sélection.
  bool _selectionMode = false;

  // ── Paiement en lot ────────────────────────────────────────────────────
  bool _paying = false;
  int _payDone = 0;
  int _payTotal = 0;

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
      ref.read(contraventionsListeProvider.notifier).loadMore();
    }
  }

  void _load() {
    final repo = ref.read(contraventionRepositoryProvider);
    ref.read(contraventionsListeProvider.notifier).load(
          (page, size) => repo.getContraventionsPage(page: page, size: size),
        );
  }

  void _refresh() => ref.read(contraventionsListeProvider.notifier).refresh();

  // ── Sélection ──────────────────────────────────────────────────────────

  /// Appui long sur une ligne : entre en mode sélection et coche cette ligne.
  void _enterSelection(int id) {
    setState(() {
      _selectionMode = true;
      _selectedIds.add(id);
    });
  }

  void _toggleSelect(int id, bool value) {
    setState(() {
      if (value) {
        _selectedIds.add(id);
      } else {
        _selectedIds.remove(id);
      }
      // Plus rien de sélectionné → on quitte le mode sélection.
      if (_selectedIds.isEmpty) _selectionMode = false;
    });
  }

  void _toggleSelectAll(List<Contravention> selectable) {
    final allIds = selectable.map((c) => c.id!).toSet();
    final allSelected =
        allIds.isNotEmpty && allIds.every(_selectedIds.contains);
    setState(() {
      if (allSelected) {
        // « Annuler » : on vide la sélection et on quitte le mode.
        _selectedIds.removeAll(allIds);
        if (_selectedIds.isEmpty) _selectionMode = false;
      } else {
        _selectedIds.addAll(allIds);
      }
    });
  }

  /// Popup premium de confirmation du reversement en lot (charte : couleurs
  /// primaire/tint, titre w800, carte total mise en avant, boutons arrondis).
  Future<bool?> _confirmerPaiement(int count, double total) {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.surface,
        insetPadding:
            const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Icône dans une pastille teintée.
              Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryTint,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.account_balance_outlined,
                      size: 28, color: AppColors.primaryDark),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Reverser la sélection',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.dark,
                    letterSpacing: -0.4),
              ),
              const SizedBox(height: 8),
              Text(
                '$count contravention(s) vont être reversées à l\'État. '
                'Une opération « Reversement contravention » sera enregistrée '
                'pour chacune.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13.5, height: 1.4, color: AppColors.label),
              ),
              const SizedBox(height: 18),
              // Carte total mise en avant + badge du nombre.
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.primaryTint,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: AppColors.surface,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.payments_outlined,
                          size: 20, color: AppColors.primaryDark),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total à reverser',
                              style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryDark)),
                          const SizedBox(height: 2),
                          Text('${_money.format(total)} XOF',
                              style: const TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primaryDark,
                                  letterSpacing: -0.5)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('$count',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.label,
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Annuler',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.account_balance_outlined,
                            size: 18),
                        label: const Text('Reverser',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Paiement en lot (reversement à l'État) ──────────────────────────────
  Future<void> _payerSelection(List<Contravention> selected) async {
    if (selected.isEmpty) return;
    final total = selected.fold<double>(0, (s, c) => s + c.montant);

    final confirmed = await _confirmerPaiement(selected.length, total);
    if (confirmed != true) return;

    setState(() {
      _paying = true;
      _payDone = 0;
      _payTotal = selected.length;
    });

    final notifier = ref.read(contraventionNotifierProvider.notifier);
    var ok = 0;
    final erreurs = <String>[];
    for (final c in selected) {
      final err = await notifier.reverserContravention(c.id!);
      if (err == null) {
        ok++;
      } else {
        erreurs.add(err);
      }
      if (!mounted) return;
      setState(() => _payDone = ok + erreurs.length);
    }

    if (!mounted) return;
    setState(() {
      _paying = false;
      _selectedIds.clear();
    });
    _refresh();

    if (erreurs.isEmpty) {
      _appToast(context, '$ok contravention(s) reversée(s).');
    } else {
      _appToast(
        context,
        '$ok reversée(s), ${erreurs.length} en échec.',
        type: _ToastType.warning,
      );
    }
  }

  // ── Filtre recherche ─────────────────────────────────────────────────────

  List<Contravention> _filtrer(List<Contravention> all) {
    final query = (widget.externalSearch ?? '').trim().toLowerCase();
    if (query.isEmpty) return all;
    return all.where((c) {
      final hay = [
        c.numeroContravention ?? '',
        c.vehiculeNom ?? '',
        c.chauffeurNom ?? '',
        c.typeInfraction ?? '',
        c.codeInfraction ?? '',
        c.lieu ?? '',
      ].join(' ').toLowerCase();
      return hay.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(contraventionsListeProvider);
    final items = _filtrer(state.items);

    // Éligibles au paiement en lot = non soldées et identifiables.
    final selectables =
        items.where((c) => c.id != null && !c.isRegle).toList();
    final selected = items
        .where((c) => c.id != null && _selectedIds.contains(c.id))
        .toList();
    final selTotal = selected.fold<double>(0, (s, c) => s + c.montant);
    final allSelected = selectables.isNotEmpty &&
        selectables.every((c) => _selectedIds.contains(c.id));

    final body = state.initialLoading && items.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : (state.error != null && items.isEmpty)
            ? _ErrorView(message: state.error!, onRetry: _load)
            : items.isEmpty
                ? _EmptyView(onRetry: _load)
                : RefreshIndicator(
                    onRefresh: () async => _refresh(),
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: items.length + (state.hasMore ? 1 : 0),
                      itemBuilder: (ctx, i) {
                        if (i >= items.length) {
                          return const PagedListLoadMoreTile();
                        }
                        final c = items[i];
                        return ContraventionCard(
                          contravention: c,
                          selectable: !c.isRegle,
                          selectionMode: _selectionMode,
                          selected:
                              c.id != null && _selectedIds.contains(c.id),
                          onSelectChanged: c.id == null
                              ? null
                              : (v) => _toggleSelect(c.id!, v),
                          onEnterSelection: c.id == null
                              ? null
                              : () => _enterSelection(c.id!),
                          onEdit: () async {
                            final changed = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ContraventionDetailPage(contravention: c),
                              ),
                            );
                            if (mounted && changed == true) _refresh();
                          },
                        );
                      },
                    ),
                  );

    final hasSelection = selected.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      body: Column(
        children: [
          if (_selectionMode && items.isNotEmpty)
            _ListToolbar(
              count: items.length,
              allSelected: allSelected,
              onToggleAll: () => _toggleSelectAll(selectables),
            ),
          Expanded(
            child: Stack(
              children: [
                body,
                if (_paying)
                  _PayingOverlay(done: _payDone, total: _payTotal),
              ],
            ),
          ),
          // Barre de paiement intégrée au flux (et non en bottomNavigationBar) :
          // cette page est un Scaffold imbriqué dans le hub ; un
          // bottomNavigationBar y écrase la liste jusqu'à la faire disparaître.
          // Placée sous l'Expanded, la barre reste toujours sous la liste.
          if (hasSelection)
            _SelectionActionBar(
              count: selected.length,
              total: selTotal,
              busy: _paying,
              onPay: () => _payerSelection(selected),
            ),
        ],
      ),
      floatingActionButton: (widget.embedded || hasSelection)
          ? null
          : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FloatingActionButton.extended(
                    heroTag: 'importPdf',
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ContraventionImportPage()),
                      );
                      if (mounted) _refresh();
                    },
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Importer PDF'),
                  ),
                  const SizedBox(height: 12),
                  FloatingActionButton.extended(
                    heroTag: 'ajouterContravention',
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ContraventionFormPage()),
                      );
                      if (mounted) _refresh();
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Ajouter'),
                  ),
                ],
              ),
    );
  }
}

/// Barre d'outils de la liste : compteur + bouton « Tout sélectionner » qui
/// sélectionne toutes les lignes payables ; une fois tout sélectionné, il
/// devient « Annuler » et vide la sélection. La sélection d'une ligne se fait
/// en tapant directement dessus (pas de case à cocher).
class _ListToolbar extends StatelessWidget {
  final int count;
  final bool allSelected;
  final VoidCallback onToggleAll;

  const _ListToolbar({
    required this.count,
    required this.allSelected,
    required this.onToggleAll,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
      child: Row(
        children: [
          Text('$count contravention(s)',
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.label)),
          const Spacer(),
          TextButton.icon(
            onPressed: onToggleAll,
            icon: Icon(
                allSelected ? Icons.close_rounded : Icons.done_all_rounded,
                size: 18),
            label: Text(allSelected ? 'Annuler' : 'Tout sélectionner'),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

/// Barre d'action basse : total du reste à payer + bouton « Payer ».
class _SelectionActionBar extends StatelessWidget {
  final int count;
  final double total;
  final bool busy;
  final VoidCallback onPay;

  const _SelectionActionBar({
    required this.count,
    required this.total,
    required this.busy,
    required this.onPay,
  });

  @override
  Widget build(BuildContext context) {
    final actif = count > 0 && !busy;
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total à reverser',
                      style:
                          TextStyle(fontSize: 11.5, color: AppColors.label)),
                  const SizedBox(height: 2),
                  Text('${_money.format(total)} XOF',
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.dark)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: actif ? onPay : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.account_balance_outlined, size: 18),
              label: Text('Reverser${count > 0 ? ' ($count)' : ''}'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Overlay modal pendant le paiement en lot, avec progression k/n.
class _PayingOverlay extends StatelessWidget {
  final int done;
  final int total;
  const _PayingOverlay({required this.done, required this.total});

  @override
  Widget build(BuildContext context) {
    final value = total == 0 ? null : done / total;
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.35),
        child: Center(
          child: Container(
            width: 240,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 46,
                  height: 46,
                  child: CircularProgressIndicator(
                    value: value,
                    strokeWidth: 4,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 18),
                const Text('Reversement en cours…',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.dark)),
                const SizedBox(height: 4),
                Text('$done / $total',
                    style:
                        const TextStyle(fontSize: 13, color: AppColors.label)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final VoidCallback onRetry;
  const _EmptyView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
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
        ),
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
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
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
        ),
      ),
    );
  }
}

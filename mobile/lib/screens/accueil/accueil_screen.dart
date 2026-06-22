import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:vtc_manager/features/cotisation/presentation/pages/lignes_cotisation_page.dart';
import 'package:vtc_manager/features/maintenance/presentation/pages/lignes_maintenance_page.dart';
import 'package:vtc_manager/features/penalite/presentation/pages/lignes_penalite_page.dart';

import '../../features/condition_travail/presentation/pages/condition_travail_liste_page.dart';
import '../../features/operation_financiere/domain/entities/operation_financiere.dart';
import '../../features/operation_financiere/domain/enums/type_operation.dart';
import '../../features/operation_financiere/presentation/pages/operation_financiere_form_page.dart';
import '../../features/operation_financiere/presentation/pages/operations_financieres_page.dart';
import 'widgets/encaissement_rapide_dialog.dart';
import '../../features/operation_financiere/presentation/providers/operation_financiere_provider.dart';
import '../../features/operation_financiere/presentation/providers/operation_financiere_state.dart';
import '../../features/recette/presentation/pages/lignes_recette_page.dart';
import '../fleet/fleet_action_selector_page.dart';
import 'configurer_page.dart';
import 'indisponibilite_page.dart';
import '../../core/widgets/date_filter_dialogs.dart';

class AccueilScreen extends ConsumerWidget {
  const AccueilScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final money = NumberFormat.currency(
        locale: 'fr_FR', symbol: 'XOF', decimalDigits: 0);

    final opState = ref.watch(operationFinanciereNotifierProvider);
    final allOps = switch (opState) {
      OperationFinanciereLoaded(:final operations) => operations,
      OperationFinanciereActionSuccess(:final operations) => operations,
      _ => <OperationFinanciere>[],
    };

    // 10 dernières opérations (toutes périodes)
    final dernieres = (List<OperationFinanciere>.from(allOps)
          ..sort((a, b) => b.dateOperation.compareTo(a.dateOperation)))
        .take(10)
        .toList();

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(operationFinanciereNotifierProvider.notifier).loadAll(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
        children: [
          // ── Carte solde ─────────────────────────────────────────────────
          _SoldeCard(
            allOps: allOps,
            money: money,
          ),
          const SizedBox(height: 24),

          // ── Accès rapides ────────────────────────────────────────────────
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 4,
            crossAxisSpacing: 0,
            childAspectRatio: 0.75,
            children: [
              _ShortcutItem(
                icon: Icons.directions_car_outlined,
                label: 'Veh/Chauf',
                onTap: () => _push(context, const FleetActionSelectorPage()),
              ),
              _ShortcutItem(
                icon: Icons.badge_outlined,
                label: 'Penalites',
                onTap: () => _push(context, const LignesPenalitePage()),
              ),
              _ShortcutItem(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Recettes',
                onTap: () => _push(context, const LignesRecettePage()),
              ),
              _ShortcutItem(
                icon: Icons.build_circle_outlined,
                label: 'Maintenance',
                onTap: () => _push(context, const LignesMaintenancePage()),
              ),
              _ShortcutItem(
                icon: Icons.analytics_outlined,
                label: 'Cotisations',
                onTap: () => _push(context, const LignesCotisationPage()),
              ),
              _ShortcutItem(
                icon: Icons.assignment_outlined,
                label: 'Contrats',
                onTap: () => _push(context, const ConditionTravailListePage()),
              ),
              _ShortcutItem(
                icon: Icons.event_busy_outlined,
                label: 'Indisponibilités',
                onTap: () => _push(context, const IndisponibilitePage()),
              ),
              _ShortcutItem(
                icon: Icons.add_card_outlined,
                label: 'Opération',
                onTap: () =>
                    _push(context, const OperationFinanciereFormPage()),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Divider(color: Colors.grey.shade300, thickness: 3, height: 3),
          const SizedBox(height: 10),

          // ── Dernières opérations ────────────────────────────────────────
          if (dernieres.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const _SectionTitle(title: 'Dernières opérations'),
                TextButton(
                  onPressed: () =>
                      _push(context, const OperationsFinancieresPage()),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey.shade600,
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Voir plus'),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward, size: 14),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...dernieres.map((op) => _DerniereOpTile(op: op, money: money)),
          ] else if (opState is OperationFinanciereLoading) ...[
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }
}

// ── Helpers carte solde ───────────────────────────────────────────────────────

enum _CardFiltre { mois, semaine }

// ── Carte solde (toujours ouverte) ────────────────────────────────────────────

class _SoldeCard extends StatefulWidget {
  final List<OperationFinanciere> allOps;
  final NumberFormat money;

  const _SoldeCard({
    required this.allOps,
    required this.money,
  });

  @override
  State<_SoldeCard> createState() => _SoldeCardState();
}

class _SoldeCardState extends State<_SoldeCard> {
  bool _visible = false;
  _CardFiltre _filtre = _CardFiltre.semaine;
  int _moisSelectionne = DateTime.now().month;
  int _anneeSelectionnee = DateTime.now().year;
  DateTime _semaineDebut = mondayOf(DateTime.now());
  final GlobalKey _filtreKey = GlobalKey();
  OverlayEntry? _overlayEntry;

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  // ── Calcul des totaux selon le filtre actif ────────────────────────────────

  Iterable<OperationFinanciere> _filtreOps() {
    if (_filtre == _CardFiltre.mois) {
      return widget.allOps.where((o) =>
          o.dateOperation.year == _anneeSelectionnee &&
          o.dateOperation.month == _moisSelectionne);
    }
    final weekEnd = _semaineDebut.add(const Duration(days: 6));
    return widget.allOps.where((o) {
      final d = DateTime(
          o.dateOperation.year, o.dateOperation.month, o.dateOperation.day);
      return !d.isBefore(_semaineDebut) && !d.isAfter(weekEnd);
    });
  }

  // ── Label de la pill date ─────────────────────────────────────────────────

  String get _datePillLabel {
    if (_filtre == _CardFiltre.mois) {
      return '${kMoisNoms[_moisSelectionne - 1]} $_anneeSelectionnee';
    }
    final weekEnd = _semaineDebut.add(const Duration(days: 6));
    return '${DateFormat('dd/MM').format(_semaineDebut)} – '
        '${DateFormat('dd/MM').format(weekEnd)}';
  }

  IconData get _datePillIcon => _filtre == _CardFiltre.mois
      ? Icons.calendar_month_outlined
      : Icons.date_range_outlined;

  // ── Pickers de date (dialogs partagés — même rendu que LignesRecettePage) ──

  Future<void> _pickDate() async {
    if (_filtre == _CardFiltre.mois) {
      await _pickMois();
    } else {
      await _pickSemaine();
    }
  }

  Future<void> _pickMois() async {
    final result = await showDialog<DateTime>(
      context: context,
      builder: (_) => MonthPickerDialog(
        initialYear: _anneeSelectionnee,
        initialMonth: _moisSelectionne,
      ),
    );
    if (result != null) {
      setState(() {
        _moisSelectionne = result.month;
        _anneeSelectionnee = result.year;
      });
    }
  }

  Future<void> _pickSemaine() async {
    final result = await showDialog<DateTime>(
      context: context,
      builder: (_) => WeekPickerDialog(initialWeekStart: _semaineDebut),
    );
    if (result != null) {
      setState(() => _semaineDebut = result);
    }
  }

  // ── Dropdown filtre (style identique à LignesRecettePage) ─────────────────

  void _showFiltreOverlay() {
    _removeOverlay();
    final renderBox =
        _filtreKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (ctx) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _removeOverlay,
        child: Stack(
          children: [
            Positioned(
              left: offset.dx,
              top: offset.dy + size.height + 4,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 150,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: _CardFiltre.values.map((mode) {
                      final label =
                          mode == _CardFiltre.mois ? 'Mois' : 'Semaine';
                      final sel = _filtre == mode;
                      return InkWell(
                        onTap: () {
                          setState(() => _filtre = mode);
                          _removeOverlay();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Icon(
                                sel
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_off_outlined,
                                size: 18,
                                color: sel
                                    ? const Color(0xFF1A5276)
                                    : Colors.grey.shade400,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                label,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: sel
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: sel
                                      ? const Color(0xFF1A5276)
                                      : const Color(0xFF1A1A1A),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    final ops = _filtreOps();
    final totalRev = ops
        .where((o) => o.typeOperation == TypeOperation.REVENU)
        .fold<double>(0, (s, o) => s + o.montant);
    final totalDep = ops
        .where((o) => o.typeOperation == TypeOperation.DEPENSE)
        .fold<double>(0, (s, o) => s + o.montant);
    final solde = totalRev - totalDep;
    final filtreLabel = _filtre == _CardFiltre.mois ? 'Mois' : 'Semaine';

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFBDBDBD), Color(0xFFEEEEEE), Color(0xFF9E9E9E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.all(1.5),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16.5),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Ligne 1 : pill filtre + pill valeur de période ────────────
            Row(
              children: [
                // Pill type (Mois / Semaine)
                GestureDetector(
                  key: _filtreKey,
                  onTap: _showFiltreOverlay,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.filter_list_rounded,
                            size: 14, color: Color(0xFF1A5276)),
                        const SizedBox(width: 5),
                        Text(
                          filtreLabel,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF1A5276),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 3),
                        const Icon(Icons.keyboard_arrow_down_rounded,
                            size: 14, color: Color(0xFF1A5276)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Pill valeur date (expanded)
                Expanded(
                  child: GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(_datePillIcon,
                              size: 13,
                              color: Colors.grey.shade600),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _datePillLabel,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Icon(Icons.keyboard_arrow_down_rounded,
                              size: 14,
                              color: Colors.grey.shade600),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // ── Ligne 2 : montant (gauche) | Encaisser (droite) — symétriques ─
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Moitié gauche : montant + œil
                Expanded(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _visible
                                ? widget.money.format(solde)
                                : '••••••',
                            style: const TextStyle(
                              color: Color(0xFF1A1A1A),
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () =>
                            setState(() => _visible = !_visible),
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          child: Icon(
                            _visible
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: Colors.grey.shade500,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Moitié droite : bouton Encaisser, aligné à droite
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: () =>
                          showEncaissementRapideDialog(context),
                      icon: const Icon(Icons.add, size: 14),
                      label: const Text('Encaisser'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        textStyle: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // ── Ligne 3 : Revenus | Dépenses ─────────────────────────────
            const SizedBox(height: 16),
            Divider(color: Colors.grey.shade200, height: 1),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _CardStat(
                    icon: Icons.arrow_downward,
                    label: 'Revenus',
                    value: _visible
                        ? widget.money.format(totalRev)
                        : '••••',
                    color: Colors.green.shade600,
                  ),
                ),
                Container(
                    width: 1, height: 36, color: Colors.grey.shade200),
                Expanded(
                  child: _CardStat(
                    icon: Icons.arrow_upward,
                    label: 'Dépenses',
                    value: _visible
                        ? widget.money.format(totalDep)
                        : '••••',
                    color: Colors.red.shade400,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CardStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _CardStat(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                      color: Colors.grey.shade600, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Color(0xFF1A1A1A),
                fontWeight: FontWeight.bold,
                fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ── Navigation helper ─────────────────────────────────────────────────────

void _push(BuildContext context, Widget page) {
  Navigator.of(context).push(
    PageRouteBuilder(
      pageBuilder: (_, a, __) => page,
      transitionsBuilder: (_, a, __, child) => SlideTransition(
        position: Tween(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeInOut)).animate(a),
        child: child,
      ),
      transitionDuration: const Duration(milliseconds: 280),
    ),
  );
}

// ── Raccourci icône ───────────────────────────────────────────────────────

class _ShortcutItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ShortcutItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: Color(0xFFF0F0F0),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: const Color(0xFF2E7D32), size: 22),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section title ──────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
    );
  }
}

// ── Dernières opération ───────────────────────────────────────────────

class _DerniereOpTile extends StatelessWidget {
  final OperationFinanciere op;
  final NumberFormat money;
  const _DerniereOpTile({required this.op, required this.money});

  @override
  Widget build(BuildContext context) {
    final isRevenu = op.typeOperation == TypeOperation.REVENU;
    final color = isRevenu ? Colors.green : Colors.red;
    final sign = isRevenu ? '+' : '-';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isRevenu
                  ? Icons.trending_up_rounded
                  : Icons.trending_down_rounded,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  op.categorieLibelle ?? op.typeOperation.libelle,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (op.chauffeurNom != null || op.sousCategorieLibelle != null)
                  Text(
                    [
                      if (op.sousCategorieLibelle != null)
                        op.sousCategorieLibelle!,
                      if (op.chauffeurNom != null) op.chauffeurNom!,
                    ].join(' · '),
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$sign${money.format(op.montant)}',
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 13),
              ),
              Text(
                DateFormat('dd/MM', 'fr_FR').format(op.dateOperation),
                style:
                    TextStyle(fontSize: 10, color: Colors.grey.shade400),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

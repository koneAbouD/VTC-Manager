import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:vtc_manager/features/cotisation/presentation/pages/lignes_cotisation_page.dart';
import 'package:vtc_manager/features/maintenance/presentation/pages/lignes_maintenance_page.dart';
import 'package:vtc_manager/features/penalite/presentation/pages/lignes_penalite_page.dart';

import '../../features/condition_travail/presentation/pages/condition_travail_liste_page.dart';
import '../../features/operation_financiere/domain/entities/operation_financiere.dart';
import '../../features/operation_financiere/domain/enums/type_operation.dart';
import '../../features/operation_financiere/presentation/pages/operation_financiere_detail_page.dart';
import '../../features/operation_financiere/presentation/pages/operation_financiere_form_page.dart';
import '../../features/operation_financiere/presentation/pages/operations_financieres_page.dart';
import 'widgets/encaissement_rapide_dialog.dart';
import '../../features/operation_financiere/presentation/providers/operation_financiere_provider.dart';
import '../../features/operation_financiere/presentation/providers/operation_financiere_state.dart';
import '../../features/recette/presentation/pages/lignes_recette_page.dart';
import '../fleet/fleet_action_selector_page.dart';
import '../../features/indisponibilite/presentation/pages/indisponibilites_page.dart';
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
          const _AccesRapides(),
          const SizedBox(height: 18),

          // ── Dernières opérations ────────────────────────────────────────
          if (dernieres.isNotEmpty) ...[
            ...dernieres.map((op) => _DerniereOpTile(
                  op: op,
                  money: money,
                  onTap: () => _push(
                    context,
                    OperationFinanciereDetailPage(operation: op),
                  ),
                )),
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                onPressed: () async {
                  await _push(context, const OperationsFinancieresPage());
                  // OperationsFinancieresPage filtre la liste partagée par date ;
                  // au retour, on restaure les opérations toutes périodes pour
                  // l'accueil (qui affiche les 10 plus récentes).
                  ref
                      .read(operationFinanciereNotifierProvider.notifier)
                      .loadAll();
                },
                icon: const Icon(Icons.unfold_more_rounded, size: 16),
                label: const Text("Plus d'opérations"),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF2E7D32),
                  backgroundColor: const Color(0xFFE8F5E9),
                  textStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
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
                                    ? const Color(0xFF43A047)
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
                                      ? const Color(0xFF43A047)
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
                            size: 14, color: Color(0xFF43A047)),
                        const SizedBox(width: 5),
                        Text(
                          filtreLabel,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF43A047),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 3),
                        const Icon(Icons.keyboard_arrow_down_rounded,
                            size: 14, color: Color(0xFF43A047)),
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

Future<T?> _push<T>(BuildContext context, Widget page) {
  return Navigator.of(context).push<T>(
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

// ── Grille des accès rapides (responsive) ─────────────────────────────────

class _AccesRapides extends StatelessWidget {
  const _AccesRapides();

  @override
  Widget build(BuildContext context) {
    final shortcuts = <({IconData icon, String label, VoidCallback onTap})>[
      (
        icon: Icons.directions_car_outlined,
        label: 'Veh/Chauf',
        onTap: () => _push(context, const FleetActionSelectorPage()),
      ),
      (
        icon: Icons.badge_outlined,
        label: 'Penalites',
        onTap: () => _push(context, const LignesPenalitePage()),
      ),
      (
        icon: Icons.account_balance_wallet_outlined,
        label: 'Recettes',
        onTap: () => _push(context, const LignesRecettePage()),
      ),
      (
        icon: Icons.build_circle_outlined,
        label: 'Maintenance',
        onTap: () => _push(context, const LignesMaintenancePage()),
      ),
      (
        icon: Icons.analytics_outlined,
        label: 'Cotisations',
        onTap: () => _push(context, const LignesCotisationPage()),
      ),
      (
        icon: Icons.assignment_outlined,
        label: 'Contrats',
        onTap: () => _push(context, const ConditionTravailListePage()),
      ),
      (
        icon: Icons.event_busy_outlined,
        label: 'Indisponibilités',
        onTap: () => _push(context, const IndisponibilitesPage()),
      ),
      (
        icon: Icons.add_card_outlined,
        label: 'Opération',
        onTap: () => _push(context, const OperationFinanciereFormPage()),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        // Téléphone : 4 colonnes (2 rangées) · Tablette : tout sur une rangée.
        final cols = w >= 600 ? shortcuts.length : 4;
        final bool isTablet = w >= 600;
        final double circle = isTablet ? 56 : 48;
        final double iconSize = isTablet ? 28 : 24;
        // Hauteur fixe d'une cellule = pastille + libellé + espacements.
        final double extent = circle + 32;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: shortcuts.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisExtent: extent,
            mainAxisSpacing: 14,
            crossAxisSpacing: 8,
          ),
          itemBuilder: (_, i) {
            final s = shortcuts[i];
            return _ShortcutItem(
              icon: s.icon,
              label: s.label,
              onTap: s.onTap,
              circleSize: circle,
              iconSize: iconSize,
            );
          },
        );
      },
    );
  }
}

// ── Raccourci icône ───────────────────────────────────────────────────────

class _ShortcutItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final double circleSize;
  final double iconSize;
  const _ShortcutItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.circleSize = 48,
    this.iconSize = 24,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: circleSize,
            height: circleSize,
            decoration: const BoxDecoration(
              color: Color(0xFFF0F0F0),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFF2E7D32), size: iconSize),
          ),
          const SizedBox(height: 6),
          Flexible(
            child: Text(
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
          ),
        ],
      ),
    );
  }
}

// ── Dernières opération ───────────────────────────────────────────────

class _DerniereOpTile extends StatelessWidget {
  final OperationFinanciere op;
  final NumberFormat money;
  final VoidCallback onTap;
  const _DerniereOpTile(
      {required this.op, required this.money, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isRevenu = op.typeOperation == TypeOperation.REVENU;
    final color = isRevenu ? Colors.green : Colors.red;
    final sign = isRevenu ? '+' : '-';

    // Ligne 1 : « [Catégorie opération] du [date] »
    final categorie = op.categorieLibelle ?? op.typeOperation.libelle;
    final titre =
        '$categorie du ${DateFormat('dd/MM/yyyy', 'fr_FR').format(op.dateOperation)}';

    // Ligne 2 : « [imat véhicule - Nom chauffeur] »
    final vehiculeChauffeur = [
      if (op.vehiculeNom != null) op.vehiculeNom!,
      if (op.chauffeurNom != null) op.chauffeurNom!,
    ].join(' - ');

    return GestureDetector(
      onTap: onTap,
      child: Container(
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
                // ── Ligne 1 : catégorie + date · montant ──────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        titre,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$sign${money.format(op.montant)}',
                      style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                // ── Ligne 2 : véhicule - chauffeur · date ─────────────────
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        vehiculeChauffeur,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('dd/MM', 'fr_FR').format(op.dateOperation),
                      style: TextStyle(
                          fontSize: 10, color: Colors.grey.shade400),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}

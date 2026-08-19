import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:vtc_manager/features/cotisation/presentation/pages/lignes_cotisation_page.dart';
import 'package:vtc_manager/features/maintenance/presentation/pages/lignes_maintenance_page.dart';
import 'package:vtc_manager/features/contravention/presentation/pages/contraventions_hub_page.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/extourne_badge.dart';
import '../../features/operation_financiere/domain/entities/operation_financiere.dart';
import '../../features/operation_financiere/domain/entities/solde_periode.dart';
import '../../features/operation_financiere/domain/enums/statut_operation.dart';
import '../../features/operation_financiere/domain/enums/type_operation.dart';
import '../../features/operation_financiere/presentation/pages/operation_financiere_detail_page.dart';
import '../../features/operation_financiere/presentation/pages/operation_financiere_form_page.dart';
import 'widgets/encaissement_rapide_dialog.dart';
import '../../features/operation_financiere/presentation/providers/operation_financiere_provider.dart';
import '../../features/operation_financiere/presentation/providers/operation_financiere_state.dart';
import '../../features/recette/presentation/pages/lignes_recette_page.dart';
import '../home_nav_provider.dart';
import '../../features/indisponibilite/presentation/pages/indisponibilites_page.dart';
import '../../core/widgets/date_filter_dialogs.dart';

class AccueilScreen extends ConsumerStatefulWidget {
  const AccueilScreen({super.key});

  @override
  ConsumerState<AccueilScreen> createState() => _AccueilScreenState();
}

class _AccueilScreenState extends ConsumerState<AccueilScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _listeKey = GlobalKey();
  final GlobalKey _ligneSoldeKey = GlobalKey();

  /// Offset de scroll à partir duquel la ligne « montant + Encaisser » de la
  /// carte solde est entièrement passée sous l'en-tête. Mesuré tant que la
  /// ligne est montée, et conservé ensuite : la liste recycle ce qui sort du
  /// viewport, la mesure n'est donc plus possible une fois la ligne loin
  /// au-dessus.
  double? _seuilMasquage;

  /// Évite d'empiler plusieurs mesures sur un même frame (le scroll notifie
  /// bien plus souvent qu'il n'y a d'images à l'écran).
  bool _mesurePlanifiee = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_planifierMesure);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Reporte la mesure après le rendu : pendant le scroll, les positions des
  /// RenderBox datent encore du frame précédent alors que l'offset, lui, est
  /// déjà à jour — les comparer donnerait un seuil faux d'une image.
  void _planifierMesure() {
    if (_mesurePlanifiee) return;
    _mesurePlanifiee = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mesurePlanifiee = false;
      if (mounted) _mesurerEtAppliquer();
    });
  }

  void _mesurerEtAppliquer() {
    final offset = _scrollController.hasClients ? _scrollController.offset : 0.0;

    final ligne =
        _ligneSoldeKey.currentContext?.findRenderObject() as RenderBox?;
    final liste = _listeKey.currentContext?.findRenderObject() as RenderBox?;
    if (ligne != null &&
        ligne.hasSize &&
        ligne.attached &&
        liste != null &&
        liste.hasSize) {
      final basLigne = ligne.localToGlobal(Offset.zero).dy + ligne.size.height;
      final hautListe = liste.localToGlobal(Offset.zero).dy;
      _seuilMasquage = offset + basLigne - hautListe;
    }

    final masque = _seuilMasquage != null && offset >= _seuilMasquage!;
    if (ref.read(soldeHorsEcranProvider) != masque) {
      ref.read(soldeHorsEcranProvider.notifier).state = masque;
    }
  }

  @override
  Widget build(BuildContext context) {
    // La carte solde change de hauteur au fil des chargements (montants, filtre
    // de période) : on re-mesure à chaque rendu plutôt qu'une seule fois.
    _planifierMesure();

    final money = NumberFormat.currency(
        locale: 'fr_FR', symbol: 'XOF', decimalDigits: 0);

    final opState = ref.watch(operationFinanciereNotifierProvider);
    final allOps = switch (opState) {
      OperationFinanciereLoaded(:final operations) => operations,
      OperationFinanciereActionSuccess(:final operations) => operations,
      _ => <OperationFinanciere>[],
    };

    // 10 dernières opérations (toutes périodes).
    // Tri sur la date d'enregistrement (dateOperation) puis, à date égale, sur
    // l'id décroissant (= ordre de création) : sans ce départage, toutes les
    // opérations d'un même jour sont à égalité et le tri non stable de Dart peut
    // éjecter du top 10 une opération pourtant récente (ex. une dépense saisie
    // le matin, noyée parmi les encaissements du jour).
    final dernieres = (List<OperationFinanciere>.from(allOps)
          ..sort((a, b) {
            final parDate = b.dateOperation.compareTo(a.dateOperation);
            if (parDate != 0) return parDate;
            return (b.id ?? 0).compareTo(a.id ?? 0);
          }))
        .take(10)
        .toList();

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(operationFinanciereNotifierProvider.notifier).loadAll(),
      child: ListView(
        key: _listeKey,
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 80),
        children: [
          // ── Carte solde ─────────────────────────────────────────────────
          _SoldeCard(
            money: money,
            ligneSoldeKey: _ligneSoldeKey,
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
                onPressed: () {
                  // Redirige vers le hub Finances (index 3) sur le sous-onglet
                  // Opérations, au lieu d'ouvrir une page séparée.
                  ref.read(financeTabIndexProvider.notifier).state =
                      FinanceTab.operations;
                  ref.read(homeTabIndexProvider.notifier).state = 3;
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

// ── Relais de la carte solde dans l'en-tête ───────────────────────────────────

/// Largeur à partir de laquelle l'en-tête a la place d'accueillir le montant du
/// solde en plus du menu et du bouton « Encaisser ». Même seuil que la grille
/// des accès rapides.
const double _seuilTablette = 600;

/// Montant du solde quand l'œil est fermé. Partagé par la carte et l'en-tête :
/// chacun applique le masque de son côté (voir [soldeAccueilTexteProvider]).
const String _soldeMasque = '••••••';

/// Solde repris dans l'en-tête (HomeScreen) quand la carte est sortie de
/// l'écran, avec son œil de masquage. Réservé aux grands écrans : sur
/// téléphone, la barre est déjà prise par le menu et le bouton « Encaisser ».
class SoldeHeaderLabel extends ConsumerWidget {
  const SoldeHeaderLabel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final large = MediaQuery.sizeOf(context).width >= _seuilTablette;
    final visible = large && ref.watch(soldeHorsEcranProvider);
    // Le provider ne porte que le montant en clair : la carte qui l'alimente
    // est démontée dès qu'elle sort de l'écran et ne republie donc plus rien.
    // C'est ici, et pas à la source, que l'œil doit masquer le montant, sinon
    // il ne changerait plus que d'icône une fois la carte hors écran.
    final texteClair = ref.watch(soldeAccueilTexteProvider);
    final soldeVisible = ref.watch(soldeVisibleProvider);
    final texte = soldeVisible ? texteClair : _soldeMasque;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(scale: animation, child: child),
      ),
      child: visible && texteClair.isNotEmpty
          ? Row(
              key: const ValueKey('solde'),
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: AnimatedSwitcher(
                    // Second fondu, sur la valeur seule : le montant se
                    // remplace quand la période change ou qu'on rouvre l'œil,
                    // sans faire clignoter l'œil posé à côté.
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      texte,
                      key: ValueKey(texte),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      // Gabarit du titre d'en-tête (AppHeader).
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.dark,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => ref.read(soldeVisibleProvider.notifier).state =
                      !soldeVisible,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Icon(
                      soldeVisible
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: Colors.grey.shade500,
                      size: 18,
                    ),
                  ),
                ),
              ],
            )
          : const SizedBox(key: ValueKey('vide')),
    );
  }
}

/// Bouton « Encaisser » de l'en-tête (HomeScreen) : n'apparaît que lorsque
/// celui de la carte solde est sorti de l'écran par le haut, pour garder
/// l'encaissement rapide à portée quel que soit le scroll.
class EncaisserHeaderButton extends ConsumerWidget {
  const EncaisserHeaderButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visible = ref.watch(soldeHorsEcranProvider);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(scale: animation, child: child),
      ),
      child: visible
          ? GestureDetector(
              key: const ValueKey('encaisser'),
              onTap: () => showEncaissementRapideDialog(context),
              child: Container(
                // Même gabarit que les boutons d'en-tête (AppHeaderAction),
                // en vert : c'est la même action que sur la carte.
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.green.shade600,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 16, color: Colors.white),
                    SizedBox(width: 6),
                    Text(
                      'Encaisser',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : const SizedBox(key: ValueKey('vide'), height: 38),
    );
  }
}

// ── Helpers carte solde ───────────────────────────────────────────────────────

enum _CardFiltre { mois, semaine, jour }

String _cardFiltreLabel(_CardFiltre m) => switch (m) {
      _CardFiltre.mois => 'Mois',
      _CardFiltre.semaine => 'Semaine',
      _CardFiltre.jour => 'Jour',
    };

// ── Carte solde (toujours ouverte) ────────────────────────────────────────────

class _SoldeCard extends ConsumerStatefulWidget {
  final NumberFormat money;

  /// Clé posée sur la ligne « montant + Encaisser » : sert à l'Accueil pour
  /// savoir à quel offset de scroll elle quitte l'écran.
  final Key ligneSoldeKey;

  const _SoldeCard({
    required this.money,
    required this.ligneSoldeKey,
  });

  @override
  ConsumerState<_SoldeCard> createState() => _SoldeCardState();
}

class _SoldeCardState extends ConsumerState<_SoldeCard> {
  _CardFiltre _filtre = _CardFiltre.semaine;
  int _moisSelectionne = DateTime.now().month;
  int _anneeSelectionnee = DateTime.now().year;
  DateTime _semaineDebut = mondayOf(DateTime.now());
  DateTime _jourSelectionne = DateTime.now();
  final GlobalKey _filtreKey = GlobalKey();
  OverlayEntry? _overlayEntry;

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  // ── Plage [debut, fin] envoyée au backend selon le filtre actif ────────────

  ({String debut, String fin}) _plageActive() {
    final fmt = DateFormat('yyyy-MM-dd');
    switch (_filtre) {
      case _CardFiltre.jour:
        final j = fmt.format(_jourSelectionne);
        return (debut: j, fin: j);
      case _CardFiltre.semaine:
        return (
          debut: fmt.format(_semaineDebut),
          fin: fmt.format(_semaineDebut.add(const Duration(days: 6))),
        );
      case _CardFiltre.mois:
        final premier = DateTime(_anneeSelectionnee, _moisSelectionne, 1);
        final dernier = DateTime(_anneeSelectionnee, _moisSelectionne + 1, 0);
        return (debut: fmt.format(premier), fin: fmt.format(dernier));
    }
  }

  // ── Label de la pill date ─────────────────────────────────────────────────

  String get _datePillLabel {
    if (_filtre == _CardFiltre.mois) {
      return '${kMoisNoms[_moisSelectionne - 1]} $_anneeSelectionnee';
    }
    if (_filtre == _CardFiltre.jour) {
      return DateFormat('dd/MM/yyyy').format(_jourSelectionne);
    }
    final weekEnd = _semaineDebut.add(const Duration(days: 6));
    return '${DateFormat('dd/MM').format(_semaineDebut)} – '
        '${DateFormat('dd/MM').format(weekEnd)}';
  }

  IconData get _datePillIcon => switch (_filtre) {
        _CardFiltre.mois => Icons.calendar_month_outlined,
        _CardFiltre.jour => Icons.today_outlined,
        _CardFiltre.semaine => Icons.date_range_outlined,
      };

  // ── Pickers de date (dialogs partagés — même rendu que LignesRecettePage) ──

  Future<void> _pickDate() async {
    switch (_filtre) {
      case _CardFiltre.mois:
        await _pickMois();
      case _CardFiltre.jour:
        await _pickJour();
      case _CardFiltre.semaine:
        await _pickSemaine();
    }
  }

  Future<void> _pickJour() async {
    final result = await showDialog<DateTime>(
      context: context,
      builder: (_) => SingleDatePickerDialog(initialDate: _jourSelectionne),
    );
    if (result != null) {
      setState(() => _jourSelectionne = result);
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
                      final label = _cardFiltreLabel(mode);
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
    final plage = _plageActive();
    final soldeAsync = ref.watch(
        soldePeriodeProvider((debut: plage.debut, fin: plage.fin)));
    final totaux = soldeAsync.valueOrNull ?? SoldePeriode.zero;
    final totalRev = totaux.revenus;
    final totalDep = totaux.depenses;
    final solde = totaux.solde;
    // Vrai tant qu'on charge sans valeur en cache (1er affichage d'une période).
    final chargementInitial =
        soldeAsync.isLoading && soldeAsync.valueOrNull == null;
    final filtreLabel = _cardFiltreLabel(_filtre);
    // Œil partagé avec l'en-tête, qui reprend le solde et son bouton de
    // masquage quand la carte sort de l'écran.
    final soldeVisible = ref.watch(soldeVisibleProvider);

    // Rendu d'un montant : masqué (œil fermé), « … » pendant le 1er chargement,
    // sinon la valeur formatée.
    String afficher(double v, String masque) {
      if (!soldeVisible) return masque;
      if (chargementInitial) return '…';
      return widget.money.format(v);
    }

    // Le solde est republié pour l'en-tête (après le rendu : on ne touche pas à
    // un provider pendant un build), toujours en clair — l'en-tête applique
    // lui-même le masque de l'œil, puisque la carte ne republie plus rien une
    // fois recyclée par la liste.
    final texteSoldeClair = chargementInitial ? '…' : widget.money.format(solde);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ref.read(soldeAccueilTexteProvider) != texteSoldeClair) {
        ref.read(soldeAccueilTexteProvider.notifier).state = texteSoldeClair;
      }
    });

    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.cardBorderGradient,
        borderRadius: BorderRadius.circular(AppColors.cardRadius),
      ),
      padding: const EdgeInsets.all(1.5),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardTint,
          borderRadius: BorderRadius.circular(AppColors.cardInnerRadius),
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
              key: widget.ligneSoldeKey,
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
                            afficher(solde, _soldeMasque),
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
                        onTap: () => ref
                            .read(soldeVisibleProvider.notifier)
                            .state = !soldeVisible,
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          child: Icon(
                            soldeVisible
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
                    value: afficher(totalRev, '••••'),
                    color: Colors.green.shade600,
                  ),
                ),
                Container(
                    width: 1, height: 36, color: Colors.grey.shade200),
                Expanded(
                  child: _CardStat(
                    icon: Icons.arrow_upward,
                    label: 'Dépenses',
                    value: afficher(totalDep, '••••'),
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
        icon: Icons.gavel_outlined,
        label: 'Contraventions',
        onTap: () => _push(context, const ContraventionsHubPage()),
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
    // Signe, couleur et flèche suivent l'effet réel sur la caisse, pas le type
    // de l'écriture : une extourne garde le type de l'origine mais porte un
    // montant opposé, donc une dépense annulée fait rentrer de l'argent.
    final isRevenu = op.typeOperation == TypeOperation.REVENU;
    final effetCaisse = isRevenu ? op.montant : -op.montant;
    final entreEnCaisse = effetCaisse >= 0;
    final color = entreEnCaisse ? Colors.green : Colors.red;
    // Une sortie porte son signe ; une entrée s'en passe, sauf sur une extourne
    // où le « + » dit clairement que l'argent revient.
    final sign = entreEnCaisse ? (op.estUneExtourne ? '+' : '') : '-';
    // Trois états à distinguer, comme sur la liste des opérations : l'ancien
    // statut ANNULEE, une écriture contre-passée (barrée, elle reste au
    // journal) et la contre-passation elle-même (montant opposé).
    final isAnnulee = op.statut == StatutOperation.ANNULEE || op.estExtournee;
    final isExtourne = op.estUneExtourne;

    // Ligne 1 : « [Catégorie opération] [d'hier / du JJ/MM/AAAA] »
    // La date relative (recalculée à l'affichage) n'est ajoutée que pour les
    // encaissements ; les autres opérations (ex. Vidange) s'affichent sans date.
    final titre = op.libelleLigne;

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
              entreEnCaisse
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
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: isAnnulee ? Colors.red : null,
                            decoration: isAnnulee
                                ? TextDecoration.lineThrough
                                : null,
                            decorationColor: Colors.red),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    ExtourneBadge(
                        estUneExtourne: isExtourne, estAnnulee: isAnnulee),
                    const SizedBox(width: 8),
                    Text(
                      '$sign${money.format(effetCaisse.abs())}',
                      style: TextStyle(
                          // Montant en noir comme le libellé ; le sens de
                          // l'opération se lit sur la pastille d'icône et le
                          // signe.
                          color: isAnnulee ? Colors.red : null,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          decoration:
                              isAnnulee ? TextDecoration.lineThrough : null,
                          decorationColor: Colors.red),
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

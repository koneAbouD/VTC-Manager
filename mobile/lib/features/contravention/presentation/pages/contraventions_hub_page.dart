import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../penalite/presentation/pages/lignes_penalite_page.dart';
import '../../../penalite/presentation/providers/penalite_provider.dart';
import '../providers/contravention_provider.dart';
import 'contravention_form_page.dart';
import 'contravention_import_page.dart';
import 'reversement_import_page.dart';
import 'contraventions_page.dart';

/// Hub unifié « Contraventions » : coiffe les pénalités internes et les
/// contraventions d'État sous un même en-tête, avec un contrôle segmenté, un
/// bandeau KPI et une action contextuelle. Les corps de liste sont réutilisés
/// tels quels (mode `embedded`), toute leur logique est préservée.
class ContraventionsHubPage extends ConsumerStatefulWidget {
  /// 0 = Pénalités · 1 = Contraventions d'État (défaut).
  final int initialSegment;

  const ContraventionsHubPage({super.key, this.initialSegment = 1});

  @override
  ConsumerState<ContraventionsHubPage> createState() =>
      _ContraventionsHubPageState();
}

class _ContraventionsHubPageState extends ConsumerState<ContraventionsHubPage> {
  late int _segment = widget.initialSegment;
  bool _addOpen = false;

  // ── En-tête collapsable (KPI) ────────────────────────────────────────────
  // La recherche est désormais propre à chaque page (sous le filtre date, dans
  // la zone scrollable). Piloté par le défilement de la liste active :
  // `_collapse` = pixels repliés (0 = déployé, `_headerMax` = escamoté).
  final _headerKey = GlobalKey();
  double _headerMax = 72; // estimation, affinée après le premier layout
  double _collapse = 0;

  /// Mesure la hauteur réelle de l'en-tête après layout pour caler l'amplitude
  /// de repli sur son contenu exact.
  void _measureHeader() {
    final box = _headerKey.currentContext?.findRenderObject() as RenderBox?;
    final h = box?.size.height;
    if (h != null && h > 0 && (h - _headerMax).abs() > 0.5) {
      setState(() {
        _headerMax = h;
        if (_collapse > _headerMax) _collapse = _headerMax;
      });
    }
  }

  void _toggleAdd() => setState(() => _addOpen = !_addOpen);
  void _closeAdd() => setState(() => _addOpen = false);

  void _selectSegment(int index) {
    if (index == _segment) return;
    setState(() {
      _segment = index;
      _addOpen = false;
      _collapse = 0; // la nouvelle liste repart en haut → en-tête déployé
    });
  }

  static final _money =
      NumberFormat.currency(locale: 'fr_FR', symbol: 'XOF', decimalDigits: 0);

  bool get _isEtat => _segment == 1;

  // ── Actions contextuelles ──────────────────────────────────────────────

  Future<void> _generer() async {
    final result = await ref.read(penaliteRepositoryProvider).generer();
    final error = result.fold((f) => f.message, (_) => null);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(error ?? "Pénalités d'hier générées avec succès."),
      backgroundColor: error != null ? AppColors.error : null,
    ));
    if (error == null) {
      ref.read(lignesPenaliteListeProvider.notifier).refresh();
    }
  }

  Future<void> _importerPdf() async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => const ContraventionImportPage()));
    if (mounted) ref.read(contraventionsListeProvider.notifier).refresh();
  }

  Future<void> _importerQuittance() async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => const ReversementImportPage()));
    if (mounted) ref.read(contraventionsListeProvider.notifier).refresh();
  }

  Future<void> _saisieManuelle() async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => const ContraventionFormPage()));
    if (mounted) ref.read(contraventionsListeProvider.notifier).refresh();
  }

  // ── KPI ────────────────────────────────────────────────────────────────

  ({String label1, String value1, String label2, String value2, bool alerte})
      _kpi() {
    if (_isEtat) {
      final items = ref.watch(contraventionsListeProvider).items;
      final impaye = items
          .where((c) => !c.isRegle)
          .fold<double>(0, (s, c) => s + (c.montant - (c.montantPaye ?? 0)));
      final aRattacher =
          items.where((c) => c.statutRattachement == 'A_RATTACHER').length;
      return (
        label1: 'Total impayé',
        value1: _money.format(impaye),
        label2: 'À rattacher',
        value2: '$aRattacher',
        alerte: aRattacher > 0,
      );
    }
    final items = ref.watch(lignesPenaliteListeProvider).items;
    final du = items
        .where((l) => !l.statut.isTerminal)
        .fold<double>(0, (s, l) => s + (l.montantRestant ?? 0));
    final enAttente = items.where((l) => !l.statut.isTerminal).length;
    return (
      label1: 'Total dû',
      value1: _money.format(du),
      label2: 'En attente',
      value2: '$enAttente',
      alerte: false,
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final kpi = _kpi();
    // Recale l'amplitude de repli sur la hauteur réelle de l'en-tête.
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureHeader());

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
                  child: _segmented(),
                ),
                // KPI + recherche : se replient vers le haut au défilement.
                _collapsingHeader(kpi),
                Expanded(
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (n) {
                      // Seule la liste la plus proche (depth 0), en défilement
                      // vertical, pilote le repli de l'en-tête.
                      if (n is ScrollUpdateNotification &&
                          n.depth == 0 &&
                          n.metrics.axis == Axis.vertical) {
                        final next = (_collapse + (n.scrollDelta ?? 0))
                            .clamp(0.0, _headerMax);
                        if (next != _collapse) {
                          setState(() => _collapse = next);
                        }
                      }
                      return false;
                    },
                    child: IndexedStack(
                      index: _segment,
                      children: const [
                        LignesPenalitePage(embedded: true),
                        ContraventionsPage(embedded: true),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Barrière : ferme le speed-dial au tap en dehors.
            if (_addOpen)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _closeAdd,
                  child: const SizedBox.expand(),
                ),
              ),

            // Speed-dial descendant, ancré sous la pastille « + » de l'en-tête.
            Positioned(
              top: 58,
              right: 16,
              child: IgnorePointer(
                ignoring: !_addOpen,
                child: AnimatedSlide(
                  offset: _addOpen ? Offset.zero : const Offset(0, -0.08),
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOut,
                  child: AnimatedOpacity(
                    opacity: _addOpen ? 1 : 0,
                    duration: const Duration(milliseconds: 160),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _addAction(
                          label: 'Importer un relevé PDF',
                          icon: Icons.file_upload_outlined,
                          onTap: () {
                            _closeAdd();
                            _importerPdf();
                          },
                        ),
                        const SizedBox(height: 10),
                        _addAction(
                          label: 'Importer une quittance',
                          icon: Icons.receipt_long_outlined,
                          onTap: () {
                            _closeAdd();
                            _importerQuittance();
                          },
                        ),
                        const SizedBox(height: 10),
                        _addAction(
                          label: 'Saisie manuelle',
                          icon: Icons.edit_outlined,
                          onTap: () {
                            _closeAdd();
                            _saisieManuelle();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      color: AppColors.header,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          _pill(
            icon: Icons.arrow_back_rounded,
            onTap: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text('Contraventions',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.dark,
                    letterSpacing: -0.3)),
          ),
          _isEtat
              ? _addPill()
              : _pill(icon: Icons.auto_awesome_rounded, onTap: _generer),
        ],
      ),
    );
  }

  Widget _pill(
      {required IconData icon,
      required VoidCallback onTap,
      bool tinted = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 38,
        decoration: BoxDecoration(
          color: tinted ? AppColors.primaryTint : const Color(0xFFF0F2F8),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(icon,
            size: 18, color: tinted ? AppColors.primaryDark : AppColors.dark),
      ),
    );
  }

  // Contrôle segmenté aligné sur le style des onglets de FleetScreen :
  // conteneur gris clair, indicateur blanc à ombre légère, libellé actif en vert.
  Widget _segmented() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _segment0("Contrav. État", 1),
          _segment0('Pénalités', 0),
        ],
      ),
    );
  }

  Widget _segment0(String label, int index) {
    final actif = _segment == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => _selectSegment(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 9),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: actif ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: actif
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: actif ? const Color(0xFF43A047) : Colors.grey.shade600)),
        ),
      ),
    );
  }

  /// En-tête KPI qui s'escamote vers le haut au défilement.
  /// La boîte extérieure rétrécit (`SizedBox.height`) pour rendre l'espace à la
  /// liste, tandis que le contenu (hauteur pleine via `OverflowBox`) glisse vers
  /// le haut et s'estompe.
  Widget _collapsingHeader(
      ({
        String label1,
        String value1,
        String label2,
        String value2,
        bool alerte
      }) kpi) {
    final content = Column(
      key: _headerKey,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: _kpiBar(kpi),
        ),
      ],
    );

    final visible = (_headerMax - _collapse).clamp(0.0, _headerMax);
    final opacity =
        _headerMax <= 0 ? 1.0 : (visible / _headerMax).clamp(0.0, 1.0);

    return ClipRect(
      child: SizedBox(
        height: visible,
        child: OverflowBox(
          alignment: Alignment.topCenter,
          minHeight: 0,
          maxHeight: double.infinity,
          child: Transform.translate(
            offset: Offset(0, -_collapse),
            child: Opacity(opacity: opacity, child: content),
          ),
        ),
      ),
    );
  }

  Widget _kpiBar(
      ({
        String label1,
        String value1,
        String label2,
        String value2,
        bool alerte
      }) kpi) {
    return Row(
      children: [
        Expanded(child: _kpiCard(kpi.label1, kpi.value1, false)),
        const SizedBox(width: 10),
        Expanded(child: _kpiCard(kpi.label2, kpi.value2, kpi.alerte)),
      ],
    );
  }

  Widget _kpiCard(String label, String value, bool alerte) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 11.5, color: AppColors.label)),
          const SizedBox(height: 3),
          Text(value,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: alerte ? AppColors.warning : AppColors.dark)),
        ],
      ),
    );
  }

  /// Pastille « + » de l'en-tête : bascule le speed-dial, icône pivotante +→×.
  Widget _addPill() {
    return GestureDetector(
      onTap: _toggleAdd,
      child: Container(
        width: 56,
        height: 38,
        decoration: BoxDecoration(
          color: const Color(0xFFF0F2F8),
          borderRadius: BorderRadius.circular(20),
        ),
        child: AnimatedRotation(
          turns: _addOpen ? 0.125 : 0,
          duration: const Duration(milliseconds: 180),
          child: const Icon(Icons.add_rounded, size: 18, color: AppColors.dark),
        ),
      ),
    );
  }

  /// Action du speed-dial : libellé à gauche + pastille ronde teintée à droite.
  Widget _addAction({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(label,
                style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.dark)),
          ),
          const SizedBox(width: 9),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primaryTint,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 20, color: AppColors.primaryDark),
          ),
        ],
      ),
    );
  }
}

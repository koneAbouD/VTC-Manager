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
  final _searchController = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleAdd() => setState(() => _addOpen = !_addOpen);
  void _closeAdd() => setState(() => _addOpen = false);

  void _selectSegment(int index) {
    if (index == _segment) return;
    setState(() {
      _segment = index;
      _addOpen = false;
      _search = '';
      _searchController.clear();
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: _kpiBar(kpi),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
                  child: _searchBar(),
                ),
                Expanded(
                  child: IndexedStack(
                    index: _segment,
                    children: [
                      LignesPenalitePage(
                          embedded: true, externalSearch: _search),
                      ContraventionsPage(
                          embedded: true, externalSearch: _search),
                    ],
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

  Widget _segmented() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0F2F8),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _segment0('Pénalités', 0),
          _segment0("Contrav. État", 1),
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
            color: actif ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: actif ? FontWeight.w700 : FontWeight.w500,
                  color: actif ? Colors.white : AppColors.label)),
        ),
      ),
    );
  }

  Widget _searchBar() {
    final hint = _isEtat
        ? 'Rechercher un numéro, véhicule…'
        : 'Rechercher un véhicule, chauffeur…';
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const Icon(Icons.search, size: 18, color: AppColors.hint),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _search = v),
              style: const TextStyle(fontSize: 13, color: AppColors.dark),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 11),
                border: InputBorder.none,
                hintText: hint,
                hintStyle: const TextStyle(fontSize: 13, color: AppColors.hint),
              ),
            ),
          ),
          if (_search.isNotEmpty)
            GestureDetector(
              onTap: () => setState(() {
                _search = '';
                _searchController.clear();
              }),
              child: const Icon(Icons.close, size: 17, color: AppColors.hint),
            ),
        ],
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

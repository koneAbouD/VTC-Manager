import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/app_header.dart';
import '../../domain/entities/catalogue_element_maintenance.dart';
import '../../domain/entities/element_maintenance.dart';
import '../providers/catalogue_element_maintenance_provider.dart';
import '../../../../core/theme/app_colors.dart';

// ── Palette (reprend la même que le formulaire) ───────────────────────────────

const _kPrimary   = AppColors.primary;
const _kHint      = Color(0xFF9AA0AE);
const _kDark      = Color(0xFF1A1A2E);
const _kBorder    = Color(0xFFE3E6EE);
const _kAccent    = Color(0xFFE65100);

// ── Page ─────────────────────────────────────────────────────────────────────

class ElementsMaintenancePage extends ConsumerStatefulWidget {
  final List<ElementMaintenance> initial;

  const ElementsMaintenancePage({super.key, required this.initial});

  @override
  ConsumerState<ElementsMaintenancePage> createState() =>
      _ElementsMaintenancePageState();
}

class _ElementsMaintenancePageState
    extends ConsumerState<ElementsMaintenancePage> {
  // Éléments catalogue sélectionnés : id → entry
  final Map<int, _CatalogueEntry> _catalogueSel = {};
  // Éléments libres ajoutés par l'utilisateur
  final List<_FreeEntry> _freeItems = [];
  String _query = '';

  // Scroll
  final _scrollCtrl = ScrollController();
  bool _searchVisible = true;
  double _lastOffset = 0;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    for (final el in widget.initial) {
      if (el.catalogueElementId != null) {
        _catalogueSel[el.catalogueElementId!] = _CatalogueEntry(
          libelle: el.effectiveLibelle,
          montantCtrl: TextEditingController(
            text: el.montant > 0 ? el.montant.toStringAsFixed(0) : '',
          ),
        );
      } else {
        _freeItems.add(_FreeEntry(
          libelle: el.effectiveLibelle,
          montantCtrl: TextEditingController(
            text: el.montant > 0 ? el.montant.toStringAsFixed(0) : '',
          ),
        ));
      }
    }
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    for (final e in _catalogueSel.values) {
      e.montantCtrl.dispose();
    }
    for (final e in _freeItems) {
      e.montantCtrl.dispose();
    }
    super.dispose();
  }

  void _onScroll() {
    final offset = _scrollCtrl.offset;
    final delta = offset - _lastOffset;
    _lastOffset = offset;
    if (offset <= 0) {
      if (!_searchVisible) setState(() => _searchVisible = true);
      return;
    }
    if (delta > 3 && _searchVisible) {
      setState(() => _searchVisible = false);
    } else if (delta < -3 && !_searchVisible) {
      setState(() => _searchVisible = true);
    }
  }

  // ── Résultat à retourner ──────────────────────────────────────────────────

  List<ElementMaintenance> _buildResult() {
    final result = <ElementMaintenance>[];
    for (final entry in _catalogueSel.entries) {
      final montant = double.tryParse(
              entry.value.montantCtrl.text
                  .replaceAll(',', '.')
                  .replaceAll(' ', '')) ??
          0;
      result.add(ElementMaintenance(
        catalogueElementId: entry.key,
        catalogueElementLibelle: entry.value.libelle,
        montant: montant,
      ));
    }
    for (final f in _freeItems) {
      final montant = double.tryParse(
              f.montantCtrl.text.replaceAll(',', '.').replaceAll(' ', '')) ??
          0;
      result.add(ElementMaintenance(libelle: f.libelle, montant: montant));
    }
    return result;
  }

  // ── Toggle catalogue ──────────────────────────────────────────────────────

  void _toggleCatalogue(CatalogueElementMaintenance el, bool? checked) {
    setState(() {
      if (checked == true) {
        _catalogueSel.putIfAbsent(
          el.id,
          () => _CatalogueEntry(
            libelle: el.libelle,
            montantCtrl: TextEditingController(),
          ),
        );
      } else {
        _catalogueSel.remove(el.id)?.montantCtrl.dispose();
      }
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final catalogueAsync = ref.watch(catalogueElementsMaintenanceProvider);
    final catalogue = catalogueAsync.valueOrNull ?? [];

    final filtered = _query.isEmpty
        ? catalogue
        : catalogue
            .where((e) =>
                e.libelle.toLowerCase().contains(_query.toLowerCase()))
            .toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppHeader(
        title: 'Éléments concernés',
        action: AppHeaderAction(
          onTap: () => Navigator.pop(context, _buildResult()),
          icon: Icons.check_rounded,
        ),
      ),
      body: Column(
        children: [
            // ── Barre de recherche (masquée au scroll vers le bas) ───────
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              tween: Tween(begin: 1.0, end: _searchVisible ? 1.0 : 0.0),
              builder: (_, v, child) => ClipRect(
                child: Align(
                  alignment: Alignment.topCenter,
                  heightFactor: v,
                  child: Opacity(opacity: v, child: child),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  style: const TextStyle(fontSize: 15, color: _kDark),
                  decoration: InputDecoration(
                    hintText: 'Recherchez...',
                    hintStyle:
                        const TextStyle(color: _kHint, fontSize: 15),
                    suffixIcon:
                        const Icon(Icons.search, color: _kHint),
                    filled: true,
                    fillColor: const Color(0xFFF8F9FB),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 13),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: _kBorder, width: 1),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: _kBorder, width: 1),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: _kPrimary, width: 1.5),
                    ),
                  ),
                ),
              ),
            ),

            // ── Liste ────────────────────────────────────────────────────
            Expanded(
              child: catalogueAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                      color: _kPrimary, strokeWidth: 2),
                ),
                error: (_, __) => Center(
                  child: Text(
                    'Impossible de charger le catalogue.',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ),
                data: (_) {
                  final totalItems =
                      _freeItems.length + filtered.length;
                  if (totalItems == 0) {
                    return Center(
                      child: Text(
                        'Aucun élément trouvé',
                        style:
                            TextStyle(color: Colors.grey.shade500),
                      ),
                    );
                  }
                  return ListView.builder(
                    controller: _scrollCtrl,
                    itemCount: totalItems,
                    itemBuilder: (ctx, i) {
                      if (i < _freeItems.length) {
                        return _buildFreeRow(i);
                      }
                      return _buildCatalogueRow(
                          filtered[i - _freeItems.length]);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      );
  }

  // ── Ligne catalogue ───────────────────────────────────────────────────────

  Widget _buildCatalogueRow(CatalogueElementMaintenance el) {
    final isChecked = _catalogueSel.containsKey(el.id);
    return Container(
      decoration: const BoxDecoration(
        border:
            Border(bottom: BorderSide(color: Color(0xFFF0F1F4))),
      ),
      child: Row(
        children: [
          Checkbox(
            value: isChecked,
            onChanged: (v) => _toggleCatalogue(el, v),
            activeColor: _kPrimary,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4)),
            materialTapTargetSize:
                MaterialTapTargetSize.shrinkWrap,
          ),
          Expanded(
            child: Text(
              el.libelle,
              style: TextStyle(
                fontSize: 15,
                color: isChecked ? _kDark : _kHint,
                fontWeight: isChecked
                    ? FontWeight.w500
                    : FontWeight.w400,
              ),
            ),
          ),
          if (isChecked)
            _PriceField(ctrl: _catalogueSel[el.id]!.montantCtrl),
        ],
      ),
    );
  }

  // ── Ligne libre ───────────────────────────────────────────────────────────

  Widget _buildFreeRow(int index) {
    final item = _freeItems[index];
    return Container(
      decoration: const BoxDecoration(
        border:
            Border(bottom: BorderSide(color: Color(0xFFF0F1F4))),
      ),
      child: Row(
        children: [
          Checkbox(
            value: true,
            onChanged: (_) {
              setState(() {
                _freeItems[index].montantCtrl.dispose();
                _freeItems.removeAt(index);
              });
            },
            activeColor: _kPrimary,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4)),
            materialTapTargetSize:
                MaterialTapTargetSize.shrinkWrap,
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    item.libelle,
                    style: const TextStyle(
                        fontSize: 15,
                        color: _kDark,
                        fontWeight: FontWeight.w500),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color:
                        _kAccent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Libre',
                    style: TextStyle(
                        fontSize: 10,
                        color: _kAccent,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
          _PriceField(ctrl: item.montantCtrl),
        ],
      ),
    );
  }
}

// ── Champ prix inline ─────────────────────────────────────────────────────────

class _PriceField extends StatelessWidget {
  final TextEditingController ctrl;
  const _PriceField({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(
            width: 76,
            child: TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true),
              textAlign: TextAlign.right,
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: _kDark),
              decoration: const InputDecoration(
                isDense: true,
                border: UnderlineInputBorder(
                    borderSide:
                        BorderSide(color: _kDark, width: 1)),
                enabledBorder: UnderlineInputBorder(
                    borderSide:
                        BorderSide(color: _kDark, width: 1)),
                focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                        color: _kPrimary, width: 1.5)),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 2, vertical: 4),
              ),
            ),
          ),
          const SizedBox(width: 5),
          const Padding(
            padding: EdgeInsets.only(bottom: 5),
            child: Text(
              'XOF',
              style: TextStyle(
                  fontSize: 11,
                  color: _kHint,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Modèles internes ──────────────────────────────────────────────────────────

class _CatalogueEntry {
  final String libelle;
  final TextEditingController montantCtrl;
  _CatalogueEntry({required this.libelle, required this.montantCtrl});
}

class _FreeEntry {
  final String libelle;
  final TextEditingController montantCtrl;
  _FreeEntry({required this.libelle, required this.montantCtrl});
}

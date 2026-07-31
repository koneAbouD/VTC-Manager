import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/image_viewer.dart';
import '../../domain/entities/catalogue_element_maintenance.dart';
import '../../domain/entities/element_maintenance.dart';
import '../../../partenaire/presentation/widgets/partenaire_picker.dart';
import '../providers/catalogue_element_maintenance_provider.dart';
import '../../../../core/theme/app_colors.dart';

// ── Palette (reprend la même que le formulaire) ───────────────────────────────

const _kPrimary = AppColors.primary;
const _kHint = Color(0xFF9AA0AE);
const _kDark = Color(0xFF1A1A2E);
const _kBorder = Color(0xFFE3E6EE);
const _kAccent = Color(0xFFE65100);
const _kFieldFill = Color(0xFFF2F3F5);

// ── Page ─────────────────────────────────────────────────────────────────────

class ElementsMaintenancePage extends ConsumerStatefulWidget {
  final List<ElementMaintenance> initial;

  /// Partenaire de l'intervention : c'est lui qui prend en charge toute ligne
  /// sans prestataire propre.
  final String? partenaireDefautNom;

  const ElementsMaintenancePage({
    super.key,
    required this.initial,
    this.partenaireDefautNom,
  });

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

  /// Vrai quand le chantier mêle plusieurs prestataires. Éteint par défaut :
  /// dans le cas courant, un seul garage fait tout et le champ n'aurait servi
  /// qu'à alourdir chaque ligne. Un appui long sur la ligne concernée
  /// l'allume — le geste dit à la fois « ce chantier est partagé » et « c'est
  /// cette ligne-là qui change de main ».
  bool _multiPresta = false;

  // Scroll
  final _scrollCtrl = ScrollController();
  bool _searchVisible = true;
  double _lastOffset = 0;

  bool _refRafraichi = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Rafraîchit une seule fois le catalogue d'éléments (édité ailleurs, ex.
    // ReferentielListePage). Ici et non dans initState : `ref.invalidate`
    // dépend du ProviderScope, indisponible pendant initState.
    if (!_refRafraichi) {
      _refRafraichi = true;
      ref.invalidate(catalogueElementsMaintenanceProvider);
    }
  }

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    for (final el in widget.initial) {
      // Le champ tient le prix d'UN exemplaire ; la ligne a été enregistrée
      // avec son total, on refait donc le chemin inverse.
      final prixUnitaire =
          el.prixUnitaire > 0 ? el.prixUnitaire.toStringAsFixed(0) : '';
      if (el.catalogueElementId != null) {
        _catalogueSel[el.catalogueElementId!] = _CatalogueEntry(
          libelle: el.effectiveLibelle,
          montantCtrl: TextEditingController(text: prixUnitaire),
          quantite: el.quantite,
          partenaireId: el.partenaireId,
          partenaireNom: el.partenaireNom,
        );
      } else {
        _freeItems.add(_FreeEntry(
          libelle: el.effectiveLibelle,
          montantCtrl: TextEditingController(text: prixUnitaire),
          quantite: el.quantite,
          partenaireId: el.partenaireId,
          partenaireNom: el.partenaireNom,
        ));
      }
    }
    // Une saisie déjà répartie rouvre l'écran dans le mode qui l'a produite.
    _multiPresta = widget.initial.any((el) => el.partenaireId != null);
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

  /// Le champ porte le prix d'un exemplaire ; c'est le total qui part au
  /// serveur, seule valeur que somment le coût de l'intervention et la
  /// répartition des dettes.
  List<ElementMaintenance> _buildResult() {
    final result = <ElementMaintenance>[];
    for (final entry in _catalogueSel.entries) {
      result.add(ElementMaintenance(
        catalogueElementId: entry.key,
        catalogueElementLibelle: entry.value.libelle,
        quantite: entry.value.quantite,
        montant: entry.value.total,
        partenaireId: _multiPresta ? entry.value.partenaireId : null,
        partenaireNom: _multiPresta ? entry.value.partenaireNom : null,
      ));
    }
    for (final f in _freeItems) {
      result.add(ElementMaintenance(
        libelle: f.libelle,
        quantite: f.quantite,
        montant: f.total,
        partenaireId: _multiPresta ? f.partenaireId : null,
        partenaireNom: _multiPresta ? f.partenaireNom : null,
      ));
    }
    return result;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final catalogueAsync = ref.watch(catalogueElementsMaintenanceProvider);
    final catalogue = catalogueAsync.valueOrNull ?? [];

    final filtered = _query.isEmpty
        ? catalogue
        : catalogue
            .where(
                (e) => e.libelle.toLowerCase().contains(_query.toLowerCase()))
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
                  hintStyle: const TextStyle(color: _kHint, fontSize: 15),
                  suffixIcon: const Icon(Icons.search, color: _kHint),
                  filled: true,
                  fillColor: const Color(0xFFF8F9FB),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _kBorder, width: 1),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _kBorder, width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _kPrimary, width: 1.5),
                  ),
                ),
              ),
            ),
          ),

          // ── Plusieurs prestataires ──────────────────────────────────
          // Rien tant que le mode dort : la grande majorité des
          // interventions n'a qu'un prestataire, l'écran n'a pas à porter
          // en permanence un réglage qui ne servira pas.
          _buildBandeauMultiPresta(),

          // ── Liste ────────────────────────────────────────────────────
          Expanded(
            child: catalogueAsync.when(
              loading: () => const Center(
                child:
                    CircularProgressIndicator(color: _kPrimary, strokeWidth: 2),
              ),
              error: (_, __) => Center(
                child: Text(
                  'Impossible de charger le catalogue.',
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              ),
              data: (_) {
                final totalItems = _freeItems.length + filtered.length;
                if (totalItems == 0) {
                  return Center(
                    child: Text(
                      'Aucun élément trouvé',
                      style: TextStyle(color: Colors.grey.shade500),
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
                    final el = filtered[i - _freeItems.length];
                    // Widget à état propre : cocher/décocher ne reconstruit que
                    // cette ligne, pas toute la page (pas de « rechargement »).
                    return _CatalogueRow(
                      key: ValueKey('cat_${el.id}'),
                      el: el,
                      selection: _catalogueSel,
                      multiPresta: _multiPresta,
                      partenaireDefautNom: widget.partenaireDefautNom,
                      onActiverMulti: _activerMultiPresta,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Plusieurs prestataires ────────────────────────────────────────────────

  /// Allume le mode. Appelé par l'appui long d'une ligne, donc sans effet si
  /// le mode tourne déjà : deux lignes réparties ne doivent pas se battre.
  void _activerMultiPresta() {
    if (_multiPresta) return;
    setState(() => _multiPresta = true);
  }

  /// Sortie du mode. Les prestataires posés ligne à ligne ne partiront pas à
  /// l'enregistrement — tout retombe sur celui de l'intervention. On le dit
  /// avant, plutôt que de le laisser découvrir après coup. Les choix ne sont
  /// pas effacés pour autant : rallumer le mode les retrouve.
  Future<void> _quitterMultiPresta() async {
    final repartis = _catalogueSel.values.any((e) => e.partenaireId != null) ||
        _freeItems.any((e) => e.partenaireId != null);

    if (repartis) {
      final confirme = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Quitter la répartition ?'),
          content: const Text(
              "Les prestataires choisis ligne par ligne ne seront pas "
              "enregistrés : toute l'intervention repassera au prestataire "
              'principal.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Quitter'),
            ),
          ],
        ),
      );
      if (confirme != true) return;
    }
    if (!mounted) return;
    setState(() => _multiPresta = false);
  }

  /// Bandeau du mode actif : il dit ce qui se passe et porte la seule sortie.
  /// Absent le reste du temps — c'est l'appui long qui ouvre le mode.
  Widget _buildBandeauMultiPresta() {
    if (!_multiPresta) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
      color: _kPrimary.withValues(alpha: 0.06),
      child: Row(
        children: [
          const Icon(Icons.groups_2_outlined, size: 18, color: _kPrimary),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Plusieurs prestataires',
              style: TextStyle(
                  fontSize: 13.5, color: _kDark, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            onPressed: _quitterMultiPresta,
            icon: const Icon(Icons.close_rounded, size: 18),
            color: _kHint,
            tooltip: 'Quitter la répartition',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
          ),
        ],
      ),
    );
  }

  // ── Ligne libre ───────────────────────────────────────────────────────────

  /// Ouvre le choix du prestataire d'une ligne libre, en allumant le mode au
  /// passage : on ne demande pas « qui ? » sur un écran qui n'affiche encore
  /// aucun prestataire.
  Future<void> _choisirPrestataireLibre(_FreeEntry item) async {
    _activerMultiPresta();
    final choix = await choisirPartenaire(
      context,
      ref,
      selectionId: item.partenaireId,
      libelleParDefaut: widget.partenaireDefautNom,
    );
    if (choix == null || !mounted) return;
    setState(() {
      item.partenaireId = choix.partenaire?.id;
      item.partenaireNom = choix.partenaire?.nom;
    });
  }

  Widget _buildFreeRow(int index) {
    final item = _freeItems[index];
    return GestureDetector(
      // Appui long : cette ligne-là a son propre prestataire. Le geste ouvre
      // le mode et enchaîne sur le choix, plutôt que d'allumer un réglage et
      // laisser l'utilisateur chercher où cliquer ensuite.
      onLongPress: () {
        HapticFeedback.mediumImpact();
        _choisirPrestataireLibre(item);
      },
      child: Container(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFF0F1F4))),
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
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.libelle,
                          style: const TextStyle(
                              fontSize: 15,
                              color: _kDark,
                              fontWeight: FontWeight.w500),
                        ),
                        _QuantiteLigne(
                          quantite: item.quantite,
                          montantCtrl: item.montantCtrl,
                          onChanged: (q) => setState(() => item.quantite = q),
                        ),
                        if (_multiPresta)
                          PrestatairePuce(
                            nom: item.partenaireNom,
                            defautNom: widget.partenaireDefautNom,
                            onTap: () => _choisirPrestataireLibre(item),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _kAccent.withValues(alpha: 0.08),
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
      ),
    );
  }
}

// ── Ligne catalogue (widget à état propre) ──────────────────────────────────
// Isolée dans un StatefulWidget : cocher / décocher un élément ne reconstruit
// QUE cette ligne, pas toute la page (ni ses images) — plus de « rechargement ».
class _CatalogueRow extends ConsumerStatefulWidget {
  final CatalogueElementMaintenance el;
  final Map<int, _CatalogueEntry> selection;
  final bool multiPresta;
  final String? partenaireDefautNom;

  /// Remonte à la page l'ouverture du mode « plusieurs prestataires » : le
  /// mode vaut pour tout l'écran, une ligne ne peut pas le porter seule.
  final VoidCallback onActiverMulti;

  const _CatalogueRow({
    super.key,
    required this.el,
    required this.selection,
    required this.multiPresta,
    required this.onActiverMulti,
    this.partenaireDefautNom,
  });

  @override
  ConsumerState<_CatalogueRow> createState() => _CatalogueRowState();
}

class _CatalogueRowState extends ConsumerState<_CatalogueRow> {
  CatalogueElementMaintenance get _el => widget.el;
  Map<int, _CatalogueEntry> get _sel => widget.selection;

  void _toggle(bool? checked) {
    setState(() {
      if (checked == true) {
        _sel.putIfAbsent(
          _el.id,
          () => _CatalogueEntry(
            libelle: _el.libelle,
            // Pré-remplissage avec le montant par défaut du catalogue.
            montantCtrl: TextEditingController(
              text: (_el.montantDefaut != null && _el.montantDefaut! > 0)
                  ? _el.montantDefaut!.toStringAsFixed(0)
                  : '',
            ),
          ),
        );
      } else {
        _sel.remove(_el.id)?.montantCtrl.dispose();
      }
    });
  }

  /// Ouvre le choix du prestataire de la ligne. Coche l'élément s'il ne
  /// l'était pas — désigner qui fournit une pièce qu'on n'a pas retenue n'a
  /// pas de sens — et allume le mode au passage.
  Future<void> _choisirPrestataire() async {
    if (!_sel.containsKey(_el.id)) _toggle(true);
    widget.onActiverMulti();

    final entry = _sel[_el.id];
    if (entry == null) return;

    final choix = await choisirPartenaire(
      context,
      ref,
      selectionId: entry.partenaireId,
      libelleParDefaut: widget.partenaireDefautNom,
    );
    if (choix == null || !mounted) return;
    setState(() {
      entry.partenaireId = choix.partenaire?.id;
      entry.partenaireNom = choix.partenaire?.nom;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isChecked = _sel.containsKey(_el.id);
    return GestureDetector(
      // Appui long : cette ligne-là a son propre prestataire. Le geste ouvre
      // le mode et enchaîne sur le choix, plutôt que d'allumer un réglage et
      // laisser l'utilisateur chercher où cliquer ensuite.
      onLongPress: () {
        HapticFeedback.mediumImpact();
        _choisirPrestataire();
      },
      child: Container(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFF0F1F4))),
        ),
        child: Row(
          children: [
            Checkbox(
              value: isChecked,
              onChanged: _toggle,
              activeColor: _kPrimary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            if (_el.imageUrl != null) ...[
              GestureDetector(
                onTap: () =>
                    showImageViewer(context, _el.imageUrl!, titre: _el.libelle),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    _el.imageUrl!,
                    width: 32,
                    height: 32,
                    fit: BoxFit.cover,
                    cacheWidth: 96, // décodage léger : pas de re-décode coûteux
                    errorBuilder: (_, __, ___) =>
                        const SizedBox(width: 32, height: 32),
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _el.libelle,
                    style: TextStyle(
                      fontSize: 15,
                      color: isChecked ? _kDark : _kHint,
                      fontWeight: isChecked ? FontWeight.w500 : FontWeight.w400,
                    ),
                  ),
                  // Quantité et prestataire n'ont de sens que sur une ligne
                  // retenue : décochée, elle ne coûte rien à personne.
                  if (isChecked)
                    _QuantiteLigne(
                      quantite: _sel[_el.id]!.quantite,
                      montantCtrl: _sel[_el.id]!.montantCtrl,
                      onChanged: (q) =>
                          setState(() => _sel[_el.id]!.quantite = q),
                    ),
                  if (isChecked && widget.multiPresta)
                    PrestatairePuce(
                      nom: _sel[_el.id]!.partenaireNom,
                      defautNom: widget.partenaireDefautNom,
                      onTap: _choisirPrestataire,
                    ),
                ],
              ),
            ),
            if (isChecked) _PriceField(ctrl: _sel[_el.id]!.montantCtrl),
          ],
        ),
      ),
    );
  }
}

// ── Quantité ─────────────────────────────────────────────────────────────────
// Posée sous le libellé plutôt qu'à côté du prix : la ligne est déjà chargée à
// droite (champ + devise), et la quantité se lit mieux collée à ce qu'elle
// compte. N'apparaît que sur une ligne cochée.

/// Au-delà, ce n'est plus une intervention mais une commande : la borne évite
/// surtout qu'un appui resté enfoncé parte à l'infini.
const int _kQuantiteMax = 999;

class _QuantiteLigne extends StatelessWidget {
  final int quantite;

  /// Le prix unitaire est écouté, pas lu une fois : le total suit la frappe.
  final TextEditingController montantCtrl;
  final ValueChanged<int> onChanged;

  const _QuantiteLigne({
    required this.quantite,
    required this.montantCtrl,
    required this.onChanged,
  });

  void _pas(int delta) {
    final cible = (quantite + delta).clamp(1, _kQuantiteMax);
    if (cible == quantite) return;
    HapticFeedback.selectionClick();
    onChanged(cible);
  }

  /// Saisie directe : douze bougies ne se comptent pas au bouton +.
  Future<void> _saisir(BuildContext context) async {
    final ctrl = TextEditingController(text: '$quantite');
    ctrl.selection =
        TextSelection(baseOffset: 0, extentOffset: ctrl.text.length);

    final valeur = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nombre d\'exemplaires'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(suffixText: 'ex.'),
          onSubmitted: (v) => Navigator.pop(ctx, int.tryParse(v)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(ctrl.text)),
            child: const Text('Valider'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (valeur == null) return;
    onChanged(valeur.clamp(1, _kQuantiteMax));
  }

  @override
  Widget build(BuildContext context) {
    final multiple = quantite > 1;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pilule compacte : − N + d'un seul tenant, pour que le nombre reste
          // lisible entre ses deux boutons.
          Container(
            decoration: BoxDecoration(
              color: multiple ? _kAccent.withValues(alpha: 0.08) : _kFieldFill,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color:
                      multiple ? _kAccent.withValues(alpha: 0.35) : _kBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PasBouton(
                  icone: Icons.remove_rounded,
                  actif: quantite > 1,
                  onTap: () => _pas(-1),
                ),
                GestureDetector(
                  onTap: () => _saisir(context),
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 26),
                    alignment: Alignment.center,
                    child: Text(
                      '$quantite',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: multiple ? _kAccent : _kDark,
                      ),
                    ),
                  ),
                ),
                _PasBouton(
                  icone: Icons.add_rounded,
                  actif: quantite < _kQuantiteMax,
                  onTap: () => _pas(1),
                ),
              ],
            ),
          ),
          // Le total ne s'affiche qu'à partir de deux : à l'unité il répéterait
          // le champ de droite.
          if (multiple)
            AnimatedBuilder(
              animation: montantCtrl,
              builder: (_, __) => Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  '= ${CurrencyFormatter.format(_lirePrix(montantCtrl) * quantite)}',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _kAccent),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PasBouton extends StatelessWidget {
  final IconData icone;
  final bool actif;
  final VoidCallback onTap;

  const _PasBouton({
    required this.icone,
    required this.actif,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: actif ? onTap : null,
      customBorder: const CircleBorder(),
      child: SizedBox(
        width: 30,
        height: 28,
        child: Icon(icone, size: 15, color: actif ? _kDark : _kHint),
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
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.right,
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w700, color: _kDark),
              decoration: const InputDecoration(
                isDense: true,
                border: UnderlineInputBorder(
                    borderSide: BorderSide(color: _kDark, width: 1)),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: _kDark, width: 1)),
                focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: _kPrimary, width: 1.5)),
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

// ── Puce « prestataire de la ligne » ─────────────────────────────────────────
// Discrète tant que la ligne suit le partenaire de l'intervention, colorée dès
// qu'elle s'en écarte : d'un coup d'œil, on voit ce qui a été réparti.
class PrestatairePuce extends StatelessWidget {
  final String? nom;
  final String? defautNom;
  final VoidCallback onTap;

  const PrestatairePuce({
    super.key,
    required this.nom,
    required this.defautNom,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final propre = nom != null && nom!.isNotEmpty;
    final texte =
        propre ? nom! : (defautNom ?? 'Prestataire de l\'intervention');
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.storefront_outlined,
                  size: 12, color: propre ? _kAccent : _kHint),
              const SizedBox(width: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 150),
                child: Text(
                  texte,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: propre ? _kAccent : _kHint,
                    fontWeight: propre ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              const Icon(Icons.expand_more_rounded, size: 13, color: _kHint),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Modèles internes ──────────────────────────────────────────────────────────

/// Prix unitaire saisi dans un champ texte, ramené à un nombre. Vide ou
/// illisible vaut zéro : la ligne ne coûte rien tant qu'on n'a rien tapé.
double _lirePrix(TextEditingController ctrl) =>
    double.tryParse(ctrl.text.replaceAll(',', '.').replaceAll(' ', '')) ?? 0;

/// Ce que les deux sortes de lignes ont en commun : un prix unitaire au
/// clavier, un nombre d'exemplaires, et un prestataire facultatif.
mixin _LigneSaisie {
  TextEditingController get montantCtrl;

  /// Exemplaires posés. Jamais en dessous de 1 — une ligne à zéro pièce
  /// n'aurait aucune raison d'être cochée.
  int get quantite;

  double get prixUnitaire => _lirePrix(montantCtrl);

  /// Ce qui part au serveur.
  double get total => prixUnitaire * quantite;
}

class _CatalogueEntry with _LigneSaisie {
  final String libelle;
  @override
  final TextEditingController montantCtrl;
  @override
  int quantite;

  /// Prestataire propre à la ligne ; null = celui de l'intervention.
  int? partenaireId;
  String? partenaireNom;

  _CatalogueEntry({
    required this.libelle,
    required this.montantCtrl,
    this.quantite = 1,
    this.partenaireId,
    this.partenaireNom,
  });
}

class _FreeEntry with _LigneSaisie {
  final String libelle;
  @override
  final TextEditingController montantCtrl;
  @override
  int quantite;

  int? partenaireId;
  String? partenaireNom;

  _FreeEntry({
    required this.libelle,
    required this.montantCtrl,
    this.quantite = 1,
    this.partenaireId,
    this.partenaireNom,
  });
}

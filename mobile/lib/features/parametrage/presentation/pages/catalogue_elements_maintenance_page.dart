import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:tmk_cache/tmk_cache.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/image_viewer.dart';
import '../../../maintenance/presentation/providers/type_maintenance_provider.dart';
import '../../../operation_financiere/domain/entities/categorie_operation.dart';
import '../../../maintenance/presentation/widgets/maintenance_visuels.dart';
import '../../data/parametrage_api.dart';
import '../providers/catalogue_elements_providers.dart';
import '../providers/parametrage_providers.dart';
import '../widgets/cible_vehicule_catalogue.dart';
import 'catalogue_element_maintenance_form_page.dart';

/// Clé de section des éléments communs à tous les types de maintenance.
const _kCommuns = 'communs';

/// Paramétrage › Éléments de maintenance.
///
/// Le catalogue est rangé par type de maintenance — l'ordre dans lequel le
/// formulaire de maintenance les demande —, chaque ligne portant la portée
/// véhicule de l'élément. Des puces de modèles de la flotte restreignent la
/// liste à ce que la saisie proposerait pour un véhicule de ce modèle.
class CatalogueElementsMaintenancePage extends ConsumerStatefulWidget {
  final ReferentielDescriptor descriptor;

  const CatalogueElementsMaintenancePage({super.key, required this.descriptor});

  @override
  ConsumerState<CatalogueElementsMaintenancePage> createState() =>
      _CatalogueElementsMaintenancePageState();
}

class _CatalogueElementsMaintenancePageState
    extends ConsumerState<CatalogueElementsMaintenancePage> {
  /// Sections ouvertes, gardées le temps de la session : on les retrouve en
  /// revenant sur la page.
  static final Set<String> _ouvertes = {};

  ReferentielDescriptor get d => widget.descriptor;

  bool _busy = false;
  String _query = '';
  final _searchCtrl = TextEditingController();

  /// Modèle filtré ; null = tous les véhicules.
  CibleVehicule? _modele;

  /// Surcharge optimiste de l'état « actif » pendant l'appel réseau.
  final Map<Object, bool> _actifOverride = {};

  final _money =
      NumberFormat.currency(locale: 'fr_FR', symbol: 'XOF', decimalDigits: 0);

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Données ───────────────────────────────────────────────────────────────

  Future<void> _rafraichir() async {
    ref.invalidate(referentielItemsProvider(d.endpoint));
    ref.invalidate(elementsCompatiblesModeleProvider);
    try {
      await ref.read(referentielItemsProvider(d.endpoint).future);
    } catch (_) {}
  }

  bool _estActif(Map<String, dynamic> item) =>
      _actifOverride[item['id']] ?? item['actif'] as bool? ?? true;

  static String _normaliser(String s) => s
      .toLowerCase()
      .replaceAll(RegExp('[éèêë]'), 'e')
      .replaceAll(RegExp('[àâä]'), 'a')
      .replaceAll(RegExp('[îï]'), 'i')
      .replaceAll(RegExp('[ôö]'), 'o')
      .replaceAll(RegExp('[ùûü]'), 'u')
      .replaceAll('ç', 'c');

  bool _correspond(Map<String, dynamic> item, String q) => [
        item['libelle'],
        item['categorieTypeLibelle'],
        item['marqueNom'],
        item['modeleNom'],
      ].any((v) => v != null && _normaliser('$v').contains(q));

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _ouvrirFormulaire(
      {Map<String, dynamic>? item, int? categorieTypeId}) async {
    final modifie = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CatalogueElementMaintenanceFormPage(
            item: item, categorieTypeInitialeId: categorieTypeId),
      ),
    );
    if (modifie == true) await _rafraichir();
  }

  Future<void> _basculerActif(Map<String, dynamic> item, bool actif) async {
    final id = item['id'] as Object;
    setState(() => _actifOverride[id] = actif);
    try {
      await ref
          .read(parametrageApiProvider)
          .changerActivation(d.endpoint, id, actif);
      await _rafraichir();
    } catch (e) {
      _toast(_message(e), erreur: true);
    } finally {
      if (mounted) setState(() => _actifOverride.remove(id));
    }
  }

  Future<void> _supprimer(Map<String, dynamic> item) async {
    final libelle = item['libelle'] ?? '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Supprimer',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text('Supprimer « $libelle » ? Cette action est définitive.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(parametrageApiProvider)
          .supprimer(d.endpoint, item['id'] as Object);
      await _rafraichir();
      _toast('« $libelle » supprimé.');
    } catch (e) {
      _toast(_message(e), erreur: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _choisirAutreModele() async {
    final choix = await choisirCibleVehicule(
      context,
      actuelle: _modele ?? CibleVehicule.tous,
      modelesSeulement: true,
      titre: 'Filtrer sur un modèle',
    );
    if (choix != null && mounted) setState(() => _modele = choix);
  }

  void _toast(String message, {bool erreur = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: erreur ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      ));
  }

  String _message(Object e) {
    try {
      final m = (e as dynamic).message;
      if (m is String && m.isNotEmpty) return m;
    } catch (_) {}
    return 'Opération impossible.';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(referentielItemsProvider(d.endpoint));
    final liste = itemsAsync.valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: AppHeader(
        title: d.libelle,
        action: d.editable
            ? AppHeaderAction(
                icon: Icons.add_rounded,
                onTap: _busy ? null : () => _ouvrirFormulaire(),
              )
            : null,
      ),
      body: liste == null
          ? itemsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => _erreur(),
              data: (_) => const SizedBox.shrink(),
            )
          : _corps(liste),
    );
  }

  Widget _corps(List<Map<String, dynamic>> tous) {
    final flotte = ref.watch(modelesFlotteProvider).valueOrNull ?? const [];
    final types =
        ref.watch(typeMaintenanceProvider('Maintenances')).valueOrNull ??
            const [];

    // Filtre par modèle : la compatibilité est celle du serveur.
    final modele = _modele;
    final compatiblesAsync = modele?.modeleId == null
        ? null
        : ref.watch(elementsCompatiblesModeleProvider(modele!.modeleId!));
    final compatibles = compatiblesAsync?.valueOrNull;

    final q = _normaliser(_query.trim());
    final visibles = tous
        .where((it) => compatibles == null || compatibles.contains(it['id']))
        .where((it) => q.isEmpty || _correspond(it, q))
        .toList();

    // Sections : une par type de maintenance présent, du plus fourni au moins
    // fourni ; les éléments communs ferment la liste.
    final parType = <String, List<Map<String, dynamic>>>{};
    for (final it in visibles) {
      final typeId = (it['categorieTypeId'] as num?)?.toInt();
      parType.putIfAbsent(typeId == null ? _kCommuns : '$typeId', () => [])
          .add(it);
    }
    for (final l in parType.values) {
      l.sort((a, b) => _normaliser('${a['libelle'] ?? ''}')
          .compareTo(_normaliser('${b['libelle'] ?? ''}')));
    }
    final cles = parType.keys.where((k) => k != _kCommuns).toList()
      ..sort((a, b) {
        final parNombre = parType[b]!.length.compareTo(parType[a]!.length);
        return parNombre != 0
            ? parNombre
            : _libelleSection(a, parType, types)
                .compareTo(_libelleSection(b, parType, types));
      });
    if (parType.containsKey(_kCommuns)) cles.add(_kCommuns);

    // Une recherche ou un filtre de modèle montrent leurs résultats tout de
    // suite : on ne fait pas ouvrir chaque section pour les trouver.
    final toutOuvert = q.isNotEmpty || modele != null;

    return Column(
      children: [
        SizedBox(
          height: 2,
          child: _busy || (compatiblesAsync?.isLoading ?? false)
              ? const LinearProgressIndicator(minHeight: 2)
              : null,
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _rafraichir,
            color: AppColors.primary,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _barreRecherche()),
                SliverToBoxAdapter(child: _pucesModeles(flotte)),
                if (modele != null)
                  SliverToBoxAdapter(
                      child: _resumeModele(modele)),
                if (visibles.isEmpty)
                  SliverToBoxAdapter(child: _vide(q.isNotEmpty || modele != null))
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 96),
                    sliver: SliverList.list(children: [
                      for (final cle in cles) ...[
                        _enTeteSection(cle, parType[cle]!, types,
                            ouverte: toutOuvert || _ouvertes.contains(cle),
                            forcee: toutOuvert),
                        if (toutOuvert || _ouvertes.contains(cle))
                          for (final it in parType[cle]!) ...[
                            const SizedBox(height: 6),
                            _ligne(it),
                          ],
                        const SizedBox(height: 10),
                      ],
                    ]),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _libelleSection(String cle, Map<String, List<Map<String, dynamic>>> parType,
      List<CategorieOperation> types) {
    if (cle == _kCommuns) return 'Communs à tous les types';
    final premier = parType[cle]!.first;
    return (premier['categorieTypeLibelle'] as String?) ??
        types
            .where((t) => '${t.id}' == cle)
            .map((t) => t.libelle)
            .firstOrNull ??
        'Type #$cle';
  }

  // ── Recherche et filtre ───────────────────────────────────────────────────

  Widget _barreRecherche() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _query = v),
        textInputAction: TextInputAction.search,
        style: TextStyle(fontSize: 15, color: AppColors.dark),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Rechercher un élément…',
          hintStyle: TextStyle(color: AppColors.hint, fontSize: 15),
          prefixIcon: Icon(Icons.search, color: AppColors.hint, size: 20),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  icon: Icon(Icons.close_rounded,
                      color: AppColors.hint, size: 18),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _query = '');
                  },
                ),
          filled: true,
          fillColor: AppColors.surface,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _pucesModeles(List<ModeleFlotte> flotte) {
    final modele = _modele;
    final horsFlotte = modele != null &&
        !flotte.any((m) => m.modeleId == modele.modeleId);
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
        children: [
          _puce('Tous les véhicules',
              choisie: modele == null,
              onTap: () => setState(() => _modele = null)),
          for (final m in flotte)
            _puce(m.modeleNom,
                choisie: modele?.modeleId == m.modeleId,
                onTap: () => setState(() => _modele = CibleVehicule(
                      marqueId: m.marqueId,
                      marqueNom: m.marqueNom,
                      modeleId: m.modeleId,
                      modeleNom: m.modeleNom,
                    ))),
          if (horsFlotte)
            _puce(modele.libelle,
                choisie: true, onTap: _choisirAutreModele),
          _puce('Autres modèles',
              icone: Icons.search_rounded,
              choisie: false,
              onTap: _choisirAutreModele),
        ],
      ),
    );
  }

  Widget _puce(String libelle,
      {required bool choisie, required VoidCallback onTap, IconData? icone}) {
    final accent = AppColors.primary;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
        button: true,
        selected: choisie,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: choisie ? accent.withValues(alpha: 0.12) : AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: choisie ? accent.withValues(alpha: 0.5) : AppColors.border),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (icone != null) ...[
                Icon(icone, size: 14, color: AppColors.label),
                const SizedBox(width: 4),
              ],
              Text(libelle,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: choisie ? FontWeight.w700 : FontWeight.w500,
                      color: choisie ? accent : AppColors.label)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _resumeModele(CibleVehicule modele) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
      child: Text(
        'Éléments proposés pour ${modele.libelle}',
        style: TextStyle(fontSize: 12.5, color: AppColors.label),
      ),
    );
  }

  // ── Sections ──────────────────────────────────────────────────────────────

  Widget _enTeteSection(String cle, List<Map<String, dynamic>> items,
      List<CategorieOperation> types,
      {required bool ouverte, required bool forcee}) {
    final libelle = _libelleSection(cle, {cle: items}, types);
    final premier = items.first;
    final icone = cle == _kCommuns
        ? Icons.all_inclusive_rounded
        : TypeMaintenanceVisuel.icone(
            code: types
                .where((t) => '${t.id}' == cle)
                .map((t) => t.code)
                .firstOrNull,
            libelle: premier['categorieTypeLibelle'] as String?);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: forcee
          ? null
          : () => setState(() {
                if (!_ouvertes.remove(cle)) _ouvertes.add(cle);
              }),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
        decoration: BoxDecoration(
          color: ouverte ? Colors.transparent : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: ouverte ? Colors.transparent : AppColors.border),
        ),
        child: Row(children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppColors.fieldFill,
              shape: BoxShape.circle,
            ),
            child: Icon(icone, size: 16, color: AppColors.label),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              libelle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.dark),
            ),
          ),
          if (d.editable)
            IconButton(
              tooltip: 'Ajouter un élément',
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.add_rounded, size: 20, color: AppColors.label),
              onPressed: _busy
                  ? null
                  : () => _ouvrirFormulaire(
                      categorieTypeId:
                          cle == _kCommuns ? null : int.tryParse(cle)),
            ),
          if (!forcee)
            Icon(
                ouverte
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                color: AppColors.hint),
          if (forcee) const SizedBox(width: 8),
        ]),
      ),
    );
  }

  Widget _ligne(Map<String, dynamic> item) {
    final actif = _estActif(item);
    final montant = item['montantDefaut'] as num?;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: actif ? 1 : 0.5,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: InkWell(
          onTap: d.editable && !_busy
              ? () => _ouvrirFormulaire(item: item)
              : null,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 9, 4, 9),
            child: Row(children: [
              _vignette(item['imageUrl'] as String?),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${item['libelle'] ?? ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.dark)),
                    const SizedBox(height: 4),
                    Row(children: [
                      Flexible(
                        child: PastilleVehicule(
                            cible: CibleVehicule.depuisElement(item)),
                      ),
                      if (montant != null && montant > 0) ...[
                        const SizedBox(width: 8),
                        Text(_money.format(montant),
                            style: TextStyle(
                                fontSize: 11.5, color: AppColors.label)),
                      ],
                    ]),
                  ],
                ),
              ),
              if (d.editable)
                Transform.scale(
                  scale: 0.70,
                  child: Switch.adaptive(
                    value: actif,
                    activeThumbColor: AppColors.primary,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: _busy ? null : (v) => _basculerActif(item, v),
                  ),
                ),
              if (d.editable) _menuActions(item),
            ]),
          ),
        ),
      ),
    );
  }

  /// Vignette de l'image de l'élément ; une pastille neutre à défaut, pour
  /// garder les libellés alignés.
  Widget _vignette(String? imageUrl) {
    Widget pastille() => Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.fieldFill,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.inventory_2_outlined,
              size: 17, color: AppColors.hint),
        );
    if (imageUrl == null || imageUrl.isEmpty) return pastille();
    return GestureDetector(
      onTap: () => showImageViewer(context, imageUrl),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image(
          image: imageReseau(imageUrl),
          width: 36,
          height: 36,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => pastille(),
        ),
      ),
    );
  }

  Widget _menuActions(Map<String, dynamic> item) {
    return PopupMenuButton<String>(
      enabled: !_busy,
      tooltip: 'Actions',
      icon: Icon(Icons.more_vert_rounded, color: AppColors.hint, size: 20),
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shadowColor: AppColors.dark.withValues(alpha: 0.18),
      position: PopupMenuPosition.under,
      offset: const Offset(0, 4),
      constraints: const BoxConstraints(minWidth: 190),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppColors.border),
      ),
      menuPadding: const EdgeInsets.symmetric(vertical: 6),
      onSelected: (v) {
        if (v == 'edit') _ouvrirFormulaire(item: item);
        if (v == 'delete') _supprimer(item);
      },
      itemBuilder: (_) => [
        _entreeMenu('edit', Icons.edit_outlined, 'Modifier', AppColors.dark),
        const PopupMenuDivider(height: 9),
        _entreeMenu('delete', Icons.delete_outline_rounded, 'Supprimer',
            AppColors.error),
      ],
    );
  }

  PopupMenuItem<String> _entreeMenu(
      String valeur, IconData icone, String libelle, Color couleur) {
    return PopupMenuItem<String>(
      value: valeur,
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: couleur.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icone, size: 18, color: couleur),
        ),
        const SizedBox(width: 12),
        Text(libelle,
            style: TextStyle(
                fontSize: 14.5, fontWeight: FontWeight.w600, color: couleur)),
      ]),
    );
  }

  // ── États ─────────────────────────────────────────────────────────────────

  Widget _vide(bool filtre) {
    return Padding(
      padding: EdgeInsets.only(top: MediaQuery.of(context).size.height * 0.18),
      child: Center(
        child: Column(
          children: [
            Icon(filtre ? Icons.search_off_rounded : Icons.inbox_rounded,
                size: 44, color: AppColors.hint),
            const SizedBox(height: 10),
            Text(
              filtre
                  ? 'Aucun élément ne correspond.'
                  : 'Aucun élément. Ajoutez-en un.',
              style: TextStyle(color: AppColors.label),
            ),
          ],
        ),
      ),
    );
  }

  Widget _erreur() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.hint),
            const SizedBox(height: 12),
            Text('Chargement impossible.',
                style: TextStyle(color: AppColors.label)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () =>
                  ref.invalidate(referentielItemsProvider(d.endpoint)),
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}

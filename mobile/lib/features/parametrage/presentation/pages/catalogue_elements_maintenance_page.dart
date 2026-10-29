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

/// Sections ouvertes, gardées le temps de la session et partagées par les
/// onglets : on retrouve la même section ouverte d'un modèle à l'autre, et en
/// revenant sur la page.
final _sectionsOuvertes = <String>{};

@visibleForTesting
void reinitialiserSectionsOuvertesCatalogue() => _sectionsOuvertes.clear();

/// Paramétrage › Éléments de maintenance.
///
/// Un onglet par modèle de la flotte, chacun présenté de la même façon : les
/// éléments que la saisie d'une maintenance proposerait pour ce modèle, rangés
/// par type de maintenance, les communs à tous les types en dernier. Un onglet
/// « Hors flotte » garde accessibles les éléments réservés à des modèles ou
/// marques absents de la flotte.
class CatalogueElementsMaintenancePage extends ConsumerStatefulWidget {
  final ReferentielDescriptor descriptor;

  const CatalogueElementsMaintenancePage({super.key, required this.descriptor});

  @override
  ConsumerState<CatalogueElementsMaintenancePage> createState() =>
      _CatalogueElementsMaintenancePageState();
}

class _CatalogueElementsMaintenancePageState
    extends ConsumerState<CatalogueElementsMaintenancePage> {
  Set<String> get _ouvertes => _sectionsOuvertes;

  ReferentielDescriptor get d => widget.descriptor;

  bool _busy = false;
  String _query = '';
  final _searchCtrl = TextEditingController();

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
    final flotteAsync = ref.watch(modelesFlotteProvider);
    if (flotteAsync.isLoading && !flotteAsync.hasValue) {
      return const Center(child: CircularProgressIndicator());
    }
    final flotte = flotteAsync.valueOrNull ?? const <ModeleFlotte>[];
    final types =
        ref.watch(typeMaintenanceProvider('Maintenances')).valueOrNull ??
            const <CategorieOperation>[];

    // Ordre des sections fixé sur tout le catalogue : chaque onglet présente
    // les types dans le même ordre, communs à tous les types en dernier.
    final ordre = _ordreSections(tous, types);
    final horsFlotte = _horsFlotte(tous, flotte);
    final onglets = <({String titre, ModeleFlotte? modele})>[
      for (final m in flotte) (titre: m.modeleNom, modele: m),
      if (horsFlotte.isNotEmpty) (titre: 'Hors flotte', modele: null),
    ];

    final progression = SizedBox(
      height: 2,
      child: _busy ? const LinearProgressIndicator(minHeight: 2) : null,
    );

    // Sans véhicule dans la flotte, il n'y a pas de modèle à présenter : tout
    // le catalogue reste visible pour pouvoir le préparer.
    if (onglets.isEmpty) {
      return Column(children: [
        progression,
        _barreRecherche(),
        Expanded(child: _listeSections(tous, ordre, types, null)),
      ]);
    }

    return DefaultTabController(
      key: ValueKey(onglets.map((o) => o.titre).join('|')),
      length: onglets.length,
      child: Column(
        children: [
          progression,
          _barreRecherche(),
          TabBar(
            isScrollable: onglets.length > 3,
            tabAlignment: onglets.length > 3 ? TabAlignment.start : null,
            labelColor: AppColors.dark,
            unselectedLabelColor: AppColors.hint,
            labelStyle:
                const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
            unselectedLabelStyle:
                const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
            indicatorColor: AppColors.primary,
            indicatorSize: TabBarIndicatorSize.label,
            dividerColor: AppColors.border,
            tabs: [for (final o in onglets) Tab(text: o.titre)],
          ),
          Expanded(
            child: TabBarView(
              children: [
                for (final o in onglets)
                  o.modele == null
                      ? _listeSections(horsFlotte, ordre, types, null)
                      : _ongletModele(tous, o.modele!, ordre, types),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Onglet d'un modèle : ce que la saisie proposerait pour un véhicule de ce
  /// modèle. La compatibilité est celle du serveur, pas une copie en Dart.
  Widget _ongletModele(List<Map<String, dynamic>> tous, ModeleFlotte modele,
      List<String> ordre, List<CategorieOperation> types) {
    final compatibles =
        ref.watch(elementsCompatiblesModeleProvider(modele.modeleId));
    return compatibles.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => _erreur(),
      data: (ids) => _listeSections(
          tous.where((it) => ids.contains(it['id'])).toList(),
          ordre,
          types,
          modele.modeleId),
    );
  }

  /// Clés de section dans l'ordre d'affichage : types du plus fourni au moins
  /// fourni sur tout le catalogue, puis les communs à tous les types.
  List<String> _ordreSections(
      List<Map<String, dynamic>> tous, List<CategorieOperation> types) {
    final parType = _grouper(tous);
    return parType.keys.where((k) => k != _kCommuns).toList()
      ..sort((a, b) {
        final parNombre = parType[b]!.length.compareTo(parType[a]!.length);
        return parNombre != 0
            ? parNombre
            : _libelleSection(a, parType, types)
                .compareTo(_libelleSection(b, parType, types));
      })
      ..add(_kCommuns);
  }

  Map<String, List<Map<String, dynamic>>> _grouper(
      List<Map<String, dynamic>> items) {
    final parType = <String, List<Map<String, dynamic>>>{};
    for (final it in items) {
      final typeId = (it['categorieTypeId'] as num?)?.toInt();
      parType.putIfAbsent(typeId == null ? _kCommuns : '$typeId', () => [])
          .add(it);
    }
    return parType;
  }

  /// Éléments réservés à un modèle, ou à une marque, absents de la flotte :
  /// aucun onglet de modèle ne les montrerait.
  List<Map<String, dynamic>> _horsFlotte(
      List<Map<String, dynamic>> tous, List<ModeleFlotte> flotte) {
    final modeles = {for (final m in flotte) m.modeleId};
    final marques = {for (final m in flotte) m.marqueId};
    return tous.where((it) {
      final cible = CibleVehicule.depuisElement(it);
      if (cible.estModele) return !modeles.contains(cible.modeleId);
      if (cible.estMarque) return !marques.contains(cible.marqueId);
      return false;
    }).toList();
  }

  /// Sections de type d'un onglet. [modeleOnglet] : modèle présenté, pour
  /// dire « Ce modèle » plutôt que son nom sur les éléments qui lui sont
  /// réservés.
  Widget _listeSections(List<Map<String, dynamic>> items, List<String> ordre,
      List<CategorieOperation> types, int? modeleOnglet) {
    final q = _normaliser(_query.trim());
    final visibles =
        items.where((it) => q.isEmpty || _correspond(it, q)).toList();
    final parType = _grouper(visibles);
    for (final l in parType.values) {
      l.sort((a, b) => _normaliser('${a['libelle'] ?? ''}')
          .compareTo(_normaliser('${b['libelle'] ?? ''}')));
    }
    final cles = ordre.where(parType.containsKey).toList();
    // Une recherche montre ses résultats tout de suite : on ne fait pas ouvrir
    // chaque section pour les trouver.
    final toutOuvert = q.isNotEmpty;

    return RefreshIndicator(
      onRefresh: _rafraichir,
      color: AppColors.primary,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (visibles.isEmpty)
            SliverToBoxAdapter(child: _vide(q.isNotEmpty))
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              sliver: SliverList.list(children: [
                for (final cle in cles) ...[
                  _enTeteSection(cle, parType[cle]!, types,
                      ouverte: toutOuvert || _ouvertes.contains(cle),
                      forcee: toutOuvert),
                  if (toutOuvert || _ouvertes.contains(cle))
                    for (final it in parType[cle]!) ...[
                      const SizedBox(height: 6),
                      _ligne(it, modeleOnglet),
                    ],
                  const SizedBox(height: 10),
                ],
              ]),
            ),
        ],
      ),
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
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

  Widget _ligne(Map<String, dynamic> item, int? modeleOnglet) {
    final actif = _estActif(item);
    final montant = item['montantDefaut'] as num?;
    final cible = CibleVehicule.depuisElement(item);
    // Un élément commun à tous les véhicules — le cas courant — ne porte
    // aucune mention ; seul ce qui est réservé se signale.
    final portee = cible.estModele
        ? (cible.modeleId == modeleOnglet ? 'Ce modèle' : cible.libelle)
        : cible.estMarque
            ? 'Marque ${cible.marqueNom ?? ''}'.trim()
            : null;
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
                    if (portee != null) ...[
                      const SizedBox(height: 4),
                      _MentionPortee(
                          libelle: portee, marque: cible.estMarque),
                    ],
                  ],
                ),
              ),
              if (montant != null && montant > 0)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(_money.format(montant),
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.dark,
                          fontFeatures: const [FontFeature.tabularFigures()])),
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

/// Mention de portée d'un élément réservé : pleine pour un modèle, cerclée
/// pour une marque entière. Sans couleur d'accent.
class _MentionPortee extends StatelessWidget {
  final String libelle;
  final bool marque;

  const _MentionPortee({required this.libelle, required this.marque});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(5, 2, 7, 2),
      decoration: BoxDecoration(
        color: marque ? Colors.transparent : AppColors.fieldFill,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
            color: marque ? AppColors.border : Colors.transparent),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(marque ? Icons.sell_outlined : Icons.directions_car_outlined,
            size: 12, color: AppColors.label),
        const SizedBox(width: 3),
        Flexible(
          child: Text(libelle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.dark)),
        ),
      ]),
    );
  }
}

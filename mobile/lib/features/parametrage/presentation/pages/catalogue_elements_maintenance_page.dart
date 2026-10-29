import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:tmk_cache/tmk_cache.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/image_viewer.dart';
import '../../../maintenance/presentation/providers/type_maintenance_provider.dart';
import '../../../maintenance/presentation/widgets/maintenance_visuels.dart';
import '../../../operation_financiere/domain/entities/categorie_operation.dart';
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

/// Une ligne de la liste : un élément pour un modèle, avec le prix, l'image et
/// l'activation de ce modèle. [modele] est nul pour un élément qui n'a encore
/// de tarif pour aucun modèle.
class _Ligne {
  final Map<String, dynamic> element;
  final CibleVehicule? modele;
  final num? prix;
  final String? image;
  final String? imageUrl;
  final bool tarifActif;

  /// Mention affichée sous le libellé (modèle hors flotte, aucun modèle).
  final String? mention;

  const _Ligne({
    required this.element,
    required this.modele,
    this.prix,
    this.image,
    this.imageUrl,
    this.tarifActif = true,
    this.mention,
  });

  Object get elementId => element['id'] as Object;

  String get cle => '$elementId-${modele?.modeleId}';

  bool get elementActif => element['actif'] as bool? ?? true;
}

/// Paramétrage › Éléments de maintenance.
///
/// Un onglet par modèle de la flotte : les éléments que ce modèle se voit
/// proposer à la saisie d'une maintenance, avec leur prix et leur image pour
/// ce modèle, rangés par type de maintenance (communs à tous les types en
/// dernier). Un onglet « Hors flotte » garde accessibles les éléments des
/// modèles absents de la flotte et ceux qui n'ont encore aucun modèle.
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

  /// Surcharge optimiste de « proposé pour ce modèle » pendant l'appel réseau
  /// (clé de ligne → valeur souhaitée).
  final Map<String, bool> _actifOverride = {};

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
    ref.invalidate(elementsDuModeleProvider);
    try {
      await ref.read(referentielItemsProvider(d.endpoint).future);
    } catch (_) {}
  }

  static String _normaliser(String s) => s
      .toLowerCase()
      .replaceAll(RegExp('[éèêë]'), 'e')
      .replaceAll(RegExp('[àâä]'), 'a')
      .replaceAll(RegExp('[îï]'), 'i')
      .replaceAll(RegExp('[ôö]'), 'o')
      .replaceAll(RegExp('[ùûü]'), 'u')
      .replaceAll('ç', 'c');

  bool _correspond(_Ligne l, String q) => [
        l.element['libelle'],
        l.element['categorieTypeLibelle'],
        l.mention,
      ].any((v) => v != null && _normaliser('$v').contains(q));

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _ouvrirFormulaire(
      {_Ligne? ligne, CibleVehicule? modele, int? categorieTypeId}) async {
    final modifie = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CatalogueElementMaintenanceFormPage(
          element: ligne?.element,
          modele: ligne?.modele ?? modele,
          prix: ligne?.prix,
          image: ligne?.image,
          imageUrl: ligne?.imageUrl,
          tarifActif: ligne?.tarifActif ?? true,
          categorieTypeInitialeId: categorieTypeId,
        ),
      ),
    );
    if (modifie == true) await _rafraichir();
  }

  Future<void> _basculerTarif(_Ligne l, bool actif) async {
    final modele = l.modele;
    if (modele?.modeleId == null) return;
    setState(() => _actifOverride[l.cle] = actif);
    try {
      await ref.read(parametrageApiProvider).enregistrerTarif(
          d.endpoint, l.elementId, modele!.modeleId!,
          prix: l.prix, image: l.image, actif: actif);
      await _rafraichir();
    } catch (e) {
      _toast(_message(e), erreur: true);
    } finally {
      if (mounted) setState(() => _actifOverride.remove(l.cle));
    }
  }

  Future<bool> _confirmer(String titre, String message, String action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(titre, style: const TextStyle(fontWeight: FontWeight.w800)),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _retirerDuModele(_Ligne l) async {
    final modele = l.modele;
    if (modele?.modeleId == null) return;
    final libelle = l.element['libelle'] ?? '';
    if (!await _confirmer(
        'Retirer du modèle',
        '« $libelle » ne sera plus proposé pour ${modele!.libelle}. '
            'Les maintenances passées ne changent pas.',
        'Retirer')) {
      return;
    }
    await _executer(
      () => ref
          .read(parametrageApiProvider)
          .supprimerTarif(d.endpoint, l.elementId, modele.modeleId!),
      succes: '« $libelle » retiré de ${modele.libelle}.',
    );
  }

  Future<void> _supprimer(_Ligne l) async {
    final libelle = l.element['libelle'] ?? '';
    if (!await _confirmer(
        'Supprimer',
        'Supprimer « $libelle » de tous les modèles ? Cette action est définitive.',
        'Supprimer')) {
      return;
    }
    await _executer(
      () => ref.read(parametrageApiProvider).supprimer(d.endpoint, l.elementId),
      succes: '« $libelle » supprimé.',
    );
  }

  Future<void> _copierVers(ModeleFlotte cible, List<ModeleFlotte> flotte) async {
    final choix = await showModalBottomSheet<_ChoixCopie>(
      context: context,
      useSafeArea: true,
      backgroundColor: AppColors.scaffold,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CopieSheet(
        cible: cible,
        sources: flotte.where((m) => m.modeleId != cible.modeleId).toList(),
      ),
    );
    if (choix == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final copies = await ref.read(parametrageApiProvider).copierTarifs(
            d.endpoint,
            deModeleId: choix.source.modeleId,
            versModeleId: cible.modeleId,
            avecPrix: choix.avecPrix,
            avecImages: choix.avecImages,
          );
      await _rafraichir();
      _toast(copies == 0
          ? '${cible.modeleNom} a déjà tous les éléments de ${choix.source.modeleNom}.'
          : '$copies élément${copies > 1 ? 's' : ''} ajouté${copies > 1 ? 's' : ''} à ${cible.modeleNom}.');
    } catch (e) {
      _toast(_message(e), erreur: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _executer(Future<void> Function() action,
      {required String succes}) async {
    setState(() => _busy = true);
    try {
      await action();
      await _rafraichir();
      _toast(succes);
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
    final horsFlotte = _lignesHorsFlotte(tous, flotte);
    final onglets = <({String titre, ModeleFlotte? modele})>[
      for (final m in flotte) (titre: m.modeleNom, modele: m),
      if (horsFlotte.isNotEmpty || flotte.isEmpty)
        (titre: 'Hors flotte', modele: null),
    ];

    return DefaultTabController(
      key: ValueKey(onglets.map((o) => o.titre).join('|')),
      length: onglets.length,
      child: Column(
        children: [
          SizedBox(
            height: 2,
            child: _busy ? const LinearProgressIndicator(minHeight: 2) : null,
          ),
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
                      ? _listeSections(horsFlotte, ordre, types)
                      : _ongletModele(o.modele!, flotte, ordre, types),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Onglet d'un modèle : ses éléments, avec le prix et l'image de ce modèle.
  Widget _ongletModele(ModeleFlotte modele, List<ModeleFlotte> flotte,
      List<String> ordre, List<CategorieOperation> types) {
    final cible = CibleVehicule(
      marqueId: modele.marqueId,
      marqueNom: modele.marqueNom,
      modeleId: modele.modeleId,
      modeleNom: modele.modeleNom,
    );
    final elements = ref.watch(elementsDuModeleProvider(modele.modeleId));
    return elements.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => _erreur(),
      data: (items) => _listeSections(
        [
          for (final it in items)
            _Ligne(
              element: it,
              modele: cible,
              prix: it['montantDefaut'] as num?,
              image: it['image'] as String?,
              imageUrl: it['imageUrl'] as String?,
              tarifActif: it['tarifActif'] as bool? ?? true,
            ),
        ],
        ordre,
        types,
        modele: cible,
        // Reprendre les éléments d'un autre modèle n'a de sens que s'il y en
        // a un autre dans la flotte.
        copie: d.editable && flotte.length > 1
            ? () => _copierVers(modele, flotte)
            : null,
      ),
    );
  }

  /// Clés de section dans l'ordre d'affichage : types du plus fourni au moins
  /// fourni sur tout le catalogue, puis les communs à tous les types.
  List<String> _ordreSections(
      List<Map<String, dynamic>> tous, List<CategorieOperation> types) {
    final parType = _grouper(tous, (it) => it);
    return parType.keys.where((k) => k != _kCommuns).toList()
      ..sort((a, b) {
        final parNombre = parType[b]!.length.compareTo(parType[a]!.length);
        return parNombre != 0
            ? parNombre
            : _libelleSection(a, parType[a]!.first, types)
                .compareTo(_libelleSection(b, parType[b]!.first, types));
      })
      ..add(_kCommuns);
  }

  Map<String, List<T>> _grouper<T>(
      List<T> items, Map<String, dynamic> Function(T) element) {
    final parType = <String, List<T>>{};
    for (final it in items) {
      final typeId = (element(it)['categorieTypeId'] as num?)?.toInt();
      parType.putIfAbsent(typeId == null ? _kCommuns : '$typeId', () => [])
          .add(it);
    }
    return parType;
  }

  /// Lignes hors flotte : tarifs des modèles absents de la flotte, et
  /// éléments qui n'ont encore aucun modèle — aucun onglet de modèle ne les
  /// montrerait.
  List<_Ligne> _lignesHorsFlotte(
      List<Map<String, dynamic>> tous, List<ModeleFlotte> flotte) {
    final modelesFlotte = {for (final m in flotte) m.modeleId};
    final lignes = <_Ligne>[];
    for (final it in tous) {
      final tarifs =
          (it['tarifs'] as List? ?? const []).whereType<Map<String, dynamic>>();
      if (tarifs.isEmpty) {
        lignes.add(_Ligne(element: it, modele: null, mention: 'Aucun modèle'));
        continue;
      }
      for (final t in tarifs) {
        final modeleId = (t['modeleId'] as num?)?.toInt();
        if (modeleId == null || modelesFlotte.contains(modeleId)) continue;
        final cible = CibleVehicule(
          marqueId: (t['marqueId'] as num?)?.toInt(),
          marqueNom: t['marqueNom'] as String?,
          modeleId: modeleId,
          modeleNom: t['modeleNom'] as String?,
        );
        lignes.add(_Ligne(
          element: it,
          modele: cible,
          prix: t['prix'] as num?,
          image: t['image'] as String?,
          imageUrl: t['imageUrl'] as String?,
          tarifActif: t['actif'] as bool? ?? true,
          mention: cible.libelle,
        ));
      }
    }
    return lignes;
  }

  /// Sections de type d'un onglet. [modele] : modèle de l'onglet, repris par
  /// le « + » d'une section ; [copie] : reprise des éléments d'un autre modèle.
  Widget _listeSections(List<_Ligne> lignes, List<String> ordre,
      List<CategorieOperation> types,
      {CibleVehicule? modele, VoidCallback? copie}) {
    final q = _normaliser(_query.trim());
    final visibles =
        lignes.where((l) => q.isEmpty || _correspond(l, q)).toList();
    final parType = _grouper(visibles, (l) => l.element);
    for (final l in parType.values) {
      l.sort((a, b) => _normaliser('${a.element['libelle'] ?? ''}')
          .compareTo(_normaliser('${b.element['libelle'] ?? ''}')));
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
            SliverToBoxAdapter(
                child: _vide(q.isNotEmpty, modele: modele, copie: copie))
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              sliver: SliverList.list(children: [
                for (final cle in cles) ...[
                  _enTeteSection(cle, parType[cle]!.first.element, types,
                      modele: modele,
                      ouverte: toutOuvert || _ouvertes.contains(cle),
                      forcee: toutOuvert),
                  if (toutOuvert || _ouvertes.contains(cle))
                    for (final l in parType[cle]!) ...[
                      const SizedBox(height: 6),
                      _ligne(l),
                    ],
                  const SizedBox(height: 10),
                ],
                if (copie != null && q.isEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _busy ? null : copie,
                      icon: Icon(Icons.content_copy_rounded,
                          size: 17, color: AppColors.label),
                      label: Text('Reprendre les éléments d\'un autre modèle',
                          style: TextStyle(color: AppColors.label)),
                    ),
                  ),
              ]),
            ),
        ],
      ),
    );
  }

  String _libelleSection(String cle, Map<String, dynamic> premier,
      List<CategorieOperation> types) {
    if (cle == _kCommuns) return 'Communs à tous les types';
    return (premier['categorieTypeLibelle'] as String?) ??
        types
            .where((t) => '${t.id}' == cle)
            .map((t) => t.libelle)
            .firstOrNull ??
        'Type #$cle';
  }

  // ── Recherche ─────────────────────────────────────────────────────────────

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

  Widget _enTeteSection(String cle, Map<String, dynamic> premier,
      List<CategorieOperation> types,
      {required CibleVehicule? modele,
      required bool ouverte,
      required bool forcee}) {
    final libelle = _libelleSection(cle, premier, types);
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
                      modele: modele,
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

  Widget _ligne(_Ligne l) {
    final tarifActif = _actifOverride[l.cle] ?? l.tarifActif;
    final propose = l.elementActif && tarifActif;
    final prix = l.prix;
    final mentions = [
      if (l.mention != null) l.mention!,
      if (!l.elementActif) 'Désactivé pour tous les modèles',
    ];
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: propose ? 1 : 0.5,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: InkWell(
          onTap: d.editable && !_busy ? () => _ouvrirFormulaire(ligne: l) : null,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 9, 4, 9),
            child: Row(children: [
              _vignette(l.imageUrl),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${l.element['libelle'] ?? ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.dark)),
                    for (final m in mentions) ...[
                      const SizedBox(height: 4),
                      _Mention(libelle: m),
                    ],
                  ],
                ),
              ),
              if (prix != null && prix > 0)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(_money.format(prix),
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.dark,
                          fontFeatures: const [FontFeature.tabularFigures()])),
                ),
              // L'interrupteur dit si l'élément est proposé pour ce modèle ;
              // l'activation pour tous les modèles se règle dans la fiche.
              if (d.editable && l.modele?.modeleId != null)
                Transform.scale(
                  scale: 0.70,
                  child: Switch.adaptive(
                    value: tarifActif,
                    activeThumbColor: AppColors.primary,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: _busy ? null : (v) => _basculerTarif(l, v),
                  ),
                ),
              if (d.editable) _menuActions(l),
            ]),
          ),
        ),
      ),
    );
  }

  /// Vignette de l'image de l'élément pour ce modèle ; une pastille neutre à
  /// défaut, pour garder les libellés alignés.
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

  Widget _menuActions(_Ligne l) {
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
      constraints: const BoxConstraints(minWidth: 210),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppColors.border),
      ),
      menuPadding: const EdgeInsets.symmetric(vertical: 6),
      onSelected: (v) {
        if (v == 'edit') _ouvrirFormulaire(ligne: l);
        if (v == 'retirer') _retirerDuModele(l);
        if (v == 'delete') _supprimer(l);
      },
      itemBuilder: (_) => [
        _entreeMenu('edit', Icons.edit_outlined, 'Modifier', AppColors.dark),
        if (l.modele?.modeleId != null)
          _entreeMenu('retirer', Icons.remove_circle_outline_rounded,
              'Retirer de ce modèle', AppColors.dark),
        const PopupMenuDivider(height: 9),
        _entreeMenu('delete', Icons.delete_outline_rounded,
            'Supprimer de tous les modèles', AppColors.error),
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

  Widget _vide(bool recherche,
      {CibleVehicule? modele, VoidCallback? copie}) {
    return Padding(
      padding: EdgeInsets.only(top: MediaQuery.of(context).size.height * 0.16),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              Icon(recherche ? Icons.search_off_rounded : Icons.inbox_rounded,
                  size: 44, color: AppColors.hint),
              const SizedBox(height: 10),
              Text(
                recherche
                    ? 'Aucun élément ne correspond.'
                    : modele != null
                        ? 'Aucun élément pour ${modele.libelle}.'
                        : 'Aucun élément hors flotte.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.label),
              ),
              // Un modèle qui entre dans la flotte n'a encore rien : on le
              // remplit en reprenant les éléments d'un modèle existant.
              if (!recherche && copie != null) ...[
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _busy ? null : copie,
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryDark,
                      foregroundColor: Colors.white),
                  icon: const Icon(Icons.content_copy_rounded, size: 18),
                  label: const Text('Reprendre les éléments d\'un autre modèle'),
                ),
              ],
            ],
          ),
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
              onPressed: _rafraichir,
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

/// Mention sous le libellé d'une ligne (modèle hors flotte, aucun modèle,
/// désactivé partout). Sans couleur d'accent.
class _Mention extends StatelessWidget {
  final String libelle;

  const _Mention({required this.libelle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 2, 7, 2),
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(libelle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: AppColors.dark)),
    );
  }
}

// ── Reprise des éléments d'un autre modèle ────────────────────────────────────

class _ChoixCopie {
  final ModeleFlotte source;
  final bool avecPrix;
  final bool avecImages;

  const _ChoixCopie(this.source, this.avecPrix, this.avecImages);
}

class _CopieSheet extends StatefulWidget {
  final ModeleFlotte cible;
  final List<ModeleFlotte> sources;

  const _CopieSheet({required this.cible, required this.sources});

  @override
  State<_CopieSheet> createState() => _CopieSheetState();
}

class _CopieSheetState extends State<_CopieSheet> {
  late ModeleFlotte? _source =
      widget.sources.isEmpty ? null : widget.sources.first;
  bool _avecPrix = true;
  bool _avecImages = true;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.primary;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 10, 16, 16 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.grey300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text('Reprendre pour ${widget.cible.modeleNom}',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.dark)),
          const SizedBox(height: 4),
          Text(
              'Les éléments du modèle choisi que ${widget.cible.modeleNom} '
              'n\'a pas encore lui sont ajoutés. Ceux qu\'il a déjà ne changent pas.',
              style: TextStyle(fontSize: 13, color: AppColors.label)),
          const SizedBox(height: 12),
          for (final m in widget.sources)
            GestureDetector(
              onTap: () => setState(() => _source = m),
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: _source == m ? accent : Colors.transparent,
                      width: 1.5),
                ),
                child: Row(children: [
                  Icon(Icons.directions_car_outlined,
                      size: 20, color: AppColors.label),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(m.libelle,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.dark)),
                  ),
                  if (_source == m)
                    Icon(Icons.check_circle_rounded, size: 20, color: accent),
                ]),
              ),
            ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _avecPrix,
            activeThumbColor: accent,
            onChanged: (v) => setState(() => _avecPrix = v),
            title: Text('Reprendre aussi les prix',
                style: TextStyle(fontSize: 14, color: AppColors.dark)),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _avecImages,
            activeThumbColor: accent,
            onChanged: (v) => setState(() => _avecImages = v),
            title: Text('Reprendre aussi les images',
                style: TextStyle(fontSize: 14, color: AppColors.dark)),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 50,
            child: FilledButton(
              onPressed: _source == null
                  ? null
                  : () => Navigator.pop(
                      context, _ChoixCopie(_source!, _avecPrix, _avecImages)),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Reprendre',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

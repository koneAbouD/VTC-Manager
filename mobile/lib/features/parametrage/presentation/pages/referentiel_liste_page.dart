import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/image_viewer.dart';
import '../../data/parametrage_api.dart';
import '../providers/parametrage_providers.dart';
import 'referentiel_form_page.dart';

/// Liste générique des valeurs d'un référentiel, pilotée par son descripteur :
/// affichage, recherche, activation/désactivation, édition et suppression.
///
/// Après CHAQUE mutation (création, édition, activation, suppression) la liste
/// est rechargée de façon déterministe via [_rafraichir] (invalidation + attente
/// du refetch), et la liste précédente reste visible pendant le rechargement
/// (pas de spinner plein écran) pour un rendu fluide.
class ReferentielListePage extends ConsumerStatefulWidget {
  final ReferentielDescriptor descriptor;
  const ReferentielListePage({super.key, required this.descriptor});

  @override
  ConsumerState<ReferentielListePage> createState() =>
      _ReferentielListePageState();
}

class _ReferentielListePageState extends ConsumerState<ReferentielListePage> {
  ReferentielDescriptor get d => widget.descriptor;

  /// Au-delà de ce nombre d'éléments, la barre de recherche apparaît.
  static const int _seuilRecherche = 20;

  bool _busy = false;
  String _query = '';
  final _searchCtrl = TextEditingController();

  /// Surcharge optimiste de l'état « actif » pendant l'appel réseau
  /// (id → valeur souhaitée) : le switch réagit immédiatement au tap, puis la
  /// liste rafraîchie fait foi.
  final Map<Object, bool> _actifOverride = {};

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Rafraîchissement déterministe ──────────────────────────────────────────
  Future<void> _rafraichir() async {
    ref.invalidate(referentielItemsProvider(d.endpoint));
    // On attend la fin du refetch pour que l'UI reflète l'état serveur à coup
    // sûr. L'erreur éventuelle est portée par l'AsyncValue de la liste.
    try {
      await ref.read(referentielItemsProvider(d.endpoint).future);
    } catch (_) {}
  }

  // ── Actions ────────────────────────────────────────────────────────────────
  Future<void> _ouvrirFormulaire([Map<String, dynamic>? item]) async {
    final modifie = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ReferentielFormPage(descriptor: d, item: item),
      ),
    );
    if (modifie == true) await _rafraichir();
  }

  Future<void> _basculerActif(Map<String, dynamic> item, bool actif) async {
    final id = item[d.idField] as Object;
    // Retour immédiat via l'override optimiste, sans passer par `_busy` : les
    // autres switches de la liste ne sont pas figés/grisés, et le rechargement
    // reste invisible. Pas de toast de confirmation.
    setState(() => _actifOverride[id] = actif);
    try {
      await ref
          .read(parametrageApiProvider)
          .changerActivation(d.endpoint, id, actif);
      await _rafraichir();
    } catch (e) {
      _toast(_message(e), erreur: true);
    } finally {
      if (mounted) {
        setState(() => _actifOverride.remove(id)); // la liste rafraîchie fait foi
      }
    }
  }

  Future<void> _supprimer(Map<String, dynamic> item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Supprimer',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text(
            'Supprimer « ${_titre(item)} » ? Cette action est définitive.'),
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
          .supprimer(d.endpoint, item[d.idField] as Object);
      await _rafraichir();
      _toast('« ${_titre(item)} » supprimé.');
    } catch (e) {
      _toast(_message(e), erreur: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Helpers d'affichage ────────────────────────────────────────────────────
  bool _estActif(Map<String, dynamic> item) {
    final id = item[d.idField] as Object?;
    if (id != null && _actifOverride.containsKey(id)) return _actifOverride[id]!;
    return item['actif'] as bool? ?? true;
  }

  String _titre(Map<String, dynamic> item) {
    final champ = d.champTitre;
    if (champ == null) return '#${item[d.idField]}';
    final v = _valeur(item, champ);
    return v.isEmpty ? '#${item[d.idField]}' : v;
  }

  /// Valeur affichable d'un champ pour un item (gère les références imbriquées).
  String _valeur(Map<String, dynamic> item, ChampDescriptor champ) {
    if (champ.type == 'reference') {
      final nested = champ.nom.endsWith('Id')
          ? champ.nom.substring(0, champ.nom.length - 2)
          : champ.nom;
      final obj = item[nested];
      if (obj is Map) {
        return (obj['nom'] ?? obj['libelle'] ?? obj['code'] ?? '').toString();
      }
      return item[champ.nom]?.toString() ?? '';
    }
    return item[champ.nom]?.toString() ?? '';
  }

  String _sousTitre(Map<String, dynamic> item) {
    final champ = d.champTitre;
    return d.champsSaisis
        // On exclut le champ image : sa « valeur » est le nom de fichier de
        // l'objet, sans intérêt dans le sous-titre (l'image est déjà en vignette).
        .where((c) => c != champ && c.type != 'bool' && c.type != 'image')
        .map((c) => _valeur(item, c))
        .where((v) => v.isNotEmpty)
        .join(' · ');
  }

  bool _correspond(Map<String, dynamic> item, String q) =>
      '${_titre(item)} ${_sousTitre(item)}'.toLowerCase().contains(q);

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

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(referentielItemsProvider(d.endpoint));
    // On garde la dernière liste connue visible pendant un refetch : pas de
    // spinner plein écran qui « efface » la liste après chaque action.
    final liste = itemsAsync.valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: AppHeader(
        title: d.libelle,
        // Bouton d'ajout dans l'en-tête (charte : même pill que LignesMaintenancePage).
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

  /// Ordre d'affichage **stable** (par identifiant croissant = ordre de
  /// création). Le backend ne garantit pas d'ordre déterministe : après un
  /// changement d'activation, la ligne modifiée peut revenir à une position
  /// différente. On fige donc l'ordre côté client pour qu'une (dés)activation
  /// ne déplace jamais l'élément dans la liste.
  List<Map<String, dynamic>> _ordonner(List<Map<String, dynamic>> liste) {
    final copie = [...liste];
    copie.sort((a, b) {
      final ida = a[d.idField];
      final idb = b[d.idField];
      if (ida is num && idb is num) return ida.compareTo(idb);
      return '$ida'.compareTo('$idb');
    });
    return copie;
  }

  Widget _corps(List<Map<String, dynamic>> listeBrute) {
    final liste = _ordonner(listeBrute);
    final q = _query.trim().toLowerCase();
    final filtree =
        q.isEmpty ? liste : liste.where((it) => _correspond(it, q)).toList();
    final afficherRecherche = liste.length > _seuilRecherche;

    return Column(
      children: [
        // Fine barre de progression pendant une suppression (les (dés)activations
        // ne passent pas par `_busy`, donc n'affichent aucun chargement).
        SizedBox(
          height: 2,
          child: _busy ? const LinearProgressIndicator(minHeight: 2) : null,
        ),
        if (afficherRecherche) _barreRecherche(liste.length),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _rafraichir,
            color: AppColors.primary,
            child: filtree.isEmpty
                ? _vide(rechercheActive: q.isNotEmpty)
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: filtree.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _tuile(filtree[i]),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _barreRecherche(int total) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _query = v),
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontSize: 15, color: AppColors.dark),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Rechercher parmi $total…',
          hintStyle: const TextStyle(color: AppColors.hint, fontSize: 15),
          prefixIcon: const Icon(Icons.search, color: AppColors.hint, size: 20),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded,
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
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _vide({required bool rechercheActive}) {
    // Scrollable pour conserver le pull-to-refresh même quand c'est vide.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.22),
        Center(
          child: Column(
            children: [
              Icon(
                  rechercheActive
                      ? Icons.search_off_rounded
                      : Icons.inbox_rounded,
                  size: 44,
                  color: AppColors.hint),
              const SizedBox(height: 10),
              Text(
                rechercheActive
                    ? 'Aucun résultat pour « $_query ».'
                    : 'Aucune valeur. Ajoutez-en une.',
                style: const TextStyle(color: AppColors.label),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _erreur() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.hint),
            const SizedBox(height: 12),
            const Text('Chargement impossible.',
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

  Widget _leadingVisuel(String? imageUrl, String initiale) {
    Widget pastille() => Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.10),
            shape: BoxShape.circle,
          ),
          child: Text(initiale,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary)),
        );
    if (imageUrl == null || imageUrl.isEmpty) return pastille();
    return GestureDetector(
      onTap: () => showImageViewer(context, imageUrl),
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              imageUrl,
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => pastille(),
            ),
          ),
          // Petit indice « agrandir ».
          Container(
            padding: const EdgeInsets.all(1),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(Icons.zoom_in_rounded, size: 11, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _tuile(Map<String, dynamic> item) {
    final actif = _estActif(item);
    final sousTitre = _sousTitre(item);
    final titre = _titre(item);
    final initiale =
        titre.isNotEmpty && titre != '#${item[d.idField]}' ? titre[0].toUpperCase() : '•';

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
          onTap: d.editable && !_busy ? () => _ouvrirFormulaire(item) : null,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
            child: Row(
              children: [
                // Vignette image si présente, sinon pastille à initiale.
                _leadingVisuel(item['imageUrl'] as String?, initiale),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.dark)),
                      if (sousTitre.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(sousTitre,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.label)),
                      ],
                    ],
                  ),
                ),
                // Toggle minimisé (compact) : l'état est aussi rendu par
                // l'opacité de la tuile et la pastille grisée quand inactif.
                if (d.gereActif && d.editable)
                  Transform.scale(
                    scale: 0.78,
                    child: Switch.adaptive(
                      value: actif,
                      activeThumbColor: AppColors.primary,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onChanged:
                          _busy ? null : (v) => _basculerActif(item, v),
                    ),
                  ),
                if (d.editable)
                  PopupMenuButton<String>(
                    enabled: !_busy,
                    icon: const Icon(Icons.more_vert_rounded,
                        color: AppColors.hint, size: 20),
                    onSelected: (v) {
                      if (v == 'edit') _ouvrirFormulaire(item);
                      if (v == 'delete') _supprimer(item);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Modifier')),
                      PopupMenuItem(value: 'delete', child: Text('Supprimer')),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}

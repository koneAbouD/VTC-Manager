import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../providers/catalogue_elements_providers.dart';
import '../providers/parametrage_providers.dart';

/// Véhicules auxquels un élément de maintenance s'adresse : tous, une marque
/// entière, ou un seul modèle. Le modèle suffit à désigner sa marque — le
/// serveur la déduit — d'où un seul choix au lieu de deux champs.
class CibleVehicule {
  final int? marqueId;
  final String? marqueNom;
  final int? modeleId;
  final String? modeleNom;

  const CibleVehicule({
    this.marqueId,
    this.marqueNom,
    this.modeleId,
    this.modeleNom,
  });

  static const tous = CibleVehicule();

  /// Portée lue sur un élément du catalogue (réponse à plat : marqueId,
  /// marqueNom, modeleId, modeleNom).
  factory CibleVehicule.depuisElement(Map<String, dynamic> item) =>
      CibleVehicule(
        marqueId: (item['marqueId'] as num?)?.toInt(),
        marqueNom: item['marqueNom'] as String?,
        modeleId: (item['modeleId'] as num?)?.toInt(),
        modeleNom: item['modeleNom'] as String?,
      );

  bool get estTous => marqueId == null && modeleId == null;
  bool get estMarque => modeleId == null && marqueId != null;
  bool get estModele => modeleId != null;

  String get libelle {
    if (estModele) {
      return [marqueNom, modeleNom]
          .where((s) => s != null && s.isNotEmpty)
          .join(' ');
    }
    if (estMarque) return 'Toute la marque ${marqueNom ?? ''}'.trim();
    return 'Tous les véhicules';
  }

  /// Ce que le formulaire envoie : le modèle seul (sa marque en est déduite),
  /// la marque seule, ou rien.
  Map<String, dynamic> versCorps() => {
        'modeleId': modeleId,
        'marqueId': estModele ? null : marqueId,
      };

  @override
  bool operator ==(Object other) =>
      other is CibleVehicule &&
      other.marqueId == marqueId &&
      other.modeleId == modeleId;

  @override
  int get hashCode => Object.hash(marqueId, modeleId);
}

/// Pastille de la portée d'un élément : grise pour tous les véhicules, pleine
/// à l'accent pour un modèle, cerclée pour une marque entière.
class PastilleVehicule extends StatelessWidget {
  final CibleVehicule cible;

  const PastilleVehicule({super.key, required this.cible});

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.primary;
    final (fond, bord, texte) = cible.estModele
        ? (accent.withValues(alpha: 0.12), Colors.transparent, accent)
        : cible.estMarque
            ? (Colors.transparent, accent.withValues(alpha: 0.45), accent)
            : (AppColors.fieldFill, Colors.transparent, AppColors.hint);
    return Container(
      padding: const EdgeInsets.fromLTRB(5, 2, 7, 2),
      decoration: BoxDecoration(
        color: fond,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: bord),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(cible.estMarque ? Icons.sell_outlined : Icons.directions_car_outlined,
            size: 12, color: texte),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            cible.estTous ? 'Tous véhicules' : cible.libelle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 10.5, fontWeight: FontWeight.w700, color: texte),
          ),
        ),
      ]),
    );
  }
}

/// Feuille de choix de la portée. Les modèles de la flotte viennent d'abord,
/// avec leur nombre de véhicules ; les autres modèles du référentiel restent
/// accessibles par la recherche. [modelesSeulement] retire « tous » et les
/// marques entières (filtre de la liste, qui raisonne par modèle).
Future<CibleVehicule?> choisirCibleVehicule(
  BuildContext context, {
  required CibleVehicule actuelle,
  bool modelesSeulement = false,
  String titre = 'Véhicule concerné',
}) {
  return showModalBottomSheet<CibleVehicule>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.scaffold,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _CibleVehiculeSheet(
      actuelle: actuelle,
      modelesSeulement: modelesSeulement,
      titre: titre,
    ),
  );
}

class _CibleVehiculeSheet extends ConsumerStatefulWidget {
  final CibleVehicule actuelle;
  final bool modelesSeulement;
  final String titre;

  const _CibleVehiculeSheet({
    required this.actuelle,
    required this.modelesSeulement,
    required this.titre,
  });

  @override
  ConsumerState<_CibleVehiculeSheet> createState() =>
      _CibleVehiculeSheetState();
}

class _CibleVehiculeSheetState extends ConsumerState<_CibleVehiculeSheet> {
  String _query = '';

  static String _normaliser(String s) => s
      .toLowerCase()
      .replaceAll(RegExp('[éèêë]'), 'e')
      .replaceAll(RegExp('[àâä]'), 'a')
      .replaceAll(RegExp('[îï]'), 'i')
      .replaceAll(RegExp('[ôö]'), 'o')
      .replaceAll(RegExp('[ùûü]'), 'u')
      .replaceAll('ç', 'c');

  @override
  Widget build(BuildContext context) {
    final flotte = ref.watch(modelesFlotteProvider).valueOrNull ?? const [];
    final modelesAsync = ref.watch(referentielItemsProvider(kEndpointModeles));
    final idsFlotte = {for (final m in flotte) m.modeleId};

    // Autres modèles du référentiel : actifs, hors flotte, triés par marque
    // puis nom. Le modèle déjà choisi reste proposé même désactivé.
    final autres = <CibleVehicule>[];
    final marques = <int, String>{};
    for (final it in modelesAsync.valueOrNull ?? const <Map<String, dynamic>>[]) {
      final id = (it['id'] as num?)?.toInt();
      final marque = it['marque'];
      final marqueId =
          marque is Map ? (marque['id'] as num?)?.toInt() : null;
      final marqueNom = marque is Map ? marque['nom'] as String? : null;
      if (marqueId != null && marqueNom != null) marques[marqueId] = marqueNom;
      final actif = it['actif'] as bool? ?? true;
      if (id == null || idsFlotte.contains(id)) continue;
      if (!actif && id != widget.actuelle.modeleId) continue;
      autres.add(CibleVehicule(
        marqueId: marqueId,
        marqueNom: marqueNom,
        modeleId: id,
        modeleNom: it['nom'] as String?,
      ));
    }
    autres.sort((a, b) => a.libelle.compareTo(b.libelle));

    final q = _normaliser(_query.trim());
    final autresVisibles = q.isEmpty
        ? autres
        : autres.where((c) => _normaliser(c.libelle).contains(q)).toList();
    final marquesFlotte = <int, String>{
      for (final m in flotte)
        if (m.marqueId != null) m.marqueId!: m.marqueNom,
    };
    final marquesTrouvees = widget.modelesSeulement || q.isEmpty
        ? const <MapEntry<int, String>>[]
        : marques.entries
            .where((e) =>
                !marquesFlotte.containsKey(e.key) &&
                _normaliser(e.value).contains(q))
            .toList();

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.85,
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.grey300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(widget.titre,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.dark)),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                  16, 4, 16, 16 + MediaQuery.of(context).padding.bottom),
              children: [
                if (!widget.modelesSeulement)
                  _option(
                    CibleVehicule.tous,
                    icone: Icons.public_rounded,
                    sousTitre: 'Proposé pour toute la flotte',
                  ),
                if (flotte.isNotEmpty) ...[
                  _titreGroupe('Votre flotte'),
                  for (final m in flotte)
                    _option(
                      CibleVehicule(
                        marqueId: m.marqueId,
                        marqueNom: m.marqueNom,
                        modeleId: m.modeleId,
                        modeleNom: m.modeleNom,
                      ),
                      icone: Icons.directions_car_outlined,
                      sousTitre:
                          '${m.nombreVehicules} véhicule${m.nombreVehicules > 1 ? 's' : ''}',
                    ),
                  if (!widget.modelesSeulement)
                    for (final e in marquesFlotte.entries)
                      _option(
                        CibleVehicule(marqueId: e.key, marqueNom: e.value),
                        icone: Icons.sell_outlined,
                        sousTitre: 'Tous ses modèles, y compris ceux à venir',
                      ),
                ],
                _titreGroupe('Autres modèles'),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextField(
                    onChanged: (v) => setState(() => _query = v),
                    textInputAction: TextInputAction.search,
                    style: TextStyle(fontSize: 14, color: AppColors.dark),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Rechercher parmi ${autres.length} modèles…',
                      hintStyle: TextStyle(color: AppColors.hint, fontSize: 14),
                      prefixIcon:
                          Icon(Icons.search, color: AppColors.hint, size: 20),
                      filled: true,
                      fillColor: AppColors.surface,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                    ),
                  ),
                ),
                if (modelesAsync.isLoading && autres.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                for (final e in marquesTrouvees)
                  _option(
                    CibleVehicule(marqueId: e.key, marqueNom: e.value),
                    icone: Icons.sell_outlined,
                    sousTitre: 'Tous les modèles de la marque',
                  ),
                for (final c in autresVisibles)
                  _option(c, icone: Icons.directions_car_outlined),
                if (!modelesAsync.isLoading &&
                    autresVisibles.isEmpty &&
                    marquesTrouvees.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text('Aucun modèle ne correspond.',
                        style: TextStyle(color: AppColors.label)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _titreGroupe(String libelle) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
        child: Text(
          libelle.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.hint,
            letterSpacing: 0.5,
          ),
        ),
      );

  Widget _option(CibleVehicule cible,
      {required IconData icone, String? sousTitre}) {
    final choisi = cible == widget.actuelle;
    final accent = AppColors.primary;
    return GestureDetector(
      onTap: () => Navigator.pop(context, cible),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: choisi ? accent : Colors.transparent, width: 1.5),
        ),
        child: Row(children: [
          Icon(icone, size: 20, color: choisi ? accent : AppColors.hint),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cible.libelle,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.dark)),
                if (sousTitre != null)
                  Text(sousTitre,
                      style: TextStyle(fontSize: 12, color: AppColors.hint)),
              ],
            ),
          ),
          if (choisi) Icon(Icons.check_circle_rounded, size: 20, color: accent),
        ]),
      ),
    );
  }
}

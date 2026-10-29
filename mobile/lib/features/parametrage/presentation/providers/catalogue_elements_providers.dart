import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../vehicule/presentation/providers/vehicule_provider.dart';
import 'parametrage_providers.dart';

/// Endpoint du catalogue des éléments de maintenance (clé de référentiel
/// `catalogue-elements-maintenance`).
const kEndpointCatalogueElements = '/api/catalogue-elements-maintenance';

/// Endpoint du référentiel des modèles de véhicule.
const kEndpointModeles = '/api/v1/modeles';

/// Un modèle de véhicule effectivement présent dans la flotte.
class ModeleFlotte {
  final int modeleId;
  final String modeleNom;
  final int? marqueId;
  final String marqueNom;
  final int nombreVehicules;

  const ModeleFlotte({
    required this.modeleId,
    required this.modeleNom,
    required this.marqueId,
    required this.marqueNom,
    required this.nombreVehicules,
  });

  String get libelle =>
      marqueNom.isEmpty ? modeleNom : '$marqueNom $modeleNom';
}

/// Regroupe les véhicules par modèle, du modèle le plus représenté au moins
/// représenté. Les véhicules sortis du parc ne comptent pas : un modèle qu'on
/// n'exploite plus n'a rien à faire en tête des choix.
List<ModeleFlotte> regrouperParModele(
    Iterable<({int? modeleId, String modele, int? marqueId, String marque, String? statut})>
        vehicules) {
  final parModele = <int, ModeleFlotte>{};
  for (final v in vehicules) {
    final id = v.modeleId;
    if (id == null || v.statut == 'HORS_PARC') continue;
    final existant = parModele[id];
    parModele[id] = ModeleFlotte(
      modeleId: id,
      modeleNom: v.modele,
      marqueId: v.marqueId,
      marqueNom: v.marque,
      nombreVehicules: (existant?.nombreVehicules ?? 0) + 1,
    );
  }
  final liste = parModele.values.toList()
    ..sort((a, b) {
      final parNombre = b.nombreVehicules.compareTo(a.nombreVehicules);
      return parNombre != 0 ? parNombre : a.libelle.compareTo(b.libelle);
    });
  return liste;
}

/// Modèles de la flotte, pour les puces de filtre et le haut du sélecteur de
/// véhicule. Une erreur retombe sur une liste vide : les modèles restent
/// accessibles par la recherche.
final modelesFlotteProvider = FutureProvider<List<ModeleFlotte>>((ref) async {
  final result = await ref.watch(vehiculeRepositoryProvider).getVehicules();
  return result.fold(
    (_) => const [],
    (vehicules) => regrouperParModele(vehicules.map((v) => (
          modeleId: v.modeleId,
          modele: v.modele,
          marqueId: v.marqueId,
          marque: v.marque,
          statut: v.statut,
        ))),
  );
});

/// Éléments d'un modèle, actifs ou non, avec le prix (`montantDefaut`),
/// l'image et l'activation (`tarifActif`) de ce modèle — l'onglet du modèle.
final elementsDuModeleProvider =
    FutureProvider.family<List<Map<String, dynamic>>, int>((ref, modeleId) =>
        ref
            .watch(parametrageApiProvider)
            .lister('$kEndpointCatalogueElements?modeleId=$modeleId'));

import 'package:flutter_test/flutter_test.dart';

import 'package:vtc_manager/features/parametrage/data/parametrage_api.dart';

/// Paramètres → Données de référence → Éléments de maintenance : le champ
/// « Type de maintenance » ne propose que les catégories de la sous-catégorie
/// « Maintenances », pas les recettes ni les assurances.
void main() {
  final typeMaintenance = ChampDescriptor.fromJson({
    'nom': 'categorieTypeId',
    'label': 'Type de maintenance',
    'type': 'reference',
    'obligatoire': false,
    'editable': true,
    'refKey': 'categories-operation',
    'refFiltre': {'sousCategorieLibelle': 'Maintenances'},
  });

  test('ne propose que les catégories qui portent la valeur du filtre', () {
    expect(
        typeMaintenance.accepteReference(
            {'id': 13, 'libelle': 'Vidange', 'sousCategorieLibelle': 'Maintenances'}),
        isTrue);
    expect(
        typeMaintenance.accepteReference(
            {'id': 1, 'libelle': 'Recette', 'sousCategorieLibelle': 'Recettes'}),
        isFalse);
    expect(typeMaintenance.accepteReference({'id': 2, 'libelle': 'Sans groupe'}),
        isFalse);
  });

  test('une référence sans filtre propose tout, comme avant', () {
    final marque = ChampDescriptor.fromJson({
      'nom': 'marqueId',
      'label': 'Marque',
      'type': 'reference',
      'refKey': 'marques',
    });
    expect(marque.refFiltre, isEmpty);
    expect(marque.accepteReference({'id': 1, 'nom': 'Toyota'}), isTrue);
  });
}

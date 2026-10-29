import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vtc_manager/features/maintenance/presentation/providers/type_maintenance_provider.dart';
import 'package:vtc_manager/features/operation_financiere/domain/entities/categorie_operation.dart';
import 'package:vtc_manager/features/operation_financiere/domain/enums/type_operation.dart';
import 'package:vtc_manager/features/parametrage/data/parametrage_api.dart';
import 'package:vtc_manager/features/parametrage/presentation/pages/catalogue_elements_maintenance_page.dart';
import 'package:vtc_manager/features/parametrage/presentation/providers/catalogue_elements_providers.dart';
import 'package:vtc_manager/features/parametrage/presentation/providers/parametrage_providers.dart';
import 'package:vtc_manager/features/parametrage/presentation/widgets/cible_vehicule_catalogue.dart';

/// Paramètres → Données de référence → Éléments de maintenance : le catalogue
/// rangé par type, la portée véhicule lisible sur chaque ligne, et un filtre
/// par modèle de la flotte.
final _descripteur = ReferentielDescriptor.fromJson({
  'key': 'catalogue-elements-maintenance',
  'libelle': 'Éléments de maintenance',
  'endpoint': kEndpointCatalogueElements,
  'editable': true,
  'idField': 'id',
  'champs': [
    {'nom': 'libelle', 'label': 'Libellé', 'type': 'text', 'obligatoire': true},
    {'nom': 'actif', 'label': 'Actif', 'type': 'bool'},
  ],
});

const _vidange = 13;
const _freinage = 16;
const _sPresso = 51;
const _dzire = 52;

final _elements = <Map<String, dynamic>>[
  {
    'id': 1,
    'libelle': 'Filtre à air',
    'actif': true,
    'montantDefaut': 2500,
    'categorieTypeId': _vidange,
    'categorieTypeLibelle': 'Vidange',
    'marqueId': 1,
    'marqueNom': 'Suzuki',
    'modeleId': _sPresso,
    'modeleNom': 'S-Presso',
  },
  {
    'id': 2,
    'libelle': 'Filtre à huile',
    'actif': true,
    'categorieTypeId': _vidange,
    'categorieTypeLibelle': 'Vidange',
  },
  {
    'id': 3,
    'libelle': 'Plaquette Dzire',
    'actif': true,
    'categorieTypeId': _freinage,
    'categorieTypeLibelle': 'Freinage',
    'marqueId': 1,
    'marqueNom': 'Suzuki',
    'modeleId': _dzire,
    'modeleNom': 'Dzire',
  },
  {'id': 4, 'libelle': "Main d'oeuvre", 'actif': true},
];

CategorieOperation _type(int id, String code, String libelle) =>
    CategorieOperation(
      id: id,
      code: code,
      libelle: libelle,
      typeOperation: TypeOperation.DEPENSE,
      actif: true,
    );

Widget _app() => ProviderScope(
      overrides: [
        referentielItemsProvider
            .overrideWith((ref, endpoint) async => _elements),
        modelesFlotteProvider.overrideWith((ref) async => const [
              ModeleFlotte(
                  modeleId: _sPresso,
                  modeleNom: 'S-Presso',
                  marqueId: 1,
                  marqueNom: 'Suzuki',
                  nombreVehicules: 9),
              ModeleFlotte(
                  modeleId: _dzire,
                  modeleNom: 'Dzire',
                  marqueId: 1,
                  marqueNom: 'Suzuki',
                  nombreVehicules: 3),
            ]),
        typeMaintenanceProvider.overrideWith((ref, _) async => [
              _type(_vidange, 'VIDANGE', 'Vidange'),
              _type(_freinage, 'FREINAGE', 'Freinage'),
            ]),
        // Ce que le serveur répond pour la S-Presso : tout sauf l'élément
        // réservé à la Dzire.
        elementsCompatiblesModeleProvider.overrideWith(
            (ref, modeleId) async => modeleId == _sPresso ? {1, 2, 4} : {2, 3, 4}),
      ],
      child: MaterialApp(
          home: CatalogueElementsMaintenancePage(descriptor: _descripteur)),
    );

void main() {
  group('CibleVehicule', () {
    test('un modèle part seul : le serveur en déduit la marque', () {
      const cible = CibleVehicule(
          marqueId: 1, marqueNom: 'Suzuki', modeleId: _sPresso, modeleNom: 'S-Presso');
      expect(cible.versCorps(), {'modeleId': _sPresso, 'marqueId': null});
      expect(cible.libelle, 'Suzuki S-Presso');
    });

    test('une marque entière part sans modèle', () {
      const cible = CibleVehicule(marqueId: 1, marqueNom: 'Suzuki');
      expect(cible.versCorps(), {'modeleId': null, 'marqueId': 1});
      expect(cible.libelle, 'Toute la marque Suzuki');
    });

    test('tous les véhicules : ni marque ni modèle', () {
      expect(CibleVehicule.tous.versCorps(), {'modeleId': null, 'marqueId': null});
      expect(CibleVehicule.depuisElement(const {'id': 4}).estTous, isTrue);
    });
  });

  test('la flotte se range du modèle le plus représenté, sans les véhicules sortis du parc', () {
    final flotte = regrouperParModele([
      (modeleId: _dzire, modele: 'Dzire', marqueId: 1, marque: 'Suzuki', statut: 'EN_SERVICE'),
      (modeleId: _sPresso, modele: 'S-Presso', marqueId: 1, marque: 'Suzuki', statut: 'EN_SERVICE'),
      (modeleId: _sPresso, modele: 'S-Presso', marqueId: 1, marque: 'Suzuki', statut: 'DISPONIBLE'),
      (modeleId: _dzire, modele: 'Dzire', marqueId: 1, marque: 'Suzuki', statut: 'HORS_PARC'),
      (modeleId: null, modele: '', marqueId: null, marque: '', statut: 'EN_SERVICE'),
    ]);
    expect(flotte.map((m) => (m.modeleNom, m.nombreVehicules)),
        [('S-Presso', 2), ('Dzire', 1)]);
  });

  testWidgets('le catalogue se range par type, communs en dernier', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    final vidange = tester.getTopLeft(find.textContaining('Vidange'));
    final freinage = tester.getTopLeft(find.textContaining('Freinage'));
    final communs = tester.getTopLeft(find.textContaining('Communs à tous les types'));
    // Vidange (2 éléments) avant Freinage (1), communs à la fin.
    expect(vidange.dy, lessThan(freinage.dy));
    expect(freinage.dy, lessThan(communs.dy));
    // Sections repliées au départ : aucune ligne visible.
    expect(find.text('Filtre à air'), findsNothing);
  });

  testWidgets('une section ouverte montre la portée véhicule de chaque élément',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Vidange'));
    await tester.pumpAndSettle();

    expect(find.text('Filtre à air'), findsOneWidget);
    expect(find.text('Suzuki S-Presso'), findsOneWidget);
    expect(find.text('Tous véhicules'), findsOneWidget);
  });

  testWidgets('le filtre par modèle montre ce que la saisie proposerait',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('S-Presso'));
    await tester.pumpAndSettle();

    // Filtre actif : les sections s'ouvrent, l'élément de la Dzire disparaît.
    expect(find.text('Filtre à air'), findsOneWidget);
    expect(find.text("Main d'oeuvre"), findsOneWidget);
    expect(find.text('Plaquette Dzire'), findsNothing);
    expect(find.text('Éléments proposés pour Suzuki S-Presso'), findsOneWidget);
    // Plus de compteurs : ni nombre d'éléments, ni nombre de véhicules.
    expect(find.textContaining('· 9'), findsNothing);
  });
}

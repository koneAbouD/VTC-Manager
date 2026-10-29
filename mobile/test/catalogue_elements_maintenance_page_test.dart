import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vtc_manager/features/maintenance/presentation/providers/type_maintenance_provider.dart';
import 'package:vtc_manager/features/operation_financiere/domain/entities/categorie_operation.dart';
import 'package:vtc_manager/features/operation_financiere/domain/enums/type_operation.dart';
import 'package:vtc_manager/features/parametrage/data/parametrage_api.dart';
import 'package:vtc_manager/features/parametrage/presentation/pages/catalogue_element_maintenance_form_page.dart';
import 'package:vtc_manager/features/parametrage/presentation/pages/catalogue_elements_maintenance_page.dart';
import 'package:vtc_manager/features/parametrage/presentation/providers/catalogue_elements_providers.dart';
import 'package:vtc_manager/features/parametrage/presentation/providers/parametrage_providers.dart';
import 'package:vtc_manager/features/parametrage/presentation/widgets/cible_vehicule_catalogue.dart';

/// Paramètres → Données de référence → Éléments de maintenance : un onglet par
/// modèle de la flotte, chacun rangé par type de maintenance de la même façon,
/// le prix à droite quand il est renseigné.
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
const _corolla = 99;

final _filtreAir = <String, dynamic>{
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
};

final _filtreHuile = <String, dynamic>{
  'id': 2,
  'libelle': 'Filtre à huile',
  'actif': true,
  'categorieTypeId': _vidange,
  'categorieTypeLibelle': 'Vidange',
};

final _elements = <Map<String, dynamic>>[
  _filtreAir,
  _filtreHuile,
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
  // Réservé à un modèle absent de la flotte : seul l'onglet « Hors flotte »
  // le montre.
  {
    'id': 5,
    'libelle': 'Courroie Corolla',
    'actif': true,
    'categorieTypeId': _freinage,
    'categorieTypeLibelle': 'Freinage',
    'marqueId': 7,
    'marqueNom': 'Toyota',
    'modeleId': _corolla,
    'modeleNom': 'Corolla',
  },
];

CategorieOperation _type(int id, String code, String libelle) =>
    CategorieOperation(
      id: id,
      code: code,
      libelle: libelle,
      typeOperation: TypeOperation.DEPENSE,
      actif: true,
    );

Widget _app(Widget page) => ProviderScope(
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
        // Ce que le serveur répond pour chaque modèle : les communs et ce qui
        // lui est réservé.
        elementsCompatiblesModeleProvider.overrideWith(
            (ref, modeleId) async => modeleId == _sPresso ? {1, 2, 4} : {2, 3, 4}),
      ],
      child: MaterialApp(home: page),
    );

Widget _page() => _app(CatalogueElementsMaintenancePage(descriptor: _descripteur));

void main() {
  setUp(reinitialiserSectionsOuvertesCatalogue);

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

  testWidgets('un onglet par modèle de la flotte, plus Hors flotte, sans « Tous les véhicules »',
      (tester) async {
    await tester.pumpWidget(_page());
    await tester.pumpAndSettle();

    expect(find.widgetWithText(Tab, 'S-Presso'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Dzire'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Hors flotte'), findsOneWidget);
    expect(find.text('Tous les véhicules'), findsNothing);
    // Sections repliées au départ : aucune ligne visible.
    expect(find.text('Filtre à air'), findsNothing);
  });

  testWidgets('les sections suivent le même ordre dans chaque onglet', (tester) async {
    await tester.pumpWidget(_page());
    await tester.pumpAndSettle();

    double y(String texte) => tester.getTopLeft(find.text(texte).hitTestable()).dy;
    // Ordre fixé sur tout le catalogue : Freinage (2 éléments) puis Vidange
    // (2, départagés par le libellé), communs en dernier. Un onglet ne montre
    // que les sections où il a des éléments : la S-Presso n'a pas de freinage.
    expect(find.text('Freinage').hitTestable(), findsNothing);
    expect(y('Vidange'), lessThan(y('Communs à tous les types')));

    await tester.tap(find.widgetWithText(Tab, 'Dzire'));
    await tester.pumpAndSettle();
    expect(y('Freinage'), lessThan(y('Vidange')));
    expect(y('Vidange'), lessThan(y('Communs à tous les types')));
  });

  testWidgets('chaque onglet montre ce que la saisie proposerait pour son modèle, prix compris',
      (tester) async {
    await tester.pumpWidget(_page());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Vidange').hitTestable());
    await tester.pumpAndSettle();

    // S-Presso : son filtre à air, signalé « Ce modèle », avec son prix ;
    // le filtre à huile commun ne porte aucune mention.
    expect(find.text('Filtre à air'), findsOneWidget);
    expect(find.text('Ce modèle'), findsOneWidget);
    expect(find.textContaining('2 500'), findsOneWidget);
    expect(find.text('Filtre à huile'), findsOneWidget);

    // Dzire : la section reste ouverte, sans le filtre à air de la S-Presso.
    await tester.tap(find.widgetWithText(Tab, 'Dzire'));
    await tester.pumpAndSettle();
    expect(find.text('Filtre à huile').hitTestable(), findsOneWidget);
    expect(find.text('Filtre à air').hitTestable(), findsNothing);
  });

  testWidgets('Hors flotte garde accessibles les éléments des modèles absents',
      (tester) async {
    await tester.pumpWidget(_page());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(Tab, 'Hors flotte'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Freinage').hitTestable());
    await tester.pumpAndSettle();

    expect(find.text('Courroie Corolla').hitTestable(), findsOneWidget);
    expect(find.text('Toyota Corolla').hitTestable(), findsOneWidget);
    expect(find.text('Filtre à huile').hitTestable(), findsNothing);
  });

  testWidgets('modifier un élément commun rappelle les modèles concernés',
      (tester) async {
    await tester.pumpWidget(
        _app(CatalogueElementMaintenanceFormPage(item: _filtreHuile)));
    await tester.pumpAndSettle();

    expect(
        find.text('Commun à tous les véhicules : la modification vaut pour '
            'S-Presso et Dzire.'),
        findsOneWidget);
    expect(find.text('Prix par défaut', findRichText: true), findsOneWidget);
  });

  testWidgets("un élément réservé à un modèle n'a pas de rappel", (tester) async {
    await tester.pumpWidget(
        _app(CatalogueElementMaintenanceFormPage(item: _filtreAir)));
    await tester.pumpAndSettle();

    expect(find.textContaining('la modification vaut pour'), findsNothing);
  });
}

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
/// modèle de la flotte, chaque élément au prix et à l'image de ce modèle ; le
/// formulaire sépare ce qui vaut pour tous les modèles de ce qui vaut pour un.
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

Map<String, dynamic> _tarif(int modeleId, String modeleNom, num? prix,
        {String marqueNom = 'Suzuki', bool actif = true}) =>
    {
      'modeleId': modeleId,
      'modeleNom': modeleNom,
      'marqueNom': marqueNom,
      'prix': prix,
      'actif': actif,
    };

final _tarifsFiltre = [
  _tarif(_sPresso, 'S-Presso', 1600),
  _tarif(_dzire, 'Dzire', 2200),
];

final _filtreHuile = <String, dynamic>{
  'id': 2,
  'libelle': 'Filtre à huile',
  'actif': true,
  'categorieTypeId': _vidange,
  'categorieTypeLibelle': 'Vidange',
  'tarifs': _tarifsFiltre,
};

final _plaquette = <String, dynamic>{
  'id': 3,
  'libelle': 'Plaquette',
  'actif': true,
  'categorieTypeId': _freinage,
  'categorieTypeLibelle': 'Freinage',
  'tarifs': [_tarif(_dzire, 'Dzire', 6000)],
};

final _mainOeuvre = <String, dynamic>{
  'id': 4,
  'libelle': "Main d'oeuvre",
  'actif': true,
  'tarifs': [_tarif(_sPresso, 'S-Presso', null), _tarif(_dzire, 'Dzire', null)],
};

// Réservé à un modèle absent de la flotte.
final _courroie = <String, dynamic>{
  'id': 5,
  'libelle': 'Courroie Corolla',
  'actif': true,
  'categorieTypeId': _freinage,
  'categorieTypeLibelle': 'Freinage',
  'tarifs': [_tarif(_corolla, 'Corolla', 9000, marqueNom: 'Toyota')],
};

// Créé sans modèle : proposé nulle part.
final _orphelin = <String, dynamic>{
  'id': 6,
  'libelle': 'Essuie-glaces',
  'actif': true,
  'tarifs': const [],
};

/// Vue d'un élément depuis l'onglet d'un modèle : prix et activation du modèle.
Map<String, dynamic> _vue(Map<String, dynamic> el, int modeleId) {
  final t = (el['tarifs'] as List).cast<Map<String, dynamic>>()
      .firstWhere((t) => t['modeleId'] == modeleId);
  return {
    ...el,
    'tarifModeleId': modeleId,
    'montantDefaut': t['prix'],
    'tarifActif': t['actif'],
  };
}

/// Fausse API : garde la trace des appels d'écriture.
class _FakeApi implements ParametrageApi {
  final List<String> appels = [];

  @override
  Future<void> enregistrerTarif(String endpoint, Object elementId, int modeleId,
      {num? prix, String? image, required bool actif}) async {
    appels.add('tarif $elementId/$modeleId prix=$prix actif=$actif');
  }

  @override
  Future<Map<String, dynamic>> mettreAJour(
      String endpoint, Object id, Map<String, dynamic> body) async {
    appels.add('element $id ${body['libelle']}');
    return body;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

CategorieOperation _type(int id, String code, String libelle) =>
    CategorieOperation(
      id: id,
      code: code,
      libelle: libelle,
      typeOperation: TypeOperation.DEPENSE,
      actif: true,
    );

Widget _app(Widget page, {_FakeApi? api}) => ProviderScope(
      overrides: [
        if (api != null) parametrageApiProvider.overrideWithValue(api),
        referentielItemsProvider.overrideWith((ref, endpoint) async =>
            [_filtreHuile, _plaquette, _mainOeuvre, _courroie, _orphelin]),
        elementsDuModeleProvider.overrideWith((ref, modeleId) async =>
            modeleId == _sPresso
                ? [_vue(_filtreHuile, _sPresso), _vue(_mainOeuvre, _sPresso)]
                : [
                    _vue(_filtreHuile, _dzire),
                    _vue(_plaquette, _dzire),
                    _vue(_mainOeuvre, _dzire),
                  ]),
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
      ],
      child: MaterialApp(home: page),
    );

Widget _page({_FakeApi? api}) =>
    _app(CatalogueElementsMaintenancePage(descriptor: _descripteur), api: api);

const _modeleSPresso = CibleVehicule(
    marqueId: 1, marqueNom: 'Suzuki', modeleId: _sPresso, modeleNom: 'S-Presso');

void main() {
  setUp(reinitialiserSectionsOuvertesCatalogue);

  test('un modèle se désigne par sa marque et son nom', () {
    expect(_modeleSPresso.libelle, 'Suzuki S-Presso');
    expect(_modeleSPresso.estModele, isTrue);
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

  testWidgets('un onglet par modèle de la flotte, plus Hors flotte', (tester) async {
    await tester.pumpWidget(_page());
    await tester.pumpAndSettle();

    expect(find.widgetWithText(Tab, 'S-Presso'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Dzire'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Hors flotte'), findsOneWidget);
    expect(find.text('Tous les véhicules'), findsNothing);
  });

  testWidgets('le même élément a le prix de chaque modèle', (tester) async {
    await tester.pumpWidget(_page());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Vidange').hitTestable());
    await tester.pumpAndSettle();
    expect(find.textContaining('1 600').hitTestable(), findsOneWidget);

    await tester.tap(find.widgetWithText(Tab, 'Dzire'));
    await tester.pumpAndSettle();
    expect(find.textContaining('2 200').hitTestable(), findsOneWidget);
    expect(find.textContaining('1 600').hitTestable(), findsNothing);
  });

  testWidgets('les sections suivent le même ordre dans chaque onglet', (tester) async {
    await tester.pumpWidget(_page());
    await tester.pumpAndSettle();

    double y(String texte) => tester.getTopLeft(find.text(texte).hitTestable()).dy;
    // La S-Presso n'a pas de freinage : la section n'apparaît pas.
    expect(find.text('Freinage').hitTestable(), findsNothing);
    expect(y('Vidange'), lessThan(y('Communs à tous les types')));

    await tester.tap(find.widgetWithText(Tab, 'Dzire'));
    await tester.pumpAndSettle();
    // Freinage (2 éléments sur le catalogue) avant Vidange (1).
    expect(y('Freinage'), lessThan(y('Vidange')));
    expect(y('Vidange'), lessThan(y('Communs à tous les types')));
  });

  testWidgets("l'interrupteur retire l'élément du seul modèle affiché", (tester) async {
    final api = _FakeApi();
    await tester.pumpWidget(_page(api: api));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Vidange').hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch).hitTestable().first);
    await tester.pumpAndSettle();

    expect(api.appels, contains('tarif 2/$_sPresso prix=1600 actif=false'));
  });

  testWidgets('Hors flotte montre les modèles absents et les éléments sans modèle',
      (tester) async {
    await tester.pumpWidget(_page());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(Tab, 'Hors flotte'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Freinage').hitTestable());
    await tester.tap(find.text('Communs à tous les types').hitTestable());
    await tester.pumpAndSettle();

    expect(find.text('Courroie Corolla').hitTestable(), findsOneWidget);
    expect(find.text('Toyota Corolla').hitTestable(), findsOneWidget);
    expect(find.text('Essuie-glaces').hitTestable(), findsOneWidget);
    expect(find.text('Aucun modèle').hitTestable(), findsOneWidget);
    expect(find.text('Filtre à huile').hitTestable(), findsNothing);
  });

  testWidgets('la fiche sépare ce qui vaut pour tous les modèles de ce qui vaut pour un',
      (tester) async {
    await tester.pumpWidget(_app(CatalogueElementMaintenanceFormPage(
      element: _filtreHuile,
      modele: _modeleSPresso,
      prix: 1600,
    )));
    await tester.pumpAndSettle();

    expect(
        find.text('Le libellé et le type valent pour S-Presso et Dzire. '
            'Le prix et l\'image ne valent que pour S-Presso.'),
        findsOneWidget);
    expect(find.text('POUR TOUS LES MODÈLES'), findsOneWidget);
    expect(find.text('POUR SUZUKI S-PRESSO'), findsOneWidget);
    expect(find.text('1600'), findsOneWidget);
  });

  testWidgets("enregistrer la fiche met à jour l'élément et le prix de ce modèle",
      (tester) async {
    final api = _FakeApi();
    await tester.pumpWidget(_app(
        CatalogueElementMaintenanceFormPage(
          element: _filtreHuile,
          modele: _modeleSPresso,
          prix: 1600,
        ),
        api: api));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, '1600'), '1800');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(api.appels, [
      'element 2 Filtre à huile',
      'tarif 2/$_sPresso prix=1800 actif=true',
    ]);
  });

  testWidgets("depuis l'onglet d'un modèle, on peut ajouter un élément existant",
      (tester) async {
    await tester.pumpWidget(_app(
        const CatalogueElementMaintenanceFormPage(modele: _modeleSPresso)));
    await tester.pumpAndSettle();

    // Titre de la page et premier choix du sélecteur.
    expect(find.text('Nouvel élément'), findsNWidgets(2));
    await tester.tap(find.text('Élément existant'));
    await tester.pumpAndSettle();

    expect(find.text('Choisir un élément…'), findsOneWidget);
    expect(find.text('Ajouter au modèle'), findsOneWidget);
  });
}

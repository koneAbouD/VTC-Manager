import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vtc_manager/features/parametrage/data/parametrage_api.dart';
import 'package:vtc_manager/features/parametrage/presentation/pages/referentiel_form_page.dart';
import 'package:vtc_manager/features/parametrage/presentation/pages/referentiel_liste_page.dart';
import 'package:vtc_manager/features/parametrage/presentation/providers/parametrage_providers.dart';

/// Paramètres → Données de référence → Catégories d'opération : la nature de
/// résultat s'affiche par son libellé (« Charge fixe »), jamais par son code.
final _categories = ReferentielDescriptor.fromJson({
  'key': 'categories-operation',
  'libelle': "Catégories d'opération",
  'endpoint': '/api/categories-operation',
  'editable': true,
  'idField': 'id',
  'champs': [
    {'nom': 'libelle', 'label': 'Libellé', 'type': 'text', 'obligatoire': true},
    {
      'nom': 'natureResultat',
      'label': 'Nature de résultat',
      'type': 'enum',
      'obligatoire': true,
      'options': ['PRODUIT_EXPLOITATION', 'CHARGE_FIXE'],
      'libelles': {
        'PRODUIT_EXPLOITATION': "Produit d'exploitation",
        'CHARGE_FIXE': 'Charge fixe',
      },
    },
    {'nom': 'actif', 'label': 'Actif', 'type': 'bool'},
  ],
});

const _assurance = {
  'id': 7,
  'libelle': 'Assurance',
  'natureResultat': 'CHARGE_FIXE',
  'actif': true,
};

Widget _app(Widget page) => ProviderScope(
      overrides: [
        referentielItemsProvider('/api/categories-operation')
            .overrideWith((ref) async => [_assurance]),
        catalogueProvider.overrideWith((ref) async => [_categories]),
      ],
      child: MaterialApp(home: page),
    );

void main() {
  group('descripteur', () {
    final nature = _categories.champs[1];

    test('le libellé de chaque code', () {
      expect(nature.libelleDe('CHARGE_FIXE'), 'Charge fixe');
    });

    test('catalogue sans libellés (serveur plus ancien) : le code', () {
      final ancien = ChampDescriptor.fromJson({
        'nom': 'natureResultat',
        'type': 'enum',
        'options': ['CHARGE_FIXE'],
      });
      expect(ancien.libelleDe('CHARGE_FIXE'), 'CHARGE_FIXE');
    });
  });

  testWidgets('la liste montre le libellé', (tester) async {
    await tester.pumpWidget(_app(ReferentielListePage(descriptor: _categories)));
    await tester.pumpAndSettle();

    expect(find.textContaining('Charge fixe'), findsOneWidget);
    expect(find.textContaining('CHARGE_FIXE'), findsNothing);
  });

  testWidgets('le formulaire de modification montre le libellé', (tester) async {
    await tester.pumpWidget(_app(
        ReferentielFormPage(descriptor: _categories, item: _assurance)));
    await tester.pumpAndSettle();

    expect(find.text('Charge fixe'), findsOneWidget);
    expect(find.textContaining('CHARGE_FIXE'), findsNothing);
  });
}

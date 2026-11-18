import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vtc_manager/features/maintenance/presentation/widgets/prerequis_elements_sheet.dart';

/// Ouvre la feuille depuis un bouton et rend l'étape choisie.
Future<PrerequisElements?> _ouvrir(WidgetTester tester,
    {String? types, String? vehicule, required String toucher}) async {
  PrerequisElements? choix;
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () async => choix = await showPrerequisElementsSheet(
              context,
              typesLibelle: types,
              vehiculeLibelle: vehicule),
          child: const Text('ouvrir'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('ouvrir'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(toucher));
  await tester.pumpAndSettle();
  return choix;
}

void main() {
  group('feuille des prérequis des éléments', () {
    testWidgets('types choisis, véhicule manquant : mène au véhicule',
        (tester) async {
      final choix = await _ouvrir(tester,
          types: 'Vidange · Freinage', toucher: 'Choisir le véhicule');
      expect(choix, PrerequisElements.vehicule);
    });

    testWidgets('rappelle ce qui est fait et ce qui manque', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showPrerequisElementsSheet(context,
                  typesLibelle: 'Vidange · Freinage', vehiculeLibelle: null),
              child: const Text('ouvrir'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('ouvrir'));
      await tester.pumpAndSettle();

      expect(find.text('Encore une étape'), findsOneWidget);
      expect(find.text('Vidange · Freinage'), findsOneWidget);
      expect(find.text('À choisir'), findsOneWidget);
    });

    testWidgets('rien de choisi : deux étapes, les types d\'abord',
        (tester) async {
      final choix = await _ouvrir(tester, toucher: 'Choisir les types');
      expect(choix, PrerequisElements.types);
      expect(find.text('Encore deux étapes'), findsNothing); // refermée
    });

    testWidgets('toucher l\'étape manquante y mène aussi', (tester) async {
      final choix = await _ouvrir(tester,
          types: 'Vidange', toucher: 'Véhicule concerné');
      expect(choix, PrerequisElements.vehicule);
    });

    testWidgets('« Plus tard » referme sans rien choisir', (tester) async {
      final choix = await _ouvrir(tester, types: 'Vidange', toucher: 'Plus tard');
      expect(choix, isNull);
    });
  });
}
